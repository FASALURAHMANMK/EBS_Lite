package models

import "time"

// LoginRequest represents the payload accepted by the login endpoint.
// Either Email or Username must be supplied along with password and
// device information. DeviceID identifies the client device for the
// session tracking functionality.
type LoginRequest struct {
        Username           string  `json:"username,omitempty" validate:"required_without=Email,omitempty,min=3"`
        Email              string  `json:"email,omitempty" validate:"required_without=Username,omitempty,email"`
        Password           string  `json:"password" validate:"required"`
        DeviceID           string  `json:"device_id" validate:"required"`
        DeviceName         *string `json:"device_name,omitempty"`
        IncludePreferences bool    `json:"include_preferences,omitempty"`
}

// LoginResponse describes the fields returned after a successful login.
// Tokens are issued for subsequent authenticated requests, a session ID
// identifies the device session, and optional company information is
// included when the user belongs to a company.
type LoginResponse struct {
        AccessToken  string       `json:"access_token"`
        RefreshToken string       `json:"refresh_token"`
        SessionID    string       `json:"session_id"`
        User         UserResponse `json:"user"`
        Company      *Company     `json:"company,omitempty"`
}

type RefreshTokenRequest struct {
	RefreshToken string `json:"refresh_token" validate:"required"`
}

type RefreshTokenResponse struct {
	AccessToken string `json:"access_token"`
}

type ForgotPasswordRequest struct {
	Email string `json:"email" validate:"required,email"`
}

type ResetPasswordRequest struct {
	Token       string `json:"token" validate:"required"`
	NewPassword string `json:"new_password" validate:"required,min=6"`
}

type ChangePasswordRequest struct {
	CurrentPassword string `json:"current_password" validate:"required"`
	NewPassword     string `json:"new_password" validate:"required,min=6"`
}

type JWTClaims struct {
	SessionID  string `json:"session_id,omitempty"`
	UserID     int    `json:"user_id"`
	CompanyID  *int   `json:"company_id,omitempty"` // CHANGE: int -> *int
	LocationID *int   `json:"location_id,omitempty"`
	RoleID     *int   `json:"role_id,omitempty"` // CHANGE: int -> *int
	Email      string `json:"email"`
	Type       string `json:"type"` // "access" or "refresh"
}

// Language represents available system languages
type Language struct {
	LanguageCode string    `json:"language_code" db:"language_code"`
	LanguageName string    `json:"language_name" db:"language_name"`
	IsActive     bool      `json:"is_active" db:"is_active"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

// Register request for new users
type RegisterRequest struct {
	Username          string  `json:"username" validate:"required,min=3,max=50"`
	Email             string  `json:"email" validate:"required,email"`
	Password          string  `json:"password" validate:"required,min=6"`
	FirstName         *string `json:"first_name,omitempty"`
	LastName          *string `json:"last_name,omitempty"`
	Phone             *string `json:"phone,omitempty"`
	PreferredLanguage *string `json:"preferred_language,omitempty"`
	SecondaryLanguage *string `json:"secondary_language,omitempty"`
}

// Register response after successful registration
type RegisterResponse struct {
	UserID   int    `json:"user_id"`
	Username string `json:"username"`
	Email    string `json:"email"`
	Message  string `json:"message"`
}
