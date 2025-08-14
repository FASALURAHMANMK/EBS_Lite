package services

import (
	"database/sql"
	"fmt"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type RoleService struct {
	db *sql.DB
}

func NewRoleService() *RoleService {
	return &RoleService{
		db: database.GetDB(),
	}
}

func (s *RoleService) GetRoles() ([]models.Role, error) {
	query := `
		SELECT role_id, name, description, is_system_role, created_at
		FROM roles 
		ORDER BY name
	`

	rows, err := s.db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("failed to get roles: %w", err)
	}
	defer rows.Close()

	var roles []models.Role
	for rows.Next() {
		var role models.Role
		err := rows.Scan(
			&role.RoleID, &role.Name, &role.Description,
			&role.IsSystemRole, &role.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan role: %w", err)
		}
		roles = append(roles, role)
	}

	return roles, nil
}

func (s *RoleService) GetRoleByID(roleID int) (*models.Role, error) {
	query := `
		SELECT role_id, name, description, is_system_role, created_at
		FROM roles 
		WHERE role_id = $1
	`

	var role models.Role
	err := s.db.QueryRow(query, roleID).Scan(
		&role.RoleID, &role.Name, &role.Description,
		&role.IsSystemRole, &role.CreatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("role not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get role: %w", err)
	}

	return &role, nil
}

func (s *RoleService) CreateRole(req *models.CreateRoleRequest) (*models.Role, error) {
	// Check if role name already exists
	exists, err := s.checkRoleNameExists(req.Name)
	if err != nil {
		return nil, fmt.Errorf("failed to check role existence: %w", err)
	}
	if exists {
		return nil, fmt.Errorf("role name already exists")
	}

	query := `
		INSERT INTO roles (name, description)
		VALUES ($1, $2)
		RETURNING role_id, created_at
	`

	var role models.Role
	err = s.db.QueryRow(query, req.Name, req.Description).Scan(
		&role.RoleID, &role.CreatedAt,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to create role: %w", err)
	}

	role.Name = req.Name
	role.Description = req.Description
	role.IsSystemRole = false

	return &role, nil
}

func (s *RoleService) UpdateRole(roleID int, req *models.UpdateRoleRequest) error {
	// Check if role is system role (cannot be updated)
	isSystemRole, err := s.checkIsSystemRole(roleID)
	if err != nil {
		return fmt.Errorf("failed to check role type: %w", err)
	}
	if isSystemRole {
		return fmt.Errorf("system roles cannot be updated")
	}

	setParts := []string{}
	args := []interface{}{}
	argCount := 0

	if req.Name != nil {
		// Check if new name already exists (excluding current role)
		exists, err := s.checkRoleNameExistsExcluding(roleID, *req.Name)
		if err != nil {
			return fmt.Errorf("failed to check role name existence: %w", err)
		}
		if exists {
			return fmt.Errorf("role name already exists")
		}

		argCount++
		setParts = append(setParts, fmt.Sprintf("name = $%d", argCount))
		args = append(args, *req.Name)
	}
	if req.Description != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("description = $%d", argCount))
		args = append(args, *req.Description)
	}

	if len(setParts) == 0 {
		return fmt.Errorf("no fields to update")
	}

	argCount++
	query := fmt.Sprintf("UPDATE roles SET %s WHERE role_id = $%d",
		fmt.Sprintf("%s", setParts), argCount)
	args = append(args, roleID)

	result, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update role: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("role not found")
	}

	return nil
}

func (s *RoleService) DeleteRole(roleID int) error {
	// Check if role is system role (cannot be deleted)
	isSystemRole, err := s.checkIsSystemRole(roleID)
	if err != nil {
		return fmt.Errorf("failed to check role type: %w", err)
	}
	if isSystemRole {
		return fmt.Errorf("system roles cannot be deleted")
	}

	// Check if role is in use
	inUse, err := s.checkRoleInUse(roleID)
	if err != nil {
		return fmt.Errorf("failed to check role usage: %w", err)
	}
	if inUse {
		return fmt.Errorf("role is in use and cannot be deleted")
	}

	query := `DELETE FROM roles WHERE role_id = $1`

	result, err := s.db.Exec(query, roleID)
	if err != nil {
		return fmt.Errorf("failed to delete role: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("role not found")
	}

	return nil
}

func (s *RoleService) GetPermissions() ([]models.Permission, error) {
	query := `
		SELECT permission_id, name, description, module, action
		FROM permissions 
		ORDER BY module, action
	`

	rows, err := s.db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("failed to get permissions: %w", err)
	}
	defer rows.Close()

	var permissions []models.Permission
	for rows.Next() {
		var permission models.Permission
		err := rows.Scan(
			&permission.PermissionID, &permission.Name, &permission.Description,
			&permission.Module, &permission.Action,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan permission: %w", err)
		}
		permissions = append(permissions, permission)
	}

	return permissions, nil
}

func (s *RoleService) GetRolePermissions(roleID int) (*models.RoleWithPermissions, error) {
	// Get role details
	role, err := s.GetRoleByID(roleID)
	if err != nil {
		return nil, err
	}

	// Get role permissions
	query := `
		SELECT p.permission_id, p.name, p.description, p.module, p.action
		FROM permissions p
		JOIN role_permissions rp ON p.permission_id = rp.permission_id
		WHERE rp.role_id = $1
		ORDER BY p.module, p.action
	`

	rows, err := s.db.Query(query, roleID)
	if err != nil {
		return nil, fmt.Errorf("failed to get role permissions: %w", err)
	}
	defer rows.Close()

	var permissions []models.Permission
	for rows.Next() {
		var permission models.Permission
		err := rows.Scan(
			&permission.PermissionID, &permission.Name, &permission.Description,
			&permission.Module, &permission.Action,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan permission: %w", err)
		}
		permissions = append(permissions, permission)
	}

	return &models.RoleWithPermissions{
		Role:        *role,
		Permissions: permissions,
	}, nil
}

func (s *RoleService) AssignPermissions(roleID int, req *models.AssignPermissionsRequest) error {
	// Check if role exists and is not system role
	isSystemRole, err := s.checkIsSystemRole(roleID)
	if err != nil {
		return fmt.Errorf("failed to check role type: %w", err)
	}
	if isSystemRole {
		return fmt.Errorf("system role permissions cannot be modified")
	}

	// Use transaction for atomicity
	return database.WithTransaction(func(tx *sql.Tx) error {
		// Remove existing permissions
		_, err := tx.Exec("DELETE FROM role_permissions WHERE role_id = $1", roleID)
		if err != nil {
			return fmt.Errorf("failed to remove existing permissions: %w", err)
		}

		// Add new permissions
		for _, permissionID := range req.PermissionIDs {
			_, err := tx.Exec(
				"INSERT INTO role_permissions (role_id, permission_id) VALUES ($1, $2)",
				roleID, permissionID,
			)
			if err != nil {
				return fmt.Errorf("failed to assign permission %d: %w", permissionID, err)
			}
		}

		return nil
	})
}

// Helper methods
func (s *RoleService) checkRoleNameExists(name string) (bool, error) {
	query := `SELECT COUNT(*) FROM roles WHERE name = $1`

	var count int
	err := s.db.QueryRow(query, name).Scan(&count)
	if err != nil {
		return false, err
	}

	return count > 0, nil
}

func (s *RoleService) checkRoleNameExistsExcluding(roleID int, name string) (bool, error) {
	query := `SELECT COUNT(*) FROM roles WHERE name = $1 AND role_id != $2`

	var count int
	err := s.db.QueryRow(query, name, roleID).Scan(&count)
	if err != nil {
		return false, err
	}

	return count > 0, nil
}

func (s *RoleService) checkIsSystemRole(roleID int) (bool, error) {
	query := `SELECT is_system_role FROM roles WHERE role_id = $1`

	var isSystemRole bool
	err := s.db.QueryRow(query, roleID).Scan(&isSystemRole)
	if err == sql.ErrNoRows {
		return false, fmt.Errorf("role not found")
	}
	if err != nil {
		return false, err
	}

	return isSystemRole, nil
}

func (s *RoleService) checkRoleInUse(roleID int) (bool, error) {
	query := `SELECT COUNT(*) FROM users WHERE role_id = $1 AND is_deleted = FALSE`

	var count int
	err := s.db.QueryRow(query, roleID).Scan(&count)
	if err != nil {
		return false, err
	}

	return count > 0, nil
}
