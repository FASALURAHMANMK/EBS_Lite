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
}
