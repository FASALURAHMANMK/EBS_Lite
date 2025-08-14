package errors

import (
	"errors"
	"fmt"
)

var (
	// Authentication errors
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrAccountLocked      = errors.New("account is locked")
	ErrAccountInactive    = errors.New("account is inactive")
	ErrInvalidToken       = errors.New("invalid token")
	ErrTokenExpired       = errors.New("token expired")
	ErrInvalidTokenType   = errors.New("invalid token type")

	// Authorization errors
	ErrInsufficientPermissions = errors.New("insufficient permissions")
	ErrAccessDenied            = errors.New("access denied")

	// User errors
	ErrUserNotFound      = errors.New("user not found")
	ErrUserAlreadyExists = errors.New("user already exists")
	ErrCannotDeleteSelf  = errors.New("cannot delete your own account")

	// Company errors
	ErrCompanyNotFound      = errors.New("company not found")
	ErrCompanyAlreadyExists = errors.New("company already exists")

	// Location errors
	ErrLocationNotFound      = errors.New("location not found")
	ErrLocationAlreadyExists = errors.New("location already exists")

	// Role errors
	ErrRoleNotFound       = errors.New("role not found")
	ErrRoleAlreadyExists  = errors.New("role already exists")
	ErrSystemRoleReadOnly = errors.New("system roles cannot be modified")
	ErrRoleInUse          = errors.New("role is in use and cannot be deleted")

	// Permission errors
	ErrPermissionNotFound = errors.New("permission not found")

	// Validation errors
	ErrValidationFailed = errors.New("validation failed")
	ErrRequiredField    = errors.New("required field missing")
	ErrInvalidFormat    = errors.New("invalid format")

	// Database errors
	ErrDatabaseConnection = errors.New("database connection failed")
	ErrQueryFailed        = errors.New("database query failed")
	ErrTransactionFailed  = errors.New("database transaction failed")

	// General errors
	ErrInternalServer = errors.New("internal server error")
	ErrNotFound       = errors.New("resource not found")
	ErrBadRequest     = errors.New("bad request")
	ErrConflict       = errors.New("resource conflict")
)

// CustomError represents a custom application error
type CustomError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
	Details string `json:"details,omitempty"`
}

func (e *CustomError) Error() string {
	return e.Message
}

// NewCustomError creates a new custom error
func NewCustomError(code, message, details string) *CustomError {
	return &CustomError{
		Code:    code,
		Message: message,
		Details: details,
	}
}

// ValidationError represents a validation error with field details
type ValidationError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
	Value   string `json:"value,omitempty"`
}

func (e *ValidationError) Error() string {
	return fmt.Sprintf("%s: %s", e.Field, e.Message)
}

// NewValidationError creates a new validation error
func NewValidationError(field, message, value string) *ValidationError {
	return &ValidationError{
		Field:   field,
		Message: message,
		Value:   value,
	}
}

// BusinessError represents a business logic error
type BusinessError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
	Context string `json:"context,omitempty"`
}

func (e *BusinessError) Error() string {
	return e.Message
}

// NewBusinessError creates a new business error
func NewBusinessError(code, message, context string) *BusinessError {
	return &BusinessError{
		Code:    code,
		Message: message,
		Context: context,
	}
}

// APIError represents an API-specific error
type APIError struct {
	StatusCode int         `json:"status_code"`
	Code       string      `json:"code"`
	Message    string      `json:"message"`
	Details    interface{} `json:"details,omitempty"`
}

func (e *APIError) Error() string {
	return e.Message
}

// NewAPIError creates a new API error
func NewAPIError(statusCode int, code, message string, details interface{}) *APIError {
	return &APIError{
		StatusCode: statusCode,
		Code:       code,
		Message:    message,
		Details:    details,
	}
}

// Error codes for consistent error handling
const (
	// Authentication error codes
	CodeInvalidCredentials = "INVALID_CREDENTIALS"
	CodeAccountLocked      = "ACCOUNT_LOCKED"
	CodeAccountInactive    = "ACCOUNT_INACTIVE"
	CodeInvalidToken       = "INVALID_TOKEN"
	CodeTokenExpired       = "TOKEN_EXPIRED"

	// Authorization error codes
	CodeInsufficientPermissions = "INSUFFICIENT_PERMISSIONS"
	CodeAccessDenied            = "ACCESS_DENIED"

	// Resource error codes
	CodeResourceNotFound      = "RESOURCE_NOT_FOUND"
	CodeResourceAlreadyExists = "RESOURCE_ALREADY_EXISTS"
	CodeResourceInUse         = "RESOURCE_IN_USE"

	// Validation error codes
	CodeValidationFailed = "VALIDATION_FAILED"
	CodeRequiredField    = "REQUIRED_FIELD"
	CodeInvalidFormat    = "INVALID_FORMAT"

	// System error codes
	CodeInternalServer    = "INTERNAL_SERVER_ERROR"
	CodeDatabaseError     = "DATABASE_ERROR"
	CodeExternalService   = "EXTERNAL_SERVICE_ERROR"
	CodeRateLimitExceeded = "RATE_LIMIT_EXCEEDED"
)

// IsErrorOfType checks if an error is of a specific type
func IsErrorOfType(err error, target error) bool {
	return errors.Is(err, target)
}

// WrapError wraps an error with additional context
func WrapError(err error, message string) error {
	return fmt.Errorf("%s: %w", message, err)
}
