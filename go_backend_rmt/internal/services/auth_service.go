package services

import (
	"database/sql"
	"errors"
	"fmt"
	"log"
	"net/url"
	"path"
	"strings"
	"time"

	"erp-backend/internal/config"
	"erp-backend/internal/database"
	"erp-backend/internal/models"
	"erp-backend/internal/utils"
	"github.com/google/uuid"
	"github.com/lib/pq"
)

type AuthService struct {
	db  *sql.DB
	cfg *config.Config
}

var ErrDeviceSessionCreate = errors.New("device session creation failed")

func NewAuthService() *AuthService {
	return &AuthService{
		db:  database.GetDB(),
		cfg: config.Load(),
	}
}

func (s *AuthService) Login(req *models.LoginRequest, ipAddress, userAgent string) (*models.LoginResponse, error) {
	// Get user by username or email
	var (
		user *models.User
		err  error
	)
	if req.Username != "" {
		user, err = s.getUserByUsername(req.Username)
	} else {
		user, err = s.getUserByEmail(req.Email)
	}
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
		return nil, fmt.Errorf("%w: %v", ErrDeviceSessionCreate, err)
	}
	if sessionID == "" {
		return nil, fmt.Errorf("%w: empty session id", ErrDeviceSessionCreate)
	}

	// Generate tokens
	accessToken, err := utils.GenerateAccessToken(user, sessionID, s.cfg.JWTExpiry)
	if err != nil {
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}

	refreshToken, err := utils.GenerateRefreshToken(user, sessionID, s.cfg.JWTRefreshExpiry)
	if err != nil {
		return nil, fmt.Errorf("failed to generate refresh token: %w", err)
	}

	// Update last login
	err = s.updateLastLogin(user.UserID)
	if err != nil {
		// Log error but don't fail the login
		log.Printf("auth_service: failed to update last login: %v", err)
	}

	// Get user permissions
	permissions, err := s.getUserPermissions(user.UserID)
	if err != nil {
		// Log error but don't fail the login
		log.Printf("auth_service: failed to get user permissions: %v", err)
		permissions = []string{}
	}

	var prefs map[string]string
	if req.IncludePreferences {
		prefsSvc := NewUserPreferencesService()
		prefs, err = prefsSvc.GetPreferences(user.UserID)
		if err != nil {
			prefs = map[string]string{}
		}
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

	var company *models.Company
	if user.CompanyID != nil {
		company, _ = s.getCompanyByID(*user.CompanyID)
	}

	return &models.LoginResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		SessionID:    sessionID,
		User:         userResponse,
		Company:      company,
	}, nil
}

// Logout deactivates a device session for the given user
func (s *AuthService) Logout(userID int, sessionID string) error {
	if sessionID == "" {
		return fmt.Errorf("session ID required")
	}
	_, err := s.db.Exec(`UPDATE device_sessions SET is_active=FALSE WHERE user_id=$1 AND session_id=$2`, userID, sessionID)
	if err != nil {
		return fmt.Errorf("failed to revoke session: %w", err)
	}
	return nil
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
	accessToken, err := utils.GenerateAccessToken(user, claims.SessionID, s.cfg.JWTExpiry)
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
	resetLink, err := buildResetLink(s.cfg.FrontendBaseURL, token)
	if err != nil {
		return fmt.Errorf("failed to build reset link: %w", err)
	}
	subject := "Password Reset Request"
	body := fmt.Sprintf("Click the link to reset your password: %s", resetLink)
	if err := utils.SendEmail(user.Email, subject, body); err != nil {
		return fmt.Errorf("failed to send reset email: %w", err)
	}

	return nil
}

func buildResetLink(baseURL, token string) (string, error) {
	trimmed := strings.TrimSpace(baseURL)
	if trimmed == "" {
		return "", fmt.Errorf("frontend base url is empty")
	}
	parsed, err := url.Parse(trimmed)
	if err != nil {
		return "", fmt.Errorf("invalid frontend base url: %w", err)
	}
	if parsed.Scheme == "" || parsed.Host == "" {
		return "", fmt.Errorf("frontend base url must include scheme and host")
	}

	resetPath := "reset-password"
	joinedPath := path.Join(parsed.Path, resetPath)
	if !strings.HasPrefix(joinedPath, "/") {
		joinedPath = "/" + joinedPath
	}

	resetURL := *parsed
	resetURL.Path = joinedPath
	q := resetURL.Query()
	q.Set("token", token)
	resetURL.RawQuery = q.Encode()
	return resetURL.String(), nil
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

	policy, err := s.getPasswordPolicyForUser(userID)
	if err != nil {
		return fmt.Errorf("failed to load password policy: %w", err)
	}
	if err := utils.ValidatePasswordAgainstPolicy(req.NewPassword, policy); err != nil {
		return err
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

func (s *AuthService) GetMe(userID int) (*models.AuthMeResponse, error) {
	user, err := s.getUserByID(userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	permissions, err := s.getUserPermissions(userID)
	if err != nil {
		permissions = []string{}
	}

	// Fetch user preferences to include in response
	prefsSvc := NewUserPreferencesService()
	prefs, prefsErr := prefsSvc.GetPreferences(userID)
	if prefsErr != nil {
		prefs = map[string]string{}
	}

	userResp := models.UserResponse{
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

	var company *models.Company
	if user.CompanyID != nil {
		companySvc := NewCompanyService()
		company, _ = companySvc.GetCompanyByID(*user.CompanyID)
	}

	return &models.AuthMeResponse{
		User:    userResp,
		Company: company,
	}, nil
}

func (s *AuthService) VerifyCredentials(companyID int, req *models.VerifyCredentialsRequest) (*models.VerifyCredentialsResponse, error) {
	if req == nil {
		return nil, fmt.Errorf("request is nil")
	}
	if strings.TrimSpace(req.Password) == "" {
		return nil, fmt.Errorf("invalid credentials")
	}
	identifierUser := strings.TrimSpace(req.Username)
	identifierEmail := strings.TrimSpace(req.Email)
	if identifierUser == "" && identifierEmail == "" {
		return nil, fmt.Errorf("invalid credentials")
	}

	var (
		user *models.User
		err  error
	)
	if identifierUser != "" {
		user, err = s.getUserByUsername(identifierUser)
	} else {
		user, err = s.getUserByEmail(identifierEmail)
	}
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("invalid credentials")
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}
	if user.CompanyID == nil || *user.CompanyID != companyID {
		return nil, fmt.Errorf("invalid credentials")
	}
	if !user.IsActive || user.IsLocked {
		return nil, fmt.Errorf("invalid credentials")
	}

	valid, err := utils.VerifyPassword(req.Password, user.PasswordHash)
	if err != nil {
		return nil, fmt.Errorf("failed to verify password: %w", err)
	}
	if !valid {
		return nil, fmt.Errorf("invalid credentials")
	}

	perms, err := s.getUserPermissions(user.UserID)
	if err != nil {
		perms = []string{}
	}
	required := make(map[string]struct{}, len(req.RequiredPermissions))
	for _, p := range req.RequiredPermissions {
		p = strings.TrimSpace(p)
		if p != "" {
			required[p] = struct{}{}
		}
	}
	if len(required) > 0 {
		have := make(map[string]struct{}, len(perms))
		for _, p := range perms {
			have[p] = struct{}{}
		}
		for p := range required {
			if _, ok := have[p]; !ok {
				return nil, fmt.Errorf("insufficient permissions")
			}
		}
	}

	resp := &models.VerifyCredentialsResponse{
		UserID:      user.UserID,
		Username:    user.Username,
		Permissions: perms,
	}

	// Issue a short-lived override token when permissions were explicitly requested.
	// This token is later attached to high-risk requests (discount overrides, voids, etc.)
	// so the backend can enforce approvals server-side.
	if len(required) > 0 {
		requiredList := make([]string, 0, len(required))
		for p := range required {
			requiredList = append(requiredList, p)
		}
		expiry := s.overrideExpiryForCompany(companyID)
		token, err := utils.GenerateManagerOverrideToken(user.UserID, companyID, requiredList, expiry)
		if err != nil {
			return nil, err
		}
		resp.OverrideToken = token
		resp.ExpiresAtUnix = time.Now().Add(expiry).Unix()
	}

	return resp, nil
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

func (s *AuthService) getUserByUsername(username string) (*models.User, error) {
	query := `
                SELECT user_id, company_id, location_id, role_id, username, email, password_hash,
                           first_name, last_name, phone, preferred_language, secondary_language,
                           max_allowed_devices, is_locked, is_active, last_login, sync_status,
                           created_at, updated_at, is_deleted
                FROM users
                WHERE username = $1 AND is_deleted = FALSE
        `

	var user models.User
	err := s.db.QueryRow(query, username).Scan(
		&user.UserID, &user.CompanyID, &user.LocationID, &user.RoleID,
		&user.Username, &user.Email, &user.PasswordHash, &user.FirstName,
		&user.LastName, &user.Phone, &user.PreferredLanguage, &user.SecondaryLanguage,
		&user.MaxAllowedDevices, &user.IsLocked, &user.IsActive, &user.LastLogin,
		&user.SyncStatus, &user.CreatedAt, &user.UpdatedAt, &user.IsDeleted,
	)

	return &user, err
}

func (s *AuthService) getCompanyByID(companyID int) (*models.Company, error) {
	query := `
                SELECT company_id, name, logo, address, phone, email, tax_number,
                       currency_id, is_active, created_at, updated_at
                FROM companies
                WHERE company_id = $1 AND is_active = TRUE
        `

	var company models.Company
	err := s.db.QueryRow(query, companyID).Scan(
		&company.CompanyID, &company.Name, &company.Logo, &company.Address,
		&company.Phone, &company.Email, &company.TaxNumber, &company.CurrencyID,
		&company.IsActive, &company.CreatedAt, &company.UpdatedAt,
	)

	return &company, err
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

	if err := utils.ValidatePasswordAgainstPolicy(req.Password, utils.DefaultPasswordPolicy()); err != nil {
		return nil, err
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

func (s *AuthService) getPasswordPolicyForUser(userID int) (utils.PasswordPolicy, error) {
	policy := utils.DefaultPasswordPolicy()
	var companyID sql.NullInt64
	if err := s.db.QueryRow(`SELECT company_id FROM users WHERE user_id = $1 AND is_deleted = FALSE`, userID).Scan(&companyID); err != nil {
		if err == sql.ErrNoRows {
			return policy, nil
		}
		return policy, err
	}
	if !companyID.Valid {
		return policy, nil
	}
	return s.getPasswordPolicyForCompany(int(companyID.Int64))
}

func (s *AuthService) getPasswordPolicyForCompany(companyID int) (utils.PasswordPolicy, error) {
	policy := utils.DefaultPasswordPolicy()
	if companyID == 0 {
		return policy, nil
	}
	settingsSvc := NewSettingsService()
	cfg, err := settingsSvc.GetSecurityPolicy(companyID)
	if err != nil {
		return policy, err
	}
	return utils.NormalizePasswordPolicy(utils.PasswordPolicy{
		MinPasswordLength:        cfg.MinPasswordLength,
		RequireUppercase:         cfg.RequireUppercase,
		RequireLowercase:         cfg.RequireLowercase,
		RequireNumber:            cfg.RequireNumber,
		RequireSpecial:           cfg.RequireSpecial,
		SessionIdleTimeoutMins:   cfg.SessionIdleTimeoutMins,
		ElevatedAccessWindowMins: cfg.ElevatedAccessWindowMins,
	}), nil
}

func (s *AuthService) overrideExpiryForCompany(companyID int) time.Duration {
	policy, err := s.getPasswordPolicyForCompany(companyID)
	if err != nil {
		return 5 * time.Minute
	}
	return time.Duration(policy.ElevatedAccessWindowMins) * time.Minute
}
