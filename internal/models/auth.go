package models

import "time"

type LoginRequest struct {
	Email    string `json:"email" validate:"required,email"`
	Password string `json:"password" validate:"required"`
}

type LoginResponse struct {
	AccessToken  string       `json:"access_token"`
	RefreshToken string       `json:"refresh_token"`
	User         UserResponse `json:"user"`
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
	Email       string `json:"email" validate:"required,email"`
	ResetCode   string `json:"reset_code" validate:"required"`
	NewPassword string `json:"new_password" validate:"required,min=6"`
}

type ChangePasswordRequest struct {
	CurrentPassword string `json:"current_password" validate:"required"`
	NewPassword     string `json:"new_password" validate:"required,min=6"`
}

type JWTClaims struct {
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
