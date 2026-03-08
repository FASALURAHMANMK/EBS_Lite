package services

import (
	"database/sql"
	"fmt"
	"strings"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type DesignationService struct {
	db *sql.DB
}

func NewDesignationService() *DesignationService {
	return &DesignationService{db: database.GetDB()}
}

func (s *DesignationService) List(companyID int, departmentID *int) ([]models.Designation, error) {
	query := `
		SELECT designation_id, company_id, department_id, default_app_role_id, name, description, is_active, created_by, updated_by,
		       sync_status, created_at, updated_at, is_deleted
		FROM designations
		WHERE company_id = $1 AND is_deleted = FALSE`
	args := []interface{}{companyID}
	argPos := 1
	if departmentID != nil {
		argPos++
		query += fmt.Sprintf(" AND department_id = $%d", argPos)
		args = append(args, *departmentID)
	}
	query += " ORDER BY name"
	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to list designations: %w", err)
	}
	defer rows.Close()

	var list []models.Designation
	for rows.Next() {
		var r models.Designation
		if err := rows.Scan(
			&r.DesignationID, &r.CompanyID, &r.DepartmentID, &r.DefaultAppRoleID, &r.Name, &r.Description, &r.IsActive, &r.CreatedBy, &r.UpdatedBy,
			&r.SyncStatus, &r.CreatedAt, &r.UpdatedAt, &r.IsDeleted,
		); err != nil {
			return nil, fmt.Errorf("failed to scan designation: %w", err)
		}
		list = append(list, r)
	}
	return list, nil
}

func (s *DesignationService) Create(companyID, userID int, req *models.CreateDesignationRequest) (*models.Designation, error) {
	name := strings.TrimSpace(req.Name)
	if name == "" {
		return nil, fmt.Errorf("name is required")
	}

	var ok bool
	if err := s.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM departments WHERE department_id = $1 AND company_id = $2 AND is_deleted = FALSE)`, req.DepartmentID, companyID).Scan(&ok); err != nil {
		return nil, fmt.Errorf("failed to verify department: %w", err)
	}
	if !ok {
		return nil, fmt.Errorf("department not found")
	}

	if req.DefaultAppRoleID != nil {
		if *req.DefaultAppRoleID <= 0 {
			req.DefaultAppRoleID = nil
		}
	}

	if req.DefaultAppRoleID != nil {
		var roleOk bool
		if err := s.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM roles WHERE role_id = $1)`, *req.DefaultAppRoleID).Scan(&roleOk); err != nil {
			return nil, fmt.Errorf("failed to verify default app role: %w", err)
		}
		if !roleOk {
			return nil, fmt.Errorf("default app role not found")
		}
	}

	active := true
	if req.IsActive != nil {
		active = *req.IsActive
	}

	var r models.Designation
	err := s.db.QueryRow(`
		INSERT INTO designations (company_id, department_id, default_app_role_id, name, description, is_active, created_by, updated_by)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$7)
		RETURNING designation_id, created_at, updated_at
	`, companyID, req.DepartmentID, req.DefaultAppRoleID, name, req.Description, active, userID).Scan(&r.DesignationID, &r.CreatedAt, &r.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create designation: %w", err)
	}
	r.CompanyID = companyID
	r.DepartmentID = &req.DepartmentID
	r.DefaultAppRoleID = req.DefaultAppRoleID
	r.Name = name
	r.Description = req.Description
	r.IsActive = active
	r.CreatedBy = userID
	r.UpdatedBy = &userID
	r.SyncStatus = "synced"
	return &r, nil
}

func (s *DesignationService) Update(companyID, designationID, userID int, req *models.UpdateDesignationRequest) error {
	set := []string{}
	args := []interface{}{}
	i := 1

	if req.DepartmentID != nil {
		var ok bool
		if err := s.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM departments WHERE department_id = $1 AND company_id = $2 AND is_deleted = FALSE)`, *req.DepartmentID, companyID).Scan(&ok); err != nil {
			return fmt.Errorf("failed to verify department: %w", err)
		}
		if !ok {
			return fmt.Errorf("department not found")
		}
		set = append(set, fmt.Sprintf("department_id = $%d", i))
		args = append(args, *req.DepartmentID)
		i++
	}
	if req.DefaultAppRoleID != nil {
		if *req.DefaultAppRoleID <= 0 {
			set = append(set, "default_app_role_id = NULL")
		} else {
			var roleOk bool
			if err := s.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM roles WHERE role_id = $1)`, *req.DefaultAppRoleID).Scan(&roleOk); err != nil {
				return fmt.Errorf("failed to verify default app role: %w", err)
			}
			if !roleOk {
				return fmt.Errorf("default app role not found")
			}
			set = append(set, fmt.Sprintf("default_app_role_id = $%d", i))
			args = append(args, *req.DefaultAppRoleID)
			i++
		}
	}
	if req.Name != nil {
		name := strings.TrimSpace(*req.Name)
		if name == "" {
			return fmt.Errorf("name cannot be empty")
		}
		set = append(set, fmt.Sprintf("name = $%d", i))
		args = append(args, name)
		i++
	}
	if req.Description != nil {
		set = append(set, fmt.Sprintf("description = $%d", i))
		args = append(args, *req.Description)
		i++
	}
	if req.IsActive != nil {
		set = append(set, fmt.Sprintf("is_active = $%d", i))
		args = append(args, *req.IsActive)
		i++
	}
	if len(set) == 0 {
		return nil
	}

	set = append(set, "updated_at = CURRENT_TIMESTAMP")
	set = append(set, fmt.Sprintf("updated_by = $%d", i))
	args = append(args, userID)
	i++

	args = append(args, designationID, companyID)
	query := fmt.Sprintf(`
		UPDATE designations
		SET %s
		WHERE designation_id = $%d AND company_id = $%d AND is_deleted = FALSE
	`, strings.Join(set, ", "), i, i+1)

	res, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update designation: %w", err)
	}
	aff, _ := res.RowsAffected()
	if aff == 0 {
		return fmt.Errorf("designation not found")
	}
	return nil
}

func (s *DesignationService) Delete(companyID, designationID, userID int) error {
	res, err := s.db.Exec(`
		UPDATE designations
		SET is_deleted = TRUE, updated_by = $1, updated_at = CURRENT_TIMESTAMP
		WHERE designation_id = $2 AND company_id = $3 AND is_deleted = FALSE
	`, userID, designationID, companyID)
	if err != nil {
		return fmt.Errorf("failed to delete designation: %w", err)
	}
	aff, _ := res.RowsAffected()
	if aff == 0 {
		return fmt.Errorf("designation not found")
	}
	return nil
}
