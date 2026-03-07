package services

import (
	"database/sql"
	"fmt"
	"strings"

	"erp-backend/internal/database"
	"erp-backend/internal/models"

	"github.com/lib/pq"
)

// TaxService provides CRUD operations for taxes

type TaxService struct {
	db *sql.DB
}

// NewTaxService creates a new TaxService
func NewTaxService() *TaxService {
	return &TaxService{db: database.GetDB()}
}

func (s *TaxService) getTaxComponentsByTaxIDs(companyID int, taxIDs []int) (map[int][]models.TaxComponent, error) {
	if len(taxIDs) == 0 {
		return map[int][]models.TaxComponent{}, nil
	}

	rows, err := s.db.Query(`
		SELECT tc.component_id, tc.tax_id, tc.name, tc.percentage, tc.sort_order, tc.created_at, tc.updated_at
		FROM tax_components tc
		JOIN taxes t ON t.tax_id = tc.tax_id
		WHERE t.company_id = $1 AND tc.tax_id = ANY($2)
		ORDER BY tc.tax_id, tc.sort_order, tc.component_id
	`, companyID, pq.Array(taxIDs))
	if err != nil {
		return nil, fmt.Errorf("failed to get tax components: %w", err)
	}
	defer rows.Close()

	out := map[int][]models.TaxComponent{}
	for rows.Next() {
		var c models.TaxComponent
		if err := rows.Scan(&c.ComponentID, &c.TaxID, &c.Name, &c.Percentage, &c.SortOrder, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan tax component: %w", err)
		}
		out[c.TaxID] = append(out[c.TaxID], c)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read tax components: %w", err)
	}
	return out, nil
}

// GetTaxes returns all taxes for a company
func (s *TaxService) GetTaxes(companyID int) ([]models.Tax, error) {
	rows, err := s.db.Query(`SELECT tax_id, company_id, name, percentage, is_compound, is_active, created_at, updated_at FROM taxes WHERE company_id = $1 ORDER BY name`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get taxes: %w", err)
	}
	defer rows.Close()

	var taxes []models.Tax
	taxIDs := make([]int, 0, 32)
	for rows.Next() {
		var t models.Tax
		if err := rows.Scan(&t.TaxID, &t.CompanyID, &t.Name, &t.Percentage, &t.IsCompound, &t.IsActive, &t.CreatedAt, &t.UpdatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan tax: %w", err)
		}
		taxes = append(taxes, t)
		taxIDs = append(taxIDs, t.TaxID)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read taxes: %w", err)
	}

	componentsByTaxID, err := s.getTaxComponentsByTaxIDs(companyID, taxIDs)
	if err != nil {
		return nil, err
	}
	for i := range taxes {
		taxes[i].Components = componentsByTaxID[taxes[i].TaxID]
	}
	return taxes, nil
}

func validateTaxComponents(components []models.TaxComponentRequest) (float64, error) {
	total := float64(0)
	for i, c := range components {
		if strings.TrimSpace(c.Name) == "" {
			return 0, fmt.Errorf("component %d name is required", i+1)
		}
		if c.Percentage < 0 || c.Percentage > 100 {
			return 0, fmt.Errorf("component %d percentage must be between 0 and 100", i+1)
		}
		total += c.Percentage
	}
	if total < 0 || total > 100 {
		return 0, fmt.Errorf("total components percentage must be between 0 and 100")
	}
	return total, nil
}

// CreateTax creates a new tax
func (s *TaxService) CreateTax(companyID int, req *models.CreateTaxRequest) (*models.Tax, error) {
	var tax models.Tax

	var computedPct *float64
	if len(req.Components) > 0 {
		sum, err := validateTaxComponents(req.Components)
		if err != nil {
			return nil, err
		}
		computedPct = &sum
		if req.Percentage != nil {
			// If both are provided, enforce they match (avoid ambiguous data).
			if diff := *req.Percentage - sum; diff > 0.01 || diff < -0.01 {
				return nil, fmt.Errorf("percentage must equal sum of components")
			}
		}
	} else {
		if req.Percentage == nil {
			return nil, fmt.Errorf("percentage is required when components are not provided")
		}
		computedPct = req.Percentage
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	err = tx.QueryRow(`
		INSERT INTO taxes (company_id, name, percentage, is_compound, is_active)
		VALUES ($1,$2,$3,$4,$5)
		RETURNING tax_id, created_at, updated_at
	`, companyID, req.Name, *computedPct, req.IsCompound, req.IsActive).Scan(&tax.TaxID, &tax.CreatedAt, &tax.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create tax: %w", err)
	}

	if len(req.Components) > 0 {
		for _, c := range req.Components {
			if _, err := tx.Exec(`
				INSERT INTO tax_components (tax_id, name, percentage, sort_order)
				VALUES ($1,$2,$3,$4)
			`, tax.TaxID, strings.TrimSpace(c.Name), c.Percentage, c.SortOrder); err != nil {
				return nil, fmt.Errorf("failed to create tax components: %w", err)
			}
		}
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	tax.CompanyID = companyID
	tax.Name = req.Name
	tax.Percentage = *computedPct
	tax.IsCompound = req.IsCompound
	tax.IsActive = req.IsActive
	if len(req.Components) > 0 {
		// Best-effort reload with ids; avoids a follow-up query for simple clients.
		tax.Components = []models.TaxComponent{}
		componentsByTaxID, err := s.getTaxComponentsByTaxIDs(companyID, []int{tax.TaxID})
		if err == nil {
			tax.Components = componentsByTaxID[tax.TaxID]
		}
	}
	return &tax, nil
}

// UpdateTax updates an existing tax
func (s *TaxService) UpdateTax(id, companyID int, req *models.UpdateTaxRequest) error {
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	setParts := []string{}
	args := []interface{}{}

	if req.Name != nil {
		setParts = append(setParts, fmt.Sprintf("name = $%d", len(args)+1))
		args = append(args, *req.Name)
	}

	// If components are provided, recompute and persist the total percentage.
	var replaceComponents bool
	var newComponents []models.TaxComponentRequest
	if req.Components != nil {
		replaceComponents = true
		newComponents = *req.Components
		if len(newComponents) > 0 {
			sum, verr := validateTaxComponents(newComponents)
			if verr != nil {
				return verr
			}
			if req.Percentage != nil {
				if diff := *req.Percentage - sum; diff > 0.01 || diff < -0.01 {
					return fmt.Errorf("percentage must equal sum of components")
				}
			}
			req.Percentage = &sum
		}
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

	// Allow "components only" updates (including clearing components) by touching updated_at.
	if len(setParts) == 0 && !replaceComponents {
		return fmt.Errorf("no fields to update")
	}

	setParts = append(setParts, "updated_at = CURRENT_TIMESTAMP")
	argPos := len(args) + 1
	query := fmt.Sprintf("UPDATE taxes SET %s WHERE tax_id = $%d AND company_id = $%d", strings.Join(setParts, ", "), argPos, argPos+1)
	args = append(args, id, companyID)

	res, err := tx.Exec(query, args...)
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

	if replaceComponents {
		if _, err := tx.Exec(`DELETE FROM tax_components WHERE tax_id = $1`, id); err != nil {
			return fmt.Errorf("failed to clear tax components: %w", err)
		}
		for _, c := range newComponents {
			if _, err := tx.Exec(`
				INSERT INTO tax_components (tax_id, name, percentage, sort_order)
				VALUES ($1,$2,$3,$4)
			`, id, strings.TrimSpace(c.Name), c.Percentage, c.SortOrder); err != nil {
				return fmt.Errorf("failed to upsert tax components: %w", err)
			}
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
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
