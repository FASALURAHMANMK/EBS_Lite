package services

import (
	"database/sql"
	"fmt"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
	"erp-backend/internal/utils"
)

type AuthService struct {
	db *sql.DB
}

func NewAuthService() *AuthService {
	return &AuthService{
		db: database.GetDB(),
	}
}

func (s *AuthService) Login(req *models.LoginRequest) (*models.LoginResponse, error) {
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

	// Get user permissions
	permissions, err := s.getUserPermissions(user.UserID)
	if err != nil {
		// Log error but don't fail the login
		fmt.Printf("Failed to get user permissions: %v\n", err)
		permissions = []string{}
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
	}

	return &models.LoginResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
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

	// TODO: Generate reset code and send email
	// For now, just return success
	fmt.Printf("Password reset requested for user: %s\n", user.Email)

	return nil
}

func (s *AuthService) ResetPassword(req *models.ResetPasswordRequest) error {
	// TODO: Implement reset code validation
	// For now, just update password directly

	// Hash new password
	hashedPassword, err := utils.HashPassword(req.NewPassword)
	if err != nil {
		return fmt.Errorf("failed to hash password: %w", err)
	}

	// Update password
	query := `UPDATE users SET password_hash = $1, updated_at = CURRENT_TIMESTAMP WHERE email = $2`
	_, err = s.db.Exec(query, hashedPassword, req.Email)
	if err != nil {
		return fmt.Errorf("failed to update password: %w", err)
	}

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
