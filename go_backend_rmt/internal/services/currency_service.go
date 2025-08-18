package services

import (
	"database/sql"
	"fmt"
	"strings"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

// CurrencyService provides CRUD operations for currencies
type CurrencyService struct {
	db *sql.DB
}

// NewCurrencyService creates a new CurrencyService
func NewCurrencyService() *CurrencyService {
	return &CurrencyService{db: database.GetDB()}
}

// GetCurrencies returns all non-deleted currencies
func (s *CurrencyService) GetCurrencies() ([]models.Currency, error) {
	query := `SELECT currency_id, code, name, symbol, exchange_rate, is_base_currency, created_at, updated_at
              FROM currencies WHERE is_deleted = FALSE ORDER BY code`
	rows, err := s.db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("failed to get currencies: %w", err)
	}
	defer rows.Close()

	var currencies []models.Currency
	for rows.Next() {
		var cur models.Currency
		if err := rows.Scan(&cur.CurrencyID, &cur.Code, &cur.Name, &cur.Symbol,
			&cur.ExchangeRate, &cur.IsBaseCurrency, &cur.CreatedAt, &cur.UpdatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan currency: %w", err)
		}
		currencies = append(currencies, cur)
	}
	return currencies, nil
}

// CreateCurrency creates a new currency
func (s *CurrencyService) CreateCurrency(req *models.CreateCurrencyRequest) (*models.Currency, error) {
	var exists bool
	if err := s.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM currencies WHERE code = $1 AND is_deleted = FALSE)`, req.Code).Scan(&exists); err != nil {
		return nil, fmt.Errorf("failed to check currency code: %w", err)
	}
	if exists {
		return nil, fmt.Errorf("currency code already exists")
	}

	query := `INSERT INTO currencies (code, name, symbol, exchange_rate, is_base_currency)
              VALUES ($1, $2, $3, $4, $5) RETURNING currency_id, created_at, updated_at`
	var cur models.Currency
	if err := s.db.QueryRow(query, req.Code, req.Name, req.Symbol, req.ExchangeRate, req.IsBaseCurrency).
		Scan(&cur.CurrencyID, &cur.CreatedAt, &cur.UpdatedAt); err != nil {
		return nil, fmt.Errorf("failed to create currency: %w", err)
	}
	cur.Code = req.Code
	cur.Name = req.Name
	cur.Symbol = req.Symbol
	cur.ExchangeRate = req.ExchangeRate
	cur.IsBaseCurrency = req.IsBaseCurrency
	return &cur, nil
}

// UpdateCurrency updates an existing currency
func (s *CurrencyService) UpdateCurrency(id int, req *models.UpdateCurrencyRequest) error {
	setParts := []string{}
	args := []interface{}{}
	argCount := 0

	if req.Code != nil {
		var exists bool
		if err := s.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM currencies WHERE code = $1 AND currency_id <> $2 AND is_deleted = FALSE)`, *req.Code, id).Scan(&exists); err != nil {
			return fmt.Errorf("failed to check currency code: %w", err)
		}
		if exists {
			return fmt.Errorf("currency code already exists")
		}
		argCount++
		setParts = append(setParts, fmt.Sprintf("code = $%d", argCount))
		args = append(args, *req.Code)
	}
	if req.Name != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("name = $%d", argCount))
		args = append(args, *req.Name)
	}
	if req.Symbol != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("symbol = $%d", argCount))
		args = append(args, *req.Symbol)
	}
	if req.ExchangeRate != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("exchange_rate = $%d", argCount))
		args = append(args, *req.ExchangeRate)
	}
	if req.IsBaseCurrency != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("is_base_currency = $%d", argCount))
		args = append(args, *req.IsBaseCurrency)
	}
	if len(setParts) == 0 {
		return fmt.Errorf("no fields to update")
	}

	// always update timestamp
	setParts = append(setParts, "updated_at = CURRENT_TIMESTAMP")

	argCount++
	query := fmt.Sprintf("UPDATE currencies SET %s WHERE currency_id = $%d AND is_deleted = FALSE", strings.Join(setParts, ", "), argCount)
	args = append(args, id)

	res, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update currency: %w", err)
	}
	rowsAffected, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rowsAffected == 0 {
		return fmt.Errorf("currency not found")
	}
	return nil
}

// DeleteCurrency marks a currency as deleted
func (s *CurrencyService) DeleteCurrency(id int) error {
	res, err := s.db.Exec(`UPDATE currencies SET is_deleted = TRUE, updated_at = CURRENT_TIMESTAMP WHERE currency_id = $1 AND is_deleted = FALSE`, id)
	if err != nil {
		return fmt.Errorf("failed to delete currency: %w", err)
	}
	rowsAffected, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rowsAffected == 0 {
		return fmt.Errorf("currency not found")
	}
	return nil
}
