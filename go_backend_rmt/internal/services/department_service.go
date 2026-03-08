package services

import (
	"database/sql"
	"fmt"
	"strings"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type DepartmentService struct {
	db *sql.DB
}

func NewDepartmentService() *DepartmentService {
	return &DepartmentService{db: database.GetDB()}
}

func (s *DepartmentService) List(companyID int) ([]models.Department, error) {
	rows, err := s.db.Query(`
		SELECT department_id, company_id, name, is_active, created_by, updated_by,
		       sync_status, created_at, updated_at, is_deleted
		FROM departments
		WHERE company_id = $1 AND is_deleted = FALSE
		ORDER BY name
	`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to list departments: %w", err)
	}
	defer rows.Close()

	var list []models.Department
	for rows.Next() {
		var d models.Department
		if err := rows.Scan(
			&d.DepartmentID, &d.CompanyID, &d.Name, &d.IsActive, &d.CreatedBy, &d.UpdatedBy,
			&d.SyncStatus, &d.CreatedAt, &d.UpdatedAt, &d.IsDeleted,
		); err != nil {
			return nil, fmt.Errorf("failed to scan department: %w", err)
		}
		list = append(list, d)
	}
	return list, nil
}

func (s *DepartmentService) Create(companyID, userID int, req *models.CreateDepartmentRequest) (*models.Department, error) {
	name := strings.TrimSpace(req.Name)
	if name == "" {
		return nil, fmt.Errorf("name is required")
	}
	active := true
	if req.IsActive != nil {
		active = *req.IsActive
	}

	var d models.Department
	err := s.db.QueryRow(`
		INSERT INTO departments (company_id, name, is_active, created_by, updated_by)
		VALUES ($1,$2,$3,$4,$4)
		RETURNING department_id, created_at, updated_at
	`, companyID, name, active, userID).Scan(&d.DepartmentID, &d.CreatedAt, &d.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create department: %w", err)
	}
	d.CompanyID = companyID
	d.Name = name
	d.IsActive = active
	d.CreatedBy = userID
	d.UpdatedBy = &userID
	d.SyncStatus = "synced"
	return &d, nil
}

func (s *DepartmentService) Update(companyID, departmentID, userID int, req *models.UpdateDepartmentRequest) error {
	set := []string{}
	args := []interface{}{}
	i := 1
	if req.Name != nil {
		name := strings.TrimSpace(*req.Name)
		if name == "" {
			return fmt.Errorf("name cannot be empty")
		}
		set = append(set, fmt.Sprintf("name = $%d", i))
		args = append(args, name)
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

	args = append(args, departmentID, companyID)
	query := fmt.Sprintf(`
		UPDATE departments
		SET %s
		WHERE department_id = $%d AND company_id = $%d AND is_deleted = FALSE
	`, strings.Join(set, ", "), i, i+1)
	res, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update department: %w", err)
	}
	aff, _ := res.RowsAffected()
	if aff == 0 {
		return fmt.Errorf("department not found")
	}
	return nil
}

func (s *DepartmentService) Delete(companyID, departmentID, userID int) error {
	res, err := s.db.Exec(`
		UPDATE departments
		SET is_deleted = TRUE, updated_by = $1, updated_at = CURRENT_TIMESTAMP
		WHERE department_id = $2 AND company_id = $3 AND is_deleted = FALSE
	`, userID, departmentID, companyID)
	if err != nil {
		return fmt.Errorf("failed to delete department: %w", err)
	}
	aff, _ := res.RowsAffected()
	if aff == 0 {
		return fmt.Errorf("department not found")
	}
	return nil
}
