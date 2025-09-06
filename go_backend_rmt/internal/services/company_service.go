package services

import (
	"database/sql"
	"fmt"
	"strings"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type CompanyService struct {
	db *sql.DB
}

func NewCompanyService() *CompanyService {
	return &CompanyService{
		db: database.GetDB(),
	}
}

func (s *CompanyService) GetCompanies() ([]models.Company, error) {
	query := `
		SELECT company_id, name, logo, address, phone, email, tax_number, 
			   currency_id, is_active, created_at, updated_at
		FROM companies 
		WHERE is_active = TRUE
		ORDER BY name
	`

	rows, err := s.db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("failed to get companies: %w", err)
	}
	defer rows.Close()

	var companies []models.Company
	for rows.Next() {
		var company models.Company
		err := rows.Scan(
			&company.CompanyID, &company.Name, &company.Logo, &company.Address,
			&company.Phone, &company.Email, &company.TaxNumber, &company.CurrencyID,
			&company.IsActive, &company.CreatedAt, &company.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan company: %w", err)
		}
		companies = append(companies, company)
	}

	return companies, nil
}

// GetCompanyByID retrieves a single company by its identifier. It returns an
// error if the company does not exist or is inactive.
func (s *CompanyService) GetCompanyByID(companyID int) (*models.Company, error) {
	query := `
               SELECT company_id, name, logo, address, phone, email, tax_number,
                      currency_id, is_active, created_at, updated_at
               FROM companies
               WHERE company_id = $1 AND is_active = TRUE
       `

	var company models.Company
	err := s.db.QueryRow(query, companyID).Scan(
		&company.CompanyID, &company.Name, &company.Logo, &company.Address,
		&company.Phone, &company.Email, &company.TaxNumber, &company.CurrencyID,
		&company.IsActive, &company.CreatedAt, &company.UpdatedAt,
	)

	if err != nil {
		return nil, err
	}

	return &company, nil
}

// func (s *CompanyService) CreateCompany(req *models.CreateCompanyRequest) (*models.Company, error) {
// 	query := `
// 		INSERT INTO companies (name, logo, address, phone, email, tax_number, currency_id)
// 		VALUES ($1, $2, $3, $4, $5, $6, $7)
// 		RETURNING company_id, created_at
// 	`

// 	var company models.Company
// 	err := s.db.QueryRow(query,
// 		req.Name, req.Logo, req.Address, req.Phone, req.Email, req.TaxNumber, req.CurrencyID,
// 	).Scan(&company.CompanyID, &company.CreatedAt)

// 	if err != nil {
// 		return nil, fmt.Errorf("failed to create company: %w", err)
// 	}

// 	company.Name = req.Name
// 	company.Logo = req.Logo
// 	company.Address = req.Address
// 	company.Phone = req.Phone
// 	company.Email = req.Email
// 	company.TaxNumber = req.TaxNumber
// 	company.CurrencyID = req.CurrencyID
// 	company.IsActive = true

// 	return &company, nil
// }

func (s *CompanyService) CreateCompany(req *models.CreateCompanyRequest, userID int) (*models.Company, error) {
	// Start transaction
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

    // Create company
	query := `
		INSERT INTO companies (name, logo, address, phone, email, tax_number, currency_id)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING company_id, created_at
	`

	var company models.Company
	err = tx.QueryRow(query,
		req.Name, req.Logo, req.Address, req.Phone, req.Email, req.TaxNumber, req.CurrencyID,
	).Scan(&company.CompanyID, &company.CreatedAt)

    if err != nil {
        return nil, fmt.Errorf("failed to create company: %w", err)
    }

    // Seed default tax: 'None' (0%) and 'GST 18%' example only if desired in future
    if _, err = tx.Exec(`
        INSERT INTO taxes (company_id, name, percentage, is_compound, is_active)
        VALUES ($1, 'None', 0, FALSE, TRUE)
        ON CONFLICT DO NOTHING
    `, company.CompanyID); err != nil {
        return nil, fmt.Errorf("failed to seed default tax: %w", err)
    }

    // Create default location
	_, err = tx.Exec(`
		INSERT INTO locations (company_id, name, address, is_active)
		VALUES ($1, 'Main Office', $2, TRUE)
	`, company.CompanyID, req.Address)

	if err != nil {
		return nil, fmt.Errorf("failed to create default location: %w", err)
	}

	// If user doesn't have a company, assign this company and make them admin
	var userCompanyID *int
	err = tx.QueryRow("SELECT company_id FROM users WHERE user_id = $1", userID).Scan(&userCompanyID)
	if err != nil {
		return nil, fmt.Errorf("failed to check user: %w", err)
	}

	if userCompanyID == nil {
		// User doesn't have company - assign this one and make them admin
		_, err = tx.Exec(`
			UPDATE users 
			SET company_id = $1, role_id = 1, updated_at = CURRENT_TIMESTAMP
			WHERE user_id = $2
		`, company.CompanyID, userID)

		if err != nil {
			return nil, fmt.Errorf("failed to assign company to user: %w", err)
		}
	}

	// Commit transaction
	if err = tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	company.Name = req.Name
	company.Logo = req.Logo
	company.Address = req.Address
	company.Phone = req.Phone
	company.Email = req.Email
	company.TaxNumber = req.TaxNumber
	company.CurrencyID = req.CurrencyID
	company.IsActive = true

	return &company, nil
}

func (s *CompanyService) UpdateCompany(companyID int, req *models.UpdateCompanyRequest) error {
	setParts := []string{}
	args := []interface{}{}
	argCount := 0

	if req.Name != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("name = $%d", argCount))
		args = append(args, *req.Name)
	}
	if req.Logo != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("logo = $%d", argCount))
		args = append(args, *req.Logo)
	}
	if req.Address != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("address = $%d", argCount))
		args = append(args, *req.Address)
	}
	if req.Phone != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("phone = $%d", argCount))
		args = append(args, *req.Phone)
	}
	if req.Email != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("email = $%d", argCount))
		args = append(args, *req.Email)
	}
	if req.TaxNumber != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("tax_number = $%d", argCount))
		args = append(args, *req.TaxNumber)
	}
	if req.CurrencyID != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("currency_id = $%d", argCount))
		args = append(args, *req.CurrencyID)
	}
	if req.IsActive != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("is_active = $%d", argCount))
		args = append(args, *req.IsActive)
	}

	if len(setParts) == 0 {
		return fmt.Errorf("no fields to update")
	}

	setParts = append(setParts, "updated_at = CURRENT_TIMESTAMP")

	query := fmt.Sprintf("UPDATE companies SET %s WHERE company_id = $%d",
		strings.Join(setParts, ", "), argCount+1)
	args = append(args, companyID)

	result, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update company: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("company not found")
	}

	return nil
}

func (s *CompanyService) DeleteCompany(companyID int) error {
	query := `UPDATE companies SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP WHERE company_id = $1`

	result, err := s.db.Exec(query, companyID)
	if err != nil {
		return fmt.Errorf("failed to delete company: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("company not found")
	}

	return nil
}
