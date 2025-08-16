package services

import (
	"database/sql"
	"fmt"
	"strings"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

// TaxService provides CRUD operations for taxes

type TaxService struct {
	db *sql.DB
}

// NewTaxService creates a new TaxService
func NewTaxService() *TaxService {
	return &TaxService{db: database.GetDB()}
}

// GetTaxes returns all taxes for a company
func (s *TaxService) GetTaxes(companyID int) ([]models.Tax, error) {
	rows, err := s.db.Query(`SELECT tax_id, company_id, name, percentage, is_compound, is_active, created_at, updated_at FROM taxes WHERE company_id = $1 ORDER BY name`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get taxes: %w", err)
	}
	defer rows.Close()

	var taxes []models.Tax
	for rows.Next() {
		var t models.Tax
		if err := rows.Scan(&t.TaxID, &t.CompanyID, &t.Name, &t.Percentage, &t.IsCompound, &t.IsActive, &t.CreatedAt, &t.UpdatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan tax: %w", err)
		}
		taxes = append(taxes, t)
	}
	return taxes, nil
}

// CreateTax creates a new tax
func (s *TaxService) CreateTax(companyID int, req *models.CreateTaxRequest) (*models.Tax, error) {
	var tax models.Tax
	err := s.db.QueryRow(`INSERT INTO taxes (company_id, name, percentage, is_compound, is_active) VALUES ($1,$2,$3,$4,$5) RETURNING tax_id, created_at, updated_at`,
		companyID, req.Name, req.Percentage, req.IsCompound, req.IsActive).Scan(&tax.TaxID, &tax.CreatedAt, &tax.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create tax: %w", err)
	}
	tax.CompanyID = companyID
	tax.Name = req.Name
	tax.Percentage = req.Percentage
	tax.IsCompound = req.IsCompound
	tax.IsActive = req.IsActive
	return &tax, nil
}

// UpdateTax updates an existing tax
func (s *TaxService) UpdateTax(id, companyID int, req *models.UpdateTaxRequest) error {
	setParts := []string{}
	args := []interface{}{}

	if req.Name != nil {
		setParts = append(setParts, fmt.Sprintf("name = $%d", len(args)+1))
		args = append(args, *req.Name)
	}
	if req.Percentage != nil {
		setParts = append(setParts, fmt.Sprintf("percentage = $%d", len(args)+1))
		args = append(args, *req.Percentage)
	}
	if req.IsCompound != nil {
		setParts = append(setParts, fmt.Sprintf("is_compound = $%d", len(args)+1))
		args = append(args, *req.IsCompound)
	}
	if req.IsActive != nil {
		setParts = append(setParts, fmt.Sprintf("is_active = $%d", len(args)+1))
		args = append(args, *req.IsActive)
	}

	if len(setParts) == 0 {
		return fmt.Errorf("no fields to update")
	}

	setParts = append(setParts, "updated_at = CURRENT_TIMESTAMP")
	argPos := len(args) + 1
	query := fmt.Sprintf("UPDATE taxes SET %s WHERE tax_id = $%d AND company_id = $%d", strings.Join(setParts, ", "), argPos, argPos+1)
	args = append(args, id, companyID)

	res, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update tax: %w", err)
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("tax not found")
	}
	return nil
}

// DeleteTax deletes a tax
func (s *TaxService) DeleteTax(id, companyID int) error {
	res, err := s.db.Exec(`DELETE FROM taxes WHERE tax_id = $1 AND company_id = $2`, id, companyID)
	if err != nil {
		return fmt.Errorf("failed to delete tax: %w", err)
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("tax not found")
	}
	return nil
}
