package services

import (
	"database/sql"
	"fmt"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type VoucherService struct {
	db *sql.DB
}

func NewVoucherService() *VoucherService {
	return &VoucherService{db: database.GetDB()}
}

func (s *VoucherService) CreateVoucher(companyID, userID int, vType string, req *models.CreateVoucherRequest) (int, error) {
	var id int
	err := s.db.QueryRow(`INSERT INTO vouchers (company_id, type, account_id, amount, reference, description, created_by, updated_by)
                VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING voucher_id`,
		companyID, vType, req.AccountID, req.Amount, req.Reference, req.Description, userID, userID).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("failed to create voucher: %w", err)
	}
	ledger := NewLedgerService()
	switch vType {
	case "payment":
		_ = ledger.RecordExpense(companyID, id, req.Amount, userID)
	case "receipt":
		_ = ledger.RecordSale(companyID, id, req.Amount, userID)
	case "journal":
		// Placeholder for journal entries
	}
	return id, nil
}

// ListVouchers retrieves vouchers for a company with optional type and date filters.
// Supports pagination via page and pageSize parameters.
func (s *VoucherService) ListVouchers(companyID int, filters map[string]string, page, pageSize int) ([]models.Voucher, int, error) {
	baseQuery := `SELECT voucher_id, company_id, type, date, amount, account_id, reference, description, sync_status, created_at, updated_at
                FROM vouchers WHERE company_id = $1 AND is_deleted = FALSE`
	countQuery := `SELECT COUNT(*) FROM vouchers WHERE company_id = $1 AND is_deleted = FALSE`

	args := []interface{}{companyID}
	countArgs := []interface{}{companyID}
	argPos := 1

	if v, ok := filters["type"]; ok && v != "" {
		argPos++
		baseQuery += fmt.Sprintf(" AND type = $%d", argPos)
		countQuery += fmt.Sprintf(" AND type = $%d", argPos)
		args = append(args, v)
		countArgs = append(countArgs, v)
	}
	if v, ok := filters["date_from"]; ok && v != "" {
		argPos++
		baseQuery += fmt.Sprintf(" AND date >= $%d", argPos)
		countQuery += fmt.Sprintf(" AND date >= $%d", argPos)
		args = append(args, v)
		countArgs = append(countArgs, v)
	}
	if v, ok := filters["date_to"]; ok && v != "" {
		argPos++
		baseQuery += fmt.Sprintf(" AND date <= $%d", argPos)
		countQuery += fmt.Sprintf(" AND date <= $%d", argPos)
		args = append(args, v)
		countArgs = append(countArgs, v)
	}

	// Get total count
	var total int
	if err := s.db.QueryRow(countQuery, countArgs...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("failed to count vouchers: %w", err)
	}

	// Pagination
	if pageSize <= 0 {
		pageSize = 20
	}
	if page <= 0 {
		page = 1
	}
	offset := (page - 1) * pageSize
	baseQuery += fmt.Sprintf(" ORDER BY date DESC, voucher_id DESC LIMIT $%d OFFSET $%d", argPos+1, argPos+2)
	args = append(args, pageSize, offset)

	rows, err := s.db.Query(baseQuery, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to list vouchers: %w", err)
	}
	defer rows.Close()

	var vouchers []models.Voucher
	for rows.Next() {
		var v models.Voucher
		if err := rows.Scan(&v.VoucherID, &v.CompanyID, &v.Type, &v.Date, &v.Amount, &v.AccountID, &v.Reference, &v.Description, &v.SyncStatus, &v.CreatedAt, &v.UpdatedAt); err != nil {
			return nil, 0, fmt.Errorf("failed to scan voucher: %w", err)
		}
		vouchers = append(vouchers, v)
	}

	return vouchers, total, nil
}

// GetVoucher retrieves a single voucher by ID for a company.
func (s *VoucherService) GetVoucher(companyID, voucherID int) (*models.Voucher, error) {
	query := `SELECT voucher_id, company_id, type, date, amount, account_id, reference, description, sync_status, created_at, updated_at
                FROM vouchers WHERE voucher_id = $1 AND company_id = $2 AND is_deleted = FALSE`

	var v models.Voucher
	err := s.db.QueryRow(query, voucherID, companyID).Scan(&v.VoucherID, &v.CompanyID, &v.Type, &v.Date, &v.Amount, &v.AccountID, &v.Reference, &v.Description, &v.SyncStatus, &v.CreatedAt, &v.UpdatedAt)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("voucher not found")
		}
		return nil, fmt.Errorf("failed to get voucher: %w", err)
	}

	return &v, nil
}
