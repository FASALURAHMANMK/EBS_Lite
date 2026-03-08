package services

import (
	"database/sql"
	"fmt"
	"math"
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
	basicSalary := req.BasicSalary
	if req.AutoCalculate != nil && *req.AutoCalculate {
		calc, err := s.CalculatePayroll(companyID, req.EmployeeID, req.Month, &basicSalary)
		if err != nil {
			return nil, err
		}
		basicSalary = calc.ProratedBasicSalary
	}

	gross := basicSalary + req.Allowances
	net := gross - req.Deductions
	query := `
                INSERT INTO payroll (employee_id, pay_period_start, pay_period_end, basic_salary,
                                     gross_salary, total_deductions, net_salary, status, processed_by)
                VALUES ($1,$2,$3,$4,$5,$6,$7,'FINALIZED',$8)
                RETURNING payroll_id, created_at`
	var p models.Payroll
	err = s.db.QueryRow(query,
		req.EmployeeID, start, end, basicSalary, gross, req.Deductions, net, userID,
	).Scan(&p.PayrollID, &p.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create payroll: %w", err)
	}
	p.EmployeeID = req.EmployeeID
	p.PayPeriodStart = start
	p.PayPeriodEnd = end
	p.BasicSalary = basicSalary
	p.GrossSalary = gross
	p.TotalDeductions = req.Deductions
	p.NetSalary = net
	p.Status = "FINALIZED"
	p.ProcessedBy = &userID
	return &p, nil
}

func (s *PayrollService) MarkPayrollPaid(payrollID, companyID, userID int) error {
	var basic float64
	var payPeriodEnd time.Time
	err := s.db.QueryRow(`
		SELECT p.basic_salary, p.pay_period_end
		FROM payroll p
		JOIN employees e ON p.employee_id = e.employee_id
		WHERE p.payroll_id = $1 AND e.company_id = $2
	`, payrollID, companyID).Scan(&basic, &payPeriodEnd)
	if err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("payroll not found")
		}
		return fmt.Errorf("failed to load payroll: %w", err)
	}

	var compTotal float64
	if err := s.db.QueryRow(`SELECT COALESCE(SUM(amount),0) FROM salary_components WHERE payroll_id = $1 AND is_deleted = FALSE`, payrollID).Scan(&compTotal); err != nil {
		return fmt.Errorf("failed to sum salary components: %w", err)
	}
	var advTotal float64
	if err := s.db.QueryRow(`SELECT COALESCE(SUM(amount),0) FROM payroll_advances WHERE payroll_id = $1 AND is_deleted = FALSE`, payrollID).Scan(&advTotal); err != nil {
		return fmt.Errorf("failed to sum advances: %w", err)
	}
	var dedTotal float64
	if err := s.db.QueryRow(`SELECT COALESCE(SUM(amount),0) FROM payroll_deductions WHERE payroll_id = $1 AND is_deleted = FALSE`, payrollID).Scan(&dedTotal); err != nil {
		return fmt.Errorf("failed to sum deductions: %w", err)
	}

	gross := basic + compTotal
	totalDeductions := advTotal + dedTotal
	net := gross - totalDeductions
	if net < 0 {
		net = 0
	}

	result, err := s.db.Exec(`
		UPDATE payroll p
		SET status = 'PAID',
		    gross_salary = $1,
		    total_deductions = $2,
		    net_salary = $3,
		    updated_at = CURRENT_TIMESTAMP
		FROM employees e
		WHERE p.payroll_id = $4 AND p.employee_id = e.employee_id AND e.company_id = $5
	`, gross, totalDeductions, net, payrollID, companyID)
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

	ledger := NewLedgerService()
	if err := ledger.RecordPayrollPayment(companyID, payrollID, userID, payPeriodEnd); err != nil {
		return err
	}

	return nil
}

func (s *PayrollService) CalculatePayroll(companyID, employeeID int, month string, baseMonthlySalary *float64) (*models.PayrollCalculation, error) {
	start, err := time.Parse("2006-01", month)
	if err != nil {
		return nil, fmt.Errorf("invalid month format")
	}
	end := start.AddDate(0, 1, -1)

	var salary sql.NullFloat64
	if err := s.db.QueryRow(`
		SELECT salary
		FROM employees
		WHERE employee_id = $1 AND company_id = $2 AND is_deleted = FALSE
	`, employeeID, companyID).Scan(&salary); err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("employee not found")
		}
		return nil, fmt.Errorf("failed to load employee salary: %w", err)
	}

	base := 0.0
	if baseMonthlySalary != nil && *baseMonthlySalary > 0 {
		base = *baseMonthlySalary
	} else if salary.Valid && salary.Float64 > 0 {
		base = salary.Float64
	}
	if base <= 0 {
		return nil, fmt.Errorf("base monthly salary is required (employee salary missing)")
	}

	type holidayRow struct {
		Date        time.Time
		IsRecurring bool
	}
	rows, err := s.db.Query(`
		SELECT date, is_recurring
		FROM holidays
		WHERE company_id = $1
		  AND is_deleted = FALSE
		  AND (
			(is_recurring = FALSE AND date BETWEEN $2 AND $3)
			OR (is_recurring = TRUE AND EXTRACT(MONTH FROM date) = $4)
		  )
	`, companyID, start, end, int(start.Month()))
	if err != nil {
		return nil, fmt.Errorf("failed to list holidays: %w", err)
	}
	defer rows.Close()

	holidaySet := map[string]struct{}{}
	for rows.Next() {
		var h holidayRow
		if err := rows.Scan(&h.Date, &h.IsRecurring); err != nil {
			return nil, fmt.Errorf("failed to scan holiday: %w", err)
		}
		date := h.Date
		if h.IsRecurring {
			date = time.Date(start.Year(), date.Month(), date.Day(), 0, 0, 0, 0, time.UTC)
		}
		holidaySet[date.Format("2006-01-02")] = struct{}{}
	}

	workingCredits := map[string]float64{}
	workingDays := 0
	for d := start; !d.After(end); d = d.AddDate(0, 0, 1) {
		if d.Weekday() == time.Saturday || d.Weekday() == time.Sunday {
			continue
		}
		key := d.Format("2006-01-02")
		if _, ok := holidaySet[key]; ok {
			continue
		}
		workingDays++
		workingCredits[key] = 0
	}

	presentDays := 0.0
	attRows, err := s.db.Query(`
		SELECT date, status
		FROM attendance
		WHERE employee_id = $1 AND is_deleted = FALSE AND date BETWEEN $2 AND $3
	`, employeeID, start, end)
	if err != nil {
		return nil, fmt.Errorf("failed to load attendance: %w", err)
	}
	defer attRows.Close()
	for attRows.Next() {
		var day time.Time
		var status string
		if err := attRows.Scan(&day, &status); err != nil {
			return nil, fmt.Errorf("failed to scan attendance: %w", err)
		}
		key := day.Format("2006-01-02")
		if _, ok := workingCredits[key]; !ok {
			continue
		}
		credit := 0.0
		switch status {
		case "PRESENT", "LATE":
			credit = 1
		case "HALF_DAY":
			credit = 0.5
		default:
			credit = 0
		}
		if credit > workingCredits[key] {
			workingCredits[key] = credit
		}
		presentDays += credit
	}

	approvedLeaveDays := 0.0
	leaveRows, err := s.db.Query(`
		SELECT start_date, end_date
		FROM leaves
		WHERE employee_id = $1
		  AND status = 'APPROVED'
		  AND is_deleted = FALSE
		  AND start_date <= $3
		  AND end_date >= $2
	`, employeeID, start, end)
	if err != nil {
		return nil, fmt.Errorf("failed to load approved leaves: %w", err)
	}
	defer leaveRows.Close()
	for leaveRows.Next() {
		var ls, le time.Time
		if err := leaveRows.Scan(&ls, &le); err != nil {
			return nil, fmt.Errorf("failed to scan leave: %w", err)
		}
		if ls.Before(start) {
			ls = start
		}
		if le.After(end) {
			le = end
		}
		for d := ls; !d.After(le); d = d.AddDate(0, 0, 1) {
			key := d.Format("2006-01-02")
			cur, ok := workingCredits[key]
			if !ok {
				continue
			}
			if cur < 1 {
				approvedLeaveDays += 1 - cur
				workingCredits[key] = 1
			}
		}
	}

	payableDays := 0.0
	for _, c := range workingCredits {
		payableDays += c
	}
	unpaidAbsenceDays := float64(workingDays) - payableDays
	if unpaidAbsenceDays < 0 {
		unpaidAbsenceDays = 0
	}

	prorated := base
	if workingDays > 0 {
		perDay := base / float64(workingDays)
		prorated = perDay * payableDays
	}
	prorated = math.Round(prorated*100) / 100

	return &models.PayrollCalculation{
		EmployeeID:          employeeID,
		Month:               month,
		PayPeriodStart:      start,
		PayPeriodEnd:        end,
		BaseMonthlySalary:   base,
		WorkingDays:         workingDays,
		PayableDays:         payableDays,
		PresentDays:         presentDays,
		ApprovedLeaveDays:   approvedLeaveDays,
		UnpaidAbsenceDays:   unpaidAbsenceDays,
		ProratedBasicSalary: prorated,
	}, nil
}

func (s *PayrollService) AddSalaryComponent(payrollID, companyID int, req *models.AddComponentRequest) (*models.SalaryComponent, error) {
	var exists bool
	err := s.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM payroll p JOIN employees e ON p.employee_id = e.employee_id WHERE p.payroll_id = $1 AND e.company_id = $2)`, payrollID, companyID).Scan(&exists)
	if err != nil {
		return nil, fmt.Errorf("failed to verify payroll: %w", err)
	}
	if !exists {
		return nil, fmt.Errorf("payroll not found")
	}
	var comp models.SalaryComponent
	err = s.db.QueryRow(`INSERT INTO salary_components (payroll_id, type, amount) VALUES ($1,$2,$3) RETURNING component_id, created_at`, payrollID, req.Type, req.Amount).Scan(&comp.ComponentID, &comp.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to add component: %w", err)
	}
	comp.PayrollID = payrollID
	comp.Type = req.Type
	comp.Amount = req.Amount
	comp.SyncStatus = "SYNCED"
	return &comp, nil
}

func (s *PayrollService) AddAdvance(payrollID, companyID int, req *models.AdvanceRequest) (*models.Advance, error) {
	var exists bool
	err := s.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM payroll p JOIN employees e ON p.employee_id = e.employee_id WHERE p.payroll_id = $1 AND e.company_id = $2)`, payrollID, companyID).Scan(&exists)
	if err != nil {
		return nil, fmt.Errorf("failed to verify payroll: %w", err)
	}
	if !exists {
		return nil, fmt.Errorf("payroll not found")
	}
	date, err := time.Parse("2006-01-02", req.Date)
	if err != nil {
		return nil, fmt.Errorf("invalid date")
	}
	var adv models.Advance
	err = s.db.QueryRow(`INSERT INTO payroll_advances (payroll_id, amount, date) VALUES ($1,$2,$3) RETURNING advance_id, created_at`, payrollID, req.Amount, date).Scan(&adv.AdvanceID, &adv.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to add advance: %w", err)
	}
	adv.PayrollID = payrollID
	adv.Amount = req.Amount
	adv.Date = date
	adv.SyncStatus = "SYNCED"
	return &adv, nil
}

func (s *PayrollService) AddDeduction(payrollID, companyID int, req *models.DeductionRequest) (*models.Deduction, error) {
	var exists bool
	err := s.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM payroll p JOIN employees e ON p.employee_id = e.employee_id WHERE p.payroll_id = $1 AND e.company_id = $2)`, payrollID, companyID).Scan(&exists)
	if err != nil {
		return nil, fmt.Errorf("failed to verify payroll: %w", err)
	}
	if !exists {
		return nil, fmt.Errorf("payroll not found")
	}
	date, err := time.Parse("2006-01-02", req.Date)
	if err != nil {
		return nil, fmt.Errorf("invalid date")
	}
	var ded models.Deduction
	err = s.db.QueryRow(`INSERT INTO payroll_deductions (payroll_id, type, amount, date) VALUES ($1,$2,$3,$4) RETURNING deduction_id, created_at`, payrollID, req.Type, req.Amount, date).Scan(&ded.DeductionID, &ded.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to add deduction: %w", err)
	}
	ded.PayrollID = payrollID
	ded.Type = req.Type
	ded.Amount = req.Amount
	ded.Date = date
	ded.SyncStatus = "SYNCED"
	return &ded, nil
}

func (s *PayrollService) GeneratePayslip(payrollID, companyID int) (*models.Payslip, error) {
	var exists bool
	err := s.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM payroll p JOIN employees e ON p.employee_id = e.employee_id WHERE p.payroll_id = $1 AND e.company_id = $2)`, payrollID, companyID).Scan(&exists)
	if err != nil {
		return nil, fmt.Errorf("failed to verify payroll: %w", err)
	}
	if !exists {
		return nil, fmt.Errorf("payroll not found")
	}
	var p models.Payroll
	err = s.db.QueryRow(`SELECT payroll_id, employee_id, pay_period_start, pay_period_end, basic_salary, gross_salary, total_deductions, net_salary, status, processed_by FROM payroll WHERE payroll_id = $1`, payrollID).Scan(&p.PayrollID, &p.EmployeeID, &p.PayPeriodStart, &p.PayPeriodEnd, &p.BasicSalary, &p.GrossSalary, &p.TotalDeductions, &p.NetSalary, &p.Status, &p.ProcessedBy)
	if err != nil {
		return nil, fmt.Errorf("failed to get payroll: %w", err)
	}
	compRows, err := s.db.Query(`SELECT component_id, payroll_id, type, amount, sync_status, created_at, updated_at, is_deleted FROM salary_components WHERE payroll_id = $1 AND is_deleted = FALSE`, payrollID)
	if err != nil {
		return nil, fmt.Errorf("failed to get components: %w", err)
	}
	defer compRows.Close()
	var components []models.SalaryComponent
	var compTotal float64
	for compRows.Next() {
		var c models.SalaryComponent
		if err := compRows.Scan(&c.ComponentID, &c.PayrollID, &c.Type, &c.Amount, &c.SyncStatus, &c.CreatedAt, &c.UpdatedAt, &c.IsDeleted); err != nil {
			return nil, fmt.Errorf("failed to scan component: %w", err)
		}
		compTotal += c.Amount
		components = append(components, c)
	}
	advRows, err := s.db.Query(`SELECT advance_id, payroll_id, amount, date, sync_status, created_at, updated_at, is_deleted FROM payroll_advances WHERE payroll_id = $1 AND is_deleted = FALSE`, payrollID)
	if err != nil {
		return nil, fmt.Errorf("failed to get advances: %w", err)
	}
	defer advRows.Close()
	var advances []models.Advance
	var advTotal float64
	for advRows.Next() {
		var a models.Advance
		if err := advRows.Scan(&a.AdvanceID, &a.PayrollID, &a.Amount, &a.Date, &a.SyncStatus, &a.CreatedAt, &a.UpdatedAt, &a.IsDeleted); err != nil {
			return nil, fmt.Errorf("failed to scan advance: %w", err)
		}
		advTotal += a.Amount
		advances = append(advances, a)
	}
	dedRows, err := s.db.Query(`SELECT deduction_id, payroll_id, type, amount, date, sync_status, created_at, updated_at, is_deleted FROM payroll_deductions WHERE payroll_id = $1 AND is_deleted = FALSE`, payrollID)
	if err != nil {
		return nil, fmt.Errorf("failed to get deductions: %w", err)
	}
	defer dedRows.Close()
	var deductions []models.Deduction
	var dedTotal float64
	for dedRows.Next() {
		var d models.Deduction
		if err := dedRows.Scan(&d.DeductionID, &d.PayrollID, &d.Type, &d.Amount, &d.Date, &d.SyncStatus, &d.CreatedAt, &d.UpdatedAt, &d.IsDeleted); err != nil {
			return nil, fmt.Errorf("failed to scan deduction: %w", err)
		}
		dedTotal += d.Amount
		deductions = append(deductions, d)
	}
	netPay := p.BasicSalary + compTotal - dedTotal - advTotal
	payslip := &models.Payslip{
		Payroll:    p,
		Components: components,
		Advances:   advances,
		Deductions: deductions,
		NetPay:     netPay,
	}
	return payslip, nil
}
