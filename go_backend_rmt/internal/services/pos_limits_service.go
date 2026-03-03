package services

import (
	"database/sql"
	"fmt"

	"erp-backend/internal/database"
)

type POSLimits struct {
	MaxLineDiscountPct float64
	MaxBillDiscountPct float64
}

type POSLimitsService struct {
	db *sql.DB
}

func NewPOSLimitsService() *POSLimitsService {
	return &POSLimitsService{db: database.GetDB()}
}

func (s *POSLimitsService) GetLimitsForRole(roleID int) (*POSLimits, error) {
	if roleID == 0 {
		return nil, fmt.Errorf("invalid role id")
	}
	var maxLine, maxBill float64
	err := s.db.QueryRow(`
		SELECT COALESCE(max_line_discount_pct, 0), COALESCE(max_bill_discount_pct, 0)
		FROM role_pos_limits
		WHERE role_id = $1
	`, roleID).Scan(&maxLine, &maxBill)
	if err == sql.ErrNoRows {
		// Default to no extra restriction when not configured.
		return &POSLimits{MaxLineDiscountPct: 100, MaxBillDiscountPct: 100}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get pos limits: %w", err)
	}
	return &POSLimits{MaxLineDiscountPct: maxLine, MaxBillDiscountPct: maxBill}, nil
}
