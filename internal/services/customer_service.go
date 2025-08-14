package services

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type CustomerService struct {
	db *sql.DB
}

func NewCustomerService() *CustomerService {
	return &CustomerService{db: database.GetDB()}
}

// GetCustomers returns all customers for a company with optional search filter
func (s *CustomerService) GetCustomers(companyID int, search string) ([]models.Customer, error) {
	query := `
                SELECT customer_id, company_id, name, phone, email, address, tax_number,
                       credit_limit, payment_terms, is_active, sync_status, created_at, updated_at, is_deleted
                FROM customers
                WHERE company_id = $1 AND is_deleted = FALSE`

	args := []interface{}{companyID}
	if search != "" {
		query += " AND (name ILIKE $2 OR phone ILIKE $2 OR email ILIKE $2)"
		args = append(args, "%"+search+"%")
	}

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get customers: %w", err)
	}
	defer rows.Close()

	var customers []models.Customer
	for rows.Next() {
		var c models.Customer
		if err := rows.Scan(
			&c.CustomerID, &c.CompanyID, &c.Name, &c.Phone, &c.Email, &c.Address,
			&c.TaxNumber, &c.CreditLimit, &c.PaymentTerms, &c.IsActive,
			&c.SyncStatus, &c.CreatedAt, &c.UpdatedAt, &c.IsDeleted,
		); err != nil {
			return nil, fmt.Errorf("failed to scan customer: %w", err)
		}
		customers = append(customers, c)
	}

	return customers, nil
}

// CreateCustomer adds a new customer for the company
func (s *CustomerService) CreateCustomer(companyID int, req *models.CreateCustomerRequest) (*models.Customer, error) {
	query := `
                INSERT INTO customers (company_id, name, phone, email, address, tax_number,
                                       credit_limit, payment_terms)
                VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
                RETURNING customer_id, created_at, updated_at`

	var c models.Customer
	err := s.db.QueryRow(query,
		companyID, req.Name, req.Phone, req.Email, req.Address, req.TaxNumber,
		req.CreditLimit, req.PaymentTerms,
	).Scan(&c.CustomerID, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create customer: %w", err)
	}

	c.CompanyID = companyID
	c.Name = req.Name
	c.Phone = req.Phone
	c.Email = req.Email
	c.Address = req.Address
	c.TaxNumber = req.TaxNumber
	c.CreditLimit = req.CreditLimit
	c.PaymentTerms = req.PaymentTerms
	c.IsActive = true
	c.SyncStatus = "synced"
	c.IsDeleted = false

	return &c, nil
}

// UpdateCustomer modifies existing customer fields
func (s *CustomerService) UpdateCustomer(customerID, companyID int, req *models.UpdateCustomerRequest) error {
	updates := []string{}
	args := []interface{}{}
	argCount := 1

	if req.Name != nil {
		updates = append(updates, fmt.Sprintf("name = $%d", argCount))
		args = append(args, *req.Name)
		argCount++
	}
	if req.Phone != nil {
		updates = append(updates, fmt.Sprintf("phone = $%d", argCount))
		args = append(args, *req.Phone)
		argCount++
	}
	if req.Email != nil {
		updates = append(updates, fmt.Sprintf("email = $%d", argCount))
		args = append(args, *req.Email)
		argCount++
	}
	if req.Address != nil {
		updates = append(updates, fmt.Sprintf("address = $%d", argCount))
		args = append(args, *req.Address)
		argCount++
	}
	if req.TaxNumber != nil {
		updates = append(updates, fmt.Sprintf("tax_number = $%d", argCount))
		args = append(args, *req.TaxNumber)
		argCount++
	}
	if req.CreditLimit != nil {
		updates = append(updates, fmt.Sprintf("credit_limit = $%d", argCount))
		args = append(args, *req.CreditLimit)
		argCount++
	}
	if req.PaymentTerms != nil {
		updates = append(updates, fmt.Sprintf("payment_terms = $%d", argCount))
		args = append(args, *req.PaymentTerms)
		argCount++
	}
	if req.IsActive != nil {
		updates = append(updates, fmt.Sprintf("is_active = $%d", argCount))
		args = append(args, *req.IsActive)
		argCount++
	}

	if len(updates) == 0 {
		return nil
	}

	updates = append(updates, fmt.Sprintf("updated_at = $%d", argCount))
	args = append(args, time.Now())
	argCount++

	query := fmt.Sprintf("UPDATE customers SET %s WHERE customer_id = $%d AND company_id = $%d AND is_deleted = FALSE",
		strings.Join(updates, ", "), argCount, argCount+1)
	args = append(args, customerID, companyID)

	result, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update customer: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("customer not found")
	}
	return nil
}

// DeleteCustomer marks customer as deleted
func (s *CustomerService) DeleteCustomer(customerID, companyID int) error {
	result, err := s.db.Exec(
		`UPDATE customers SET is_deleted = TRUE, updated_at = CURRENT_TIMESTAMP
                  WHERE customer_id = $1 AND company_id = $2 AND is_deleted = FALSE`,
		customerID, companyID,
	)
	if err != nil {
		return fmt.Errorf("failed to delete customer: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("customer not found")
	}
	return nil
}
