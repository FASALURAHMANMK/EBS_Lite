package services

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type EmployeeService struct {
	db *sql.DB
}

func NewEmployeeService() *EmployeeService {
	return &EmployeeService{db: database.GetDB()}
}

func (s *EmployeeService) GetEmployees(companyID int, filters map[string]string) ([]models.Employee, error) {
	query := `
                SELECT employee_id, company_id, location_id, employee_code, name, phone, email,
                       address, position, department, salary, hire_date, is_active,
                       last_check_in, last_check_out, leave_balance,
                       sync_status, created_at, updated_at, is_deleted
                FROM employees
                WHERE company_id = $1 AND is_deleted = FALSE`
	args := []interface{}{companyID}
	argPos := 1
	if dept := filters["department"]; dept != "" {
		argPos++
		query += fmt.Sprintf(" AND department = $%d", argPos)
		args = append(args, dept)
	}
	if status := filters["status"]; status != "" {
		argPos++
		query += fmt.Sprintf(" AND is_active = $%d", argPos)
		args = append(args, status == "active")
	}
	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get employees: %w", err)
	}
	defer rows.Close()

	var employees []models.Employee
	for rows.Next() {
		var e models.Employee
		if err := rows.Scan(
			&e.EmployeeID, &e.CompanyID, &e.LocationID, &e.EmployeeCode, &e.Name,
			&e.Phone, &e.Email, &e.Address, &e.Position, &e.Department,
			&e.Salary, &e.HireDate, &e.IsActive, &e.LastCheckIn, &e.LastCheckOut, &e.LeaveBalance,
			&e.SyncStatus, &e.CreatedAt, &e.UpdatedAt, &e.IsDeleted,
		); err != nil {
			return nil, fmt.Errorf("failed to scan employee: %w", err)
		}
		employees = append(employees, e)
	}
	return employees, nil
}

func (s *EmployeeService) CreateEmployee(companyID int, req *models.CreateEmployeeRequest) (*models.Employee, error) {
	isActive := true
	if req.IsActive != nil {
		isActive = *req.IsActive
	}
	query := `
                INSERT INTO employees (company_id, location_id, employee_code, name, phone, email, address,
                                       position, department, salary, hire_date, is_active, leave_balance)
                VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
                RETURNING employee_id, created_at`
	var emp models.Employee
	leaveBalance := 0.0
	if req.LeaveBalance != nil {
		leaveBalance = *req.LeaveBalance
	}
	err := s.db.QueryRow(query,
		companyID, req.LocationID, req.EmployeeCode, req.Name, req.Phone, req.Email, req.Address,
		req.Position, req.Department, req.Salary, req.HireDate, isActive, leaveBalance,
	).Scan(&emp.EmployeeID, &emp.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create employee: %w", err)
	}
	emp.CompanyID = companyID
	emp.LocationID = req.LocationID
	emp.EmployeeCode = req.EmployeeCode
	emp.Name = req.Name
	emp.Phone = req.Phone
	emp.Email = req.Email
	emp.Address = req.Address
	emp.Position = req.Position
	emp.Department = req.Department
	emp.Salary = req.Salary
	emp.HireDate = req.HireDate
	emp.IsActive = isActive
	emp.LeaveBalance = &leaveBalance
	return &emp, nil
}

func (s *EmployeeService) UpdateEmployee(employeeID, companyID int, req *models.UpdateEmployeeRequest) error {
	updates := []string{}
	args := []interface{}{}
	argPos := 1
	if req.LocationID != nil {
		updates = append(updates, fmt.Sprintf("location_id = $%d", argPos))
		args = append(args, *req.LocationID)
		argPos++
	}
	if req.EmployeeCode != nil {
		updates = append(updates, fmt.Sprintf("employee_code = $%d", argPos))
		args = append(args, *req.EmployeeCode)
		argPos++
	}
	if req.Name != nil {
		updates = append(updates, fmt.Sprintf("name = $%d", argPos))
		args = append(args, *req.Name)
		argPos++
	}
	if req.Phone != nil {
		updates = append(updates, fmt.Sprintf("phone = $%d", argPos))
		args = append(args, *req.Phone)
		argPos++
	}
	if req.Email != nil {
		updates = append(updates, fmt.Sprintf("email = $%d", argPos))
		args = append(args, *req.Email)
		argPos++
	}
	if req.Address != nil {
		updates = append(updates, fmt.Sprintf("address = $%d", argPos))
		args = append(args, *req.Address)
		argPos++
	}
	if req.Position != nil {
		updates = append(updates, fmt.Sprintf("position = $%d", argPos))
		args = append(args, *req.Position)
		argPos++
	}
	if req.Department != nil {
		updates = append(updates, fmt.Sprintf("department = $%d", argPos))
		args = append(args, *req.Department)
		argPos++
	}
	if req.Salary != nil {
		updates = append(updates, fmt.Sprintf("salary = $%d", argPos))
		args = append(args, *req.Salary)
		argPos++
	}
	if req.HireDate != nil {
		updates = append(updates, fmt.Sprintf("hire_date = $%d", argPos))
		args = append(args, *req.HireDate)
		argPos++
	}
	if req.IsActive != nil {
		updates = append(updates, fmt.Sprintf("is_active = $%d", argPos))
		args = append(args, *req.IsActive)
		argPos++
	}
	if req.LeaveBalance != nil {
		updates = append(updates, fmt.Sprintf("leave_balance = $%d", argPos))
		args = append(args, *req.LeaveBalance)
		argPos++
	}
	if len(updates) == 0 {
		return nil
	}
	updates = append(updates, fmt.Sprintf("updated_at = $%d", argPos))
	args = append(args, time.Now())
	argPos++
	query := fmt.Sprintf("UPDATE employees SET %s WHERE employee_id = $%d AND company_id = $%d AND is_deleted = FALSE",
		strings.Join(updates, ", "), argPos, argPos+1)
	args = append(args, employeeID, companyID)
	result, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update employee: %w", err)
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("employee not found")
	}
	return nil
}

func (s *EmployeeService) DeleteEmployee(employeeID, companyID int) error {
	result, err := s.db.Exec(`UPDATE employees SET is_deleted = TRUE, updated_at = CURRENT_TIMESTAMP WHERE employee_id = $1 AND company_id = $2 AND is_deleted = FALSE`, employeeID, companyID)
	if err != nil {
		return fmt.Errorf("failed to delete employee: %w", err)
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("employee not found")
	}
	return nil
}
