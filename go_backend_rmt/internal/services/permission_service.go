package services

import (
	"database/sql"
	"fmt"

	"erp-backend/internal/database"
)

type PermissionService struct {
	db *sql.DB
}

func NewPermissionService() *PermissionService {
	return &PermissionService{db: database.GetDB()}
}

func (s *PermissionService) UserHasPermission(userID int, permission string) (bool, error) {
	if userID == 0 || permission == "" {
		return false, fmt.Errorf("invalid permission query")
	}
	var count int
	err := s.db.QueryRow(`
		SELECT COUNT(*)
		FROM users u
		JOIN role_permissions rp ON u.role_id = rp.role_id
		JOIN permissions p ON rp.permission_id = p.permission_id
		WHERE u.user_id = $1 AND p.name = $2 AND u.is_deleted = FALSE
	`, userID, permission).Scan(&count)
	if err != nil {
		return false, fmt.Errorf("failed to check permission: %w", err)
	}
	return count > 0, nil
}

func (s *PermissionService) GetUserRoleID(userID int) (int, error) {
	if userID == 0 {
		return 0, fmt.Errorf("invalid user id")
	}
	var roleID sql.NullInt64
	if err := s.db.QueryRow(`SELECT role_id FROM users WHERE user_id=$1 AND is_deleted=FALSE`, userID).Scan(&roleID); err != nil {
		return 0, fmt.Errorf("failed to get role: %w", err)
	}
	if !roleID.Valid || roleID.Int64 == 0 {
		return 0, fmt.Errorf("role not found")
	}
	return int(roleID.Int64), nil
}
