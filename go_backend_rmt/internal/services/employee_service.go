package services

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
	"erp-backend/internal/utils"
)

type EmployeeService struct {
	db *sql.DB
}

func NewEmployeeService() *EmployeeService {
	return &EmployeeService{db: database.GetDB()}
}

type queryer interface {
	QueryRow(query string, args ...any) *sql.Row
}

type dbQueryer struct {
	db *sql.DB
}

func (q dbQueryer) QueryRow(query string, args ...any) *sql.Row {
	return q.db.QueryRow(query, args...)
}

type txQueryer struct {
	tx *sql.Tx
}

func (q txQueryer) QueryRow(query string, args ...any) *sql.Row {
	return q.tx.QueryRow(query, args...)
}

func (s *EmployeeService) GetEmployees(companyID int, filters map[string]string) ([]models.Employee, error) {
	query := `
		SELECT e.employee_id, e.company_id, e.location_id, e.user_id, e.employee_code, e.name, e.phone, e.email,
		       e.address,
		       COALESCE(r.name, e.position) AS position,
		       COALESCE(d.name, e.department) AS department,
		       e.department_id, e.designation_id,
		       e.salary, e.hire_date, e.is_active,
		       e.created_by, e.updated_by, e.last_check_in, e.last_check_out, e.leave_balance,
		       e.sync_status, e.created_at, e.updated_at, e.is_deleted
		FROM employees e
		LEFT JOIN departments d ON d.department_id = e.department_id AND d.is_deleted = FALSE
		LEFT JOIN designations r ON r.designation_id = e.designation_id AND r.is_deleted = FALSE
		WHERE e.company_id = $1 AND e.is_deleted = FALSE`
	args := []interface{}{companyID}
	argPos := 1
	if dept := filters["department"]; dept != "" {
		argPos++
		query += fmt.Sprintf(" AND COALESCE(d.name, e.department) = $%d", argPos)
		args = append(args, dept)
	}
	if status := filters["status"]; status != "" {
		argPos++
		query += fmt.Sprintf(" AND e.is_active = $%d", argPos)
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
			&e.EmployeeID, &e.CompanyID, &e.LocationID, &e.UserID, &e.EmployeeCode, &e.Name,
			&e.Phone, &e.Email, &e.Address, &e.Position, &e.Department,
			&e.DepartmentID, &e.DesignationID, &e.Salary, &e.HireDate, &e.IsActive, &e.CreatedBy, &e.UpdatedBy,
			&e.LastCheckIn, &e.LastCheckOut, &e.LeaveBalance,
			&e.SyncStatus, &e.CreatedAt, &e.UpdatedAt, &e.IsDeleted,
		); err != nil {
			return nil, fmt.Errorf("failed to scan employee: %w", err)
		}
		employees = append(employees, e)
	}
	return employees, nil
}

func (s *EmployeeService) CreateEmployee(companyID, userID int, req *models.CreateEmployeeRequest) (*models.Employee, error) {
	isActive := true
	if req.IsActive != nil {
		isActive = *req.IsActive
	}

	leaveBalance := 0.0
	if req.LeaveBalance != nil {
		leaveBalance = *req.LeaveBalance
	}

	createAppUser := req.AppUser != nil && req.AppUser.Create

	resolveDepartmentAndDesignation := func(q queryer) error {
		if req.DepartmentID != nil {
			var ok bool
			if err := q.QueryRow(`SELECT EXISTS(SELECT 1 FROM departments WHERE department_id = $1 AND company_id = $2 AND is_deleted = FALSE)`, *req.DepartmentID, companyID).Scan(&ok); err != nil {
				return fmt.Errorf("failed to verify department: %w", err)
			}
			if !ok {
				return fmt.Errorf("department not found")
			}
		}
		if req.DesignationID != nil {
			var depID sql.NullInt64
			if err := q.QueryRow(`
				SELECT department_id
				FROM designations
				WHERE designation_id = $1 AND company_id = $2 AND is_deleted = FALSE
			`, *req.DesignationID, companyID).Scan(&depID); err != nil {
				if err == sql.ErrNoRows {
					return fmt.Errorf("designation not found")
				}
				return fmt.Errorf("failed to verify designation: %w", err)
			}
			if req.DepartmentID == nil && depID.Valid {
				v := int(depID.Int64)
				req.DepartmentID = &v
			}
			if req.DepartmentID != nil && depID.Valid && int(depID.Int64) != *req.DepartmentID {
				return fmt.Errorf("designation does not belong to selected department")
			}
		}
		return nil
	}

	insertEmployee := func(q queryer, userIDValue interface{}) (*models.Employee, error) {
		query := `
			INSERT INTO employees (
				company_id, location_id, user_id, employee_code, name, phone, email, address,
				position, department, department_id, designation_id,
				salary, hire_date, is_active, leave_balance, created_by, updated_by
			)
			VALUES (
				$1,$2,$3,
				COALESCE(NULLIF($4, ''), 'EMP-' || LPAD(nextval('employee_code_seq')::text, 6, '0')),
				$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$17
			)
			RETURNING employee_id, created_at, updated_at`

		var emp models.Employee
		if err := q.QueryRow(query,
			companyID, req.LocationID, userIDValue, req.EmployeeCode, req.Name, req.Phone, req.Email, req.Address,
			req.Position, req.Department, req.DepartmentID, req.DesignationID,
			req.Salary, req.HireDate, isActive, leaveBalance, userID,
		).Scan(&emp.EmployeeID, &emp.CreatedAt, &emp.UpdatedAt); err != nil {
			return nil, fmt.Errorf("failed to create employee: %w", err)
		}

		emp.CompanyID = companyID
		emp.LocationID = req.LocationID
		if v, ok := userIDValue.(int); ok {
			emp.UserID = &v
		}
		emp.EmployeeCode = req.EmployeeCode
		emp.Name = req.Name
		emp.Phone = req.Phone
		emp.Email = req.Email
		emp.Address = req.Address
		emp.Position = req.Position
		emp.Department = req.Department
		emp.DepartmentID = req.DepartmentID
		emp.DesignationID = req.DesignationID
		emp.Salary = req.Salary
		emp.HireDate = req.HireDate
		emp.IsActive = isActive
		emp.CreatedBy = userID
		emp.UpdatedBy = &userID
		emp.LeaveBalance = &leaveBalance
		return &emp, nil
	}

	if !createAppUser {
		if err := resolveDepartmentAndDesignation(dbQueryer{s.db}); err != nil {
			return nil, err
		}
		return insertEmployee(dbQueryer{s.db}, nil)
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	var createdUserIDValue interface{}
	if createAppUser {
		username := strings.TrimSpace(req.AppUser.Username)
		email := strings.TrimSpace(req.AppUser.Email)
		if username == "" || email == "" {
			return nil, fmt.Errorf("app_user.username and app_user.email are required")
		}
		var exists bool
		if err := tx.QueryRow(`
			SELECT EXISTS(
				SELECT 1 FROM users
				WHERE is_deleted = FALSE AND (username = $1 OR email = $2)
			)
		`, username, email).Scan(&exists); err != nil {
			return nil, fmt.Errorf("failed to check user existence: %w", err)
		}
		if exists {
			return nil, fmt.Errorf("username or email already exists")
		}

		hashedPassword, err := utils.HashPassword(req.AppUser.TempPassword)
		if err != nil {
			return nil, fmt.Errorf("failed to hash temp password: %w", err)
		}

		locationID := req.AppUser.LocationID
		if locationID == nil {
			locationID = req.LocationID
		}

		firstName := (*string)(nil)
		lastName := (*string)(nil)
		parts := strings.Fields(strings.TrimSpace(req.Name))
		if len(parts) > 0 {
			first := parts[0]
			firstName = &first
		}
		if len(parts) > 1 {
			last := strings.Join(parts[1:], " ")
			lastName = &last
		}

		var uid int
		if err := tx.QueryRow(`
			INSERT INTO users (
				company_id, location_id, role_id, username, email, password_hash,
				first_name, last_name, phone, must_change_password
			)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,TRUE)
			RETURNING user_id
		`, companyID, locationID, req.AppUser.RoleID, username, email, hashedPassword, firstName, lastName, req.Phone).Scan(&uid); err != nil {
			return nil, fmt.Errorf("failed to create app user: %w", err)
		}
		createdUserIDValue = uid
	}
	if err := resolveDepartmentAndDesignation(txQueryer{tx}); err != nil {
		return nil, err
	}

	emp, err := insertEmployee(txQueryer{tx}, createdUserIDValue)
	if err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit employee create: %w", err)
	}
	return emp, nil
}

func (s *EmployeeService) UpdateEmployee(employeeID, companyID, userID int, req *models.UpdateEmployeeRequest) error {
	updates := []string{}
	args := []interface{}{}
	argPos := 1
	if req.LocationID != nil {
		updates = append(updates, fmt.Sprintf("location_id = $%d", argPos))
		args = append(args, *req.LocationID)
		argPos++
	}
	if req.EmployeeCode != nil {
		updates = append(updates, fmt.Sprintf("employee_code = COALESCE(NULLIF($%d, ''), 'EMP-' || LPAD(nextval('employee_code_seq')::text, 6, '0'))", argPos))
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
	if req.DepartmentID != nil {
		var ok bool
		if err := s.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM departments WHERE department_id = $1 AND company_id = $2 AND is_deleted = FALSE)`, *req.DepartmentID, companyID).Scan(&ok); err != nil {
			return fmt.Errorf("failed to verify department: %w", err)
		}
		if !ok {
			return fmt.Errorf("department not found")
		}
		updates = append(updates, fmt.Sprintf("department_id = $%d", argPos))
		args = append(args, *req.DepartmentID)
		argPos++
		// If department is changed without explicitly changing designation, clear designation to avoid mismatch.
		if req.DesignationID == nil {
			updates = append(updates, "designation_id = NULL")
		}
	}
	if req.DesignationID != nil {
		var depID sql.NullInt64
		if err := s.db.QueryRow(`
			SELECT department_id
			FROM designations
			WHERE designation_id = $1 AND company_id = $2 AND is_deleted = FALSE
		`, *req.DesignationID, companyID).Scan(&depID); err != nil {
			if err == sql.ErrNoRows {
				return fmt.Errorf("designation not found")
			}
			return fmt.Errorf("failed to verify designation: %w", err)
		}
		if req.DepartmentID != nil && depID.Valid && int(depID.Int64) != *req.DepartmentID {
			return fmt.Errorf("designation does not belong to selected department")
		}
		updates = append(updates, fmt.Sprintf("designation_id = $%d", argPos))
		args = append(args, *req.DesignationID)
		argPos++
		if depID.Valid && req.DepartmentID == nil {
			updates = append(updates, fmt.Sprintf("department_id = $%d", argPos))
			args = append(args, int(depID.Int64))
			argPos++
		}
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
	updates = append(updates, fmt.Sprintf("updated_by = $%d", argPos))
	args = append(args, userID)
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
