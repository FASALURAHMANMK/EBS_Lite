package services

import (
	"database/sql"
	"fmt"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
	"erp-backend/internal/utils"
	"github.com/google/uuid"
	"github.com/lib/pq"
)

type AuthService struct {
	db *sql.DB
}

func NewAuthService() *AuthService {
	return &AuthService{
		db: database.GetDB(),
	}
}

func (s *AuthService) Login(req *models.LoginRequest, ipAddress, userAgent string) (*models.LoginResponse, error) {
	// Get user by email
	user, err := s.getUserByEmail(req.Email)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("invalid credentials")
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	// Check if user is active
	if !user.IsActive || user.IsLocked {
		return nil, fmt.Errorf("account is inactive or locked")
	}

	// Verify password
	valid, err := utils.VerifyPassword(req.Password, user.PasswordHash)
	if err != nil {
		return nil, fmt.Errorf("failed to verify password: %w", err)
	}
	if !valid {
		return nil, fmt.Errorf("invalid credentials")
	}

	// Enforce session limit
	if user.CompanyID != nil {
		settingsSvc := NewSettingsService()
		maxSessions, err := settingsSvc.GetMaxSessions(*user.CompanyID)
		if err != nil {
			return nil, fmt.Errorf("failed to get session limit: %w", err)
		}
		if maxSessions > 0 {
			rows, err := s.db.Query(`SELECT session_id FROM device_sessions WHERE user_id=$1 AND is_active=TRUE ORDER BY last_seen ASC`, user.UserID)
			if err != nil {
				return nil, fmt.Errorf("failed to query active sessions: %w", err)
			}
			defer rows.Close()

			var sessionIDs []string
			for rows.Next() {
				var id string
				if err := rows.Scan(&id); err != nil {
					return nil, fmt.Errorf("failed to scan session id: %w", err)
				}
				sessionIDs = append(sessionIDs, id)
			}

			if len(sessionIDs) >= maxSessions {
				toRevoke := len(sessionIDs) - maxSessions + 1
				revokeIDs := sessionIDs[:toRevoke]
				if _, err = s.db.Exec(`UPDATE device_sessions SET is_active=FALSE WHERE session_id = ANY($1)`, pq.Array(revokeIDs)); err != nil {
					return nil, fmt.Errorf("failed to revoke old sessions: %w", err)
				}
			}
		}
	}

	// Generate tokens
	accessToken, err := utils.GenerateAccessToken(user, 24*time.Hour)
	if err != nil {
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}

	refreshToken, err := utils.GenerateRefreshToken(user, 7*24*time.Hour)
	if err != nil {
		return nil, fmt.Errorf("failed to generate refresh token: %w", err)
	}

	// Update last login
	err = s.updateLastLogin(user.UserID)
	if err != nil {
		// Log error but don't fail the login
		fmt.Printf("Failed to update last login: %v\n", err)
	}

	// Create device session
	var sessionID string
	var ipVal interface{}
	if ipAddress != "" {
		ipVal = ipAddress
	}
	var uaVal interface{}
	if userAgent != "" {
		uaVal = userAgent
	}
	err = s.db.QueryRow(`INSERT INTO device_sessions (user_id, device_id, device_name, ip_address, user_agent) VALUES ($1,$2,$3,$4,$5) RETURNING session_id`, user.UserID, req.DeviceID, req.DeviceName, ipVal, uaVal).Scan(&sessionID)
	if err != nil {
		fmt.Printf("Failed to create device session: %v\n", err)
	}

	// Get user permissions
	permissions, err := s.getUserPermissions(user.UserID)
	if err != nil {
		// Log error but don't fail the login
		fmt.Printf("Failed to get user permissions: %v\n", err)
		permissions = []string{}
	}

	prefsSvc := NewUserPreferencesService()
	prefs, err := prefsSvc.GetPreferences(user.UserID)
	if err != nil {
		prefs = map[string]string{}
	}

	userResponse := models.UserResponse{
		UserID:            user.UserID,
		Username:          user.Username,
		Email:             user.Email,
		FirstName:         user.FirstName,
		LastName:          user.LastName,
		Phone:             user.Phone,
		RoleID:            user.RoleID,
		LocationID:        user.LocationID,
		CompanyID:         user.CompanyID,
		IsActive:          user.IsActive,
		IsLocked:          user.IsLocked,
		PreferredLanguage: user.PreferredLanguage,
		SecondaryLanguage: user.SecondaryLanguage,
		LastLogin:         user.LastLogin,
		Permissions:       permissions,
		Preferences:       prefs,
	}

	return &models.LoginResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		SessionID:    sessionID,
		User:         userResponse,
	}, nil
}

func (s *AuthService) RefreshToken(req *models.RefreshTokenRequest) (*models.RefreshTokenResponse, error) {
	// Validate refresh token
	claims, err := utils.ValidateToken(req.RefreshToken)
	if err != nil {
		return nil, fmt.Errorf("invalid refresh token: %w", err)
	}

	if claims.Type != "refresh" {
		return nil, fmt.Errorf("invalid token type")
	}

	// Get user
	user, err := s.getUserByID(claims.UserID)
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}

	if !user.IsActive || user.IsLocked {
		return nil, fmt.Errorf("account is inactive or locked")
	}

	// Generate new access token
	accessToken, err := utils.GenerateAccessToken(user, 24*time.Hour)
	if err != nil {
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}

	return &models.RefreshTokenResponse{
		AccessToken: accessToken,
	}, nil
}

func (s *AuthService) ForgotPassword(req *models.ForgotPasswordRequest) error {
	// Check if user exists
	user, err := s.getUserByEmail(req.Email)
	if err != nil {
		if err == sql.ErrNoRows {
			// Don't reveal if user exists or not
			return nil
		}
		return fmt.Errorf("failed to get user: %w", err)
	}

	if !user.IsActive {
		return nil // Don't reveal if user is inactive
	}

	// Generate token
	token := uuid.NewString()
	expiresAt := time.Now().Add(1 * time.Hour)

	// Remove existing tokens for this user
	_, _ = s.db.Exec("DELETE FROM password_reset_tokens WHERE user_id = $1", user.UserID)

	// Store token
	query := `INSERT INTO password_reset_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)`
	if _, err = s.db.Exec(query, user.UserID, token, expiresAt); err != nil {
		return fmt.Errorf("failed to store reset token: %w", err)
	}

	// Send email with reset link
	resetLink := fmt.Sprintf("https://example.com/reset-password?token=%s", token)
	subject := "Password Reset Request"
	body := fmt.Sprintf("Click the link to reset your password: %s", resetLink)
	if err := utils.SendEmail(user.Email, subject, body); err != nil {
		return fmt.Errorf("failed to send reset email: %w", err)
	}

	return nil
}

func (s *AuthService) ResetPassword(req *models.ResetPasswordRequest) error {
	// Validate token
	var userID int
	var expiresAt time.Time
	err := s.db.QueryRow(`SELECT user_id, expires_at FROM password_reset_tokens WHERE token = $1`, req.Token).Scan(&userID, &expiresAt)
	if err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("invalid or expired token")
		}
		return fmt.Errorf("failed to validate token: %w", err)
	}

	if time.Now().After(expiresAt) {
		return fmt.Errorf("invalid or expired token")
	}

	// Hash new password
	hashedPassword, err := utils.HashPassword(req.NewPassword)
	if err != nil {
		return fmt.Errorf("failed to hash password: %w", err)
	}

	// Update password
	updateQuery := `UPDATE users SET password_hash = $1, updated_at = CURRENT_TIMESTAMP WHERE user_id = $2`
	if _, err = s.db.Exec(updateQuery, hashedPassword, userID); err != nil {
		return fmt.Errorf("failed to update password: %w", err)
	}

	// Delete token after successful reset
	_, _ = s.db.Exec(`DELETE FROM password_reset_tokens WHERE token = $1`, req.Token)

	return nil
}

func (s *AuthService) GetMe(userID int) (*models.UserResponse, error) {
	user, err := s.getUserByID(userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	permissions, err := s.getUserPermissions(userID)
	if err != nil {
		permissions = []string{}
	}

	prefsSvc := NewUserPreferencesService()
	prefs, err := prefsSvc.GetPreferences(userID)
	if err != nil {
		prefs = map[string]string{}
	}

	return &models.UserResponse{
		UserID:            user.UserID,
		Username:          user.Username,
		Email:             user.Email,
		FirstName:         user.FirstName,
		LastName:          user.LastName,
		Phone:             user.Phone,
		RoleID:            user.RoleID,
		LocationID:        user.LocationID,
		CompanyID:         user.CompanyID,
		IsActive:          user.IsActive,
		IsLocked:          user.IsLocked,
		PreferredLanguage: user.PreferredLanguage,
		SecondaryLanguage: user.SecondaryLanguage,
		LastLogin:         user.LastLogin,
		Permissions:       permissions,
		Preferences:       prefs,
	}, nil
}

// Helper methods
func (s *AuthService) getUserByEmail(email string) (*models.User, error) {
	query := `
		SELECT user_id, company_id, location_id, role_id, username, email, password_hash,
			   first_name, last_name, phone, preferred_language, secondary_language,
			   max_allowed_devices, is_locked, is_active, last_login, sync_status,
			   created_at, updated_at, is_deleted
		FROM users 
		WHERE email = $1 AND is_deleted = FALSE
	`

	var user models.User
	err := s.db.QueryRow(query, email).Scan(
		&user.UserID, &user.CompanyID, &user.LocationID, &user.RoleID,
		&user.Username, &user.Email, &user.PasswordHash, &user.FirstName,
		&user.LastName, &user.Phone, &user.PreferredLanguage, &user.SecondaryLanguage,
		&user.MaxAllowedDevices, &user.IsLocked, &user.IsActive, &user.LastLogin,
		&user.SyncStatus, &user.CreatedAt, &user.UpdatedAt, &user.IsDeleted,
	)

	return &user, err
}

func (s *AuthService) getUserByID(userID int) (*models.User, error) {
	query := `
		SELECT user_id, company_id, location_id, role_id, username, email, password_hash,
			   first_name, last_name, phone, preferred_language, secondary_language,
			   max_allowed_devices, is_locked, is_active, last_login, sync_status,
			   created_at, updated_at, is_deleted
		FROM users 
		WHERE user_id = $1 AND is_deleted = FALSE
	`

	var user models.User
	err := s.db.QueryRow(query, userID).Scan(
		&user.UserID, &user.CompanyID, &user.LocationID, &user.RoleID,
		&user.Username, &user.Email, &user.PasswordHash, &user.FirstName,
		&user.LastName, &user.Phone, &user.PreferredLanguage, &user.SecondaryLanguage,
		&user.MaxAllowedDevices, &user.IsLocked, &user.IsActive, &user.LastLogin,
		&user.SyncStatus, &user.CreatedAt, &user.UpdatedAt, &user.IsDeleted,
	)

	return &user, err
}

func (s *AuthService) updateLastLogin(userID int) error {
	query := `UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE user_id = $1`
	_, err := s.db.Exec(query, userID)
	return err
}

// func (s *AuthService) getUserPermissions(userID int) ([]string, error) {
// 	query := `
// 		SELECT p.name
// 		FROM users u
// 		JOIN role_permissions rp ON u.role_id = rp.role_id
// 		JOIN permissions p ON rp.permission_id = p.permission_id
// 		WHERE u.user_id = $1 AND u.is_active = TRUE
// 	`

// 	rows, err := s.db.Query(query, userID)
// 	if err != nil {
// 		return nil, err
// 	}
// 	defer rows.Close()

// 	var permissions []string
// 	for rows.Next() {
// 		var permission string
// 		if err := rows.Scan(&permission); err != nil {
// 			return nil, err
// 		}
// 		permissions = append(permissions, permission)
// 	}

// 	return permissions, nil
// }

func (s *AuthService) getUserPermissions(userID int) ([]string, error) {
	query := `
		SELECT p.name 
		FROM users u
		JOIN role_permissions rp ON u.role_id = rp.role_id
		JOIN permissions p ON rp.permission_id = p.permission_id
		WHERE u.user_id = $1 AND u.is_active = TRUE AND u.role_id IS NOT NULL
	`

	rows, err := s.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var permissions []string
	for rows.Next() {
		var permission string
		if err := rows.Scan(&permission); err != nil {
			return nil, err
		}
		permissions = append(permissions, permission)
	}

	return permissions, nil
}

// REPLACE the Register method:
func (s *AuthService) Register(req *models.RegisterRequest) (*models.RegisterResponse, error) {
	// Check if username or email already exists
	exists, err := s.checkUserExists(req.Username, req.Email)
	if err != nil {
		return nil, fmt.Errorf("failed to check user existence: %w", err)
	}
	if exists {
		return nil, fmt.Errorf("username or email already exists")
	}

	// Hash password
	hashedPassword, err := utils.HashPassword(req.Password)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}

	// Insert user WITHOUT company
	query := `
		INSERT INTO users (
			username, email, password_hash, first_name, last_name, 
			phone, preferred_language, secondary_language, is_active
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, TRUE)
		RETURNING user_id
	`

	var userID int
	err = s.db.QueryRow(query,
		req.Username, req.Email, hashedPassword, req.FirstName, req.LastName,
		req.Phone, req.PreferredLanguage, req.SecondaryLanguage,
	).Scan(&userID)

	if err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	return &models.RegisterResponse{
		UserID:   userID,
		Username: req.Username,
		Email:    req.Email,
		Message:  "User registered successfully. Please create your company to get started.",
	}, nil
}

// ADD this helper method:
func (s *AuthService) checkUserExists(username, email string) (bool, error) {
	query := `SELECT COUNT(*) FROM users WHERE (username = $1 OR email = $2) AND is_deleted = FALSE`

	var count int
	err := s.db.QueryRow(query, username, email).Scan(&count)
	if err != nil {
		return false, err
	}

	return count > 0, nil
}
