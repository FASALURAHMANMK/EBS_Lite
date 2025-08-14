package services

import (
	"database/sql"
	"fmt"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type PayrollService struct {
	db *sql.DB
}

func NewPayrollService() *PayrollService {
	return &PayrollService{db: database.GetDB()}
}

func (s *PayrollService) GetPayrolls(companyID int, filters map[string]string) ([]models.Payroll, error) {
	query := `
                SELECT p.payroll_id, p.employee_id, p.pay_period_start, p.pay_period_end,
                       p.basic_salary, p.gross_salary, p.total_deductions, p.net_salary,
                       p.status, p.processed_by, p.sync_status, p.created_at, p.updated_at
                FROM payroll p
                JOIN employees e ON p.employee_id = e.employee_id
                WHERE e.company_id = $1`
	args := []interface{}{companyID}
	argPos := 1
	if empID := filters["employee_id"]; empID != "" {
		argPos++
		query += fmt.Sprintf(" AND p.employee_id = $%d", argPos)
		args = append(args, empID)
	}
	if month := filters["month"]; month != "" {
		start, err := time.Parse("2006-01", month)
		if err == nil {
			argPos++
			query += fmt.Sprintf(" AND p.pay_period_start = $%d", argPos)
			args = append(args, start)
		}
	}
	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get payrolls: %w", err)
	}
	defer rows.Close()

	var payrolls []models.Payroll
	for rows.Next() {
		var p models.Payroll
		if err := rows.Scan(
			&p.PayrollID, &p.EmployeeID, &p.PayPeriodStart, &p.PayPeriodEnd,
			&p.BasicSalary, &p.GrossSalary, &p.TotalDeductions, &p.NetSalary,
			&p.Status, &p.ProcessedBy, &p.SyncStatus, &p.CreatedAt, &p.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan payroll: %w", err)
		}
		payrolls = append(payrolls, p)
	}
	return payrolls, nil
}

func (s *PayrollService) CreatePayroll(companyID int, req *models.CreatePayrollRequest, userID int) (*models.Payroll, error) {
	var exists bool
	err := s.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM employees WHERE employee_id = $1 AND company_id = $2 AND is_deleted = FALSE)`, req.EmployeeID, companyID).Scan(&exists)
	if err != nil {
		return nil, fmt.Errorf("failed to verify employee: %w", err)
	}
	if !exists {
		return nil, fmt.Errorf("employee not found")
	}
	start, err := time.Parse("2006-01", req.Month)
	if err != nil {
		return nil, fmt.Errorf("invalid month format")
	}
	end := start.AddDate(0, 1, -1)
	gross := req.BasicSalary + req.Allowances
	net := gross - req.Deductions
	query := `
                INSERT INTO payroll (employee_id, pay_period_start, pay_period_end, basic_salary,
                                     gross_salary, total_deductions, net_salary, status, processed_by)
                VALUES ($1,$2,$3,$4,$5,$6,$7,'FINALIZED',$8)
                RETURNING payroll_id, created_at`
	var p models.Payroll
	err = s.db.QueryRow(query,
		req.EmployeeID, start, end, req.BasicSalary, gross, req.Deductions, net, userID,
	).Scan(&p.PayrollID, &p.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create payroll: %w", err)
	}
	p.EmployeeID = req.EmployeeID
	p.PayPeriodStart = start
	p.PayPeriodEnd = end
	p.BasicSalary = req.BasicSalary
	p.GrossSalary = gross
	p.TotalDeductions = req.Deductions
	p.NetSalary = net
	p.Status = "FINALIZED"
	p.ProcessedBy = &userID
	return &p, nil
}

func (s *PayrollService) MarkPayrollPaid(payrollID, companyID int) error {
	result, err := s.db.Exec(`
                UPDATE payroll p
                SET status = 'PAID', updated_at = CURRENT_TIMESTAMP
                FROM employees e
                WHERE p.payroll_id = $1 AND p.employee_id = e.employee_id AND e.company_id = $2`,
		payrollID, companyID,
	)
	if err != nil {
		return fmt.Errorf("failed to mark payroll paid: %w", err)
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("payroll not found")
	}
	return nil
}
