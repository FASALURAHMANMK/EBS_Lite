package models

type Role struct {
	RoleID       int    `json:"role_id" db:"role_id"`
	Name         string `json:"name" db:"name" validate:"required,min=2,max=100"`
	Description  string `json:"description" db:"description"`
	IsSystemRole bool   `json:"is_system_role" db:"is_system_role"`
	BaseModel
}

type Permission struct {
	PermissionID int    `json:"permission_id" db:"permission_id"`
	Name         string `json:"name" db:"name"`
	Description  string `json:"description" db:"description"`
	Module       string `json:"module" db:"module"`
	Action       string `json:"action" db:"action"`
}

type RolePermission struct {
	RoleID       int `json:"role_id" db:"role_id"`
	PermissionID int `json:"permission_id" db:"permission_id"`
}

type CreateRoleRequest struct {
	Name        string `json:"name" validate:"required,min=2,max=100"`
	Description string `json:"description"`
}

type UpdateRoleRequest struct {
	Name        *string `json:"name,omitempty" validate:"omitempty,min=2,max=100"`
	Description *string `json:"description,omitempty"`
}

type AssignPermissionsRequest struct {
	PermissionIDs []int `json:"permission_ids" validate:"required,min=1"`
}

type RoleWithPermissions struct {
	Role
	Permissions []Permission `json:"permissions"`
}
