package models

type VerifyCredentialsRequest struct {
	Username            string   `json:"username,omitempty"`
	Email               string   `json:"email,omitempty"`
	Password            string   `json:"password" validate:"required"`
	RequiredPermissions []string `json:"required_permissions,omitempty"`
}

type VerifyCredentialsResponse struct {
	UserID      int      `json:"user_id"`
	Username    string   `json:"username"`
	Permissions []string `json:"permissions"`
	// OverrideToken is a short-lived token that can be attached to a high-risk
	// action request as proof of manager approval.
	OverrideToken string `json:"override_token,omitempty"`
	ExpiresAtUnix int64  `json:"expires_at_unix,omitempty"`
}
