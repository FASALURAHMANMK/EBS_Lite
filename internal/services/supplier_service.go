package services

import (
	"database/sql"
	"fmt"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type SupplierService struct {
	db *sql.DB
}

func NewSupplierService() *SupplierService {
	return &SupplierService{
		db: database.GetDB(),
	}
}

func (s *SupplierService) GetSuppliers(companyID int, filters map[string]string) ([]models.SupplierWithStats, error) {
	query := `
		SELECT s.supplier_id, s.company_id, s.name, s.contact_person, s.phone, s.email,
			   s.address, s.tax_number, s.payment_terms, s.credit_limit, s.is_active,
			   s.sync_status, s.created_at, s.updated_at,
			   COALESCE(stats.total_purchases, 0) as total_purchases,
			   COALESCE(stats.total_returns, 0) as total_returns,
			   COALESCE(stats.outstanding_amount, 0) as outstanding_amount,
			   stats.last_purchase_date
		FROM suppliers s
		LEFT JOIN (
			SELECT supplier_id,
				   SUM(CASE WHEN p.status != 'CANCELLED' THEN p.total_amount ELSE 0 END) as total_purchases,
				   SUM(COALESCE(pr.total_amount, 0)) as total_returns,
				   SUM(CASE WHEN p.status != 'CANCELLED' THEN (p.total_amount - p.paid_amount) ELSE 0 END) as outstanding_amount,
				   MAX(p.purchase_date) as last_purchase_date
			FROM purchases p
			LEFT JOIN purchase_returns pr ON p.purchase_id = pr.purchase_id
			WHERE p.is_deleted = FALSE
			GROUP BY supplier_id
		) stats ON s.supplier_id = stats.supplier_id
		WHERE s.company_id = $1
	`

	args := []interface{}{companyID}
	argCount := 1

	// Apply filters
	if isActive, ok := filters["is_active"]; ok && isActive != "" {
		argCount++
		query += fmt.Sprintf(" AND s.is_active = $%d", argCount)
		args = append(args, isActive == "true")
	}

	if search, ok := filters["search"]; ok && search != "" {
		argCount++
		query += fmt.Sprintf(" AND (s.name ILIKE $%d OR s.contact_person ILIKE $%d OR s.phone ILIKE $%d OR s.email ILIKE $%d)",
			argCount, argCount, argCount, argCount)
		searchPattern := "%" + search + "%"
		args = append(args, searchPattern)
	}

	query += " ORDER BY s.name"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get suppliers: %w", err)
	}
	defer rows.Close()

	var suppliers []models.SupplierWithStats
	for rows.Next() {
		var supplier models.SupplierWithStats

		err := rows.Scan(
			&supplier.SupplierID, &supplier.CompanyID, &supplier.Name, &supplier.ContactPerson,
			&supplier.Phone, &supplier.Email, &supplier.Address, &supplier.TaxNumber,
			&supplier.PaymentTerms, &supplier.CreditLimit, &supplier.IsActive,
			&supplier.SyncStatus, &supplier.CreatedAt, &supplier.UpdatedAt,
			&supplier.TotalPurchases, &supplier.TotalReturns, &supplier.OutstandingAmount,
			&supplier.LastPurchaseDate,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan supplier: %w", err)
		}

		suppliers = append(suppliers, supplier)
	}

	return suppliers, nil
}

func (s *SupplierService) GetSupplierByID(supplierID, companyID int) (*models.SupplierWithStats, error) {
	query := `
		SELECT s.supplier_id, s.company_id, s.name, s.contact_person, s.phone, s.email,
			   s.address, s.tax_number, s.payment_terms, s.credit_limit, s.is_active,
			   s.sync_status, s.created_at, s.updated_at,
			   COALESCE(stats.total_purchases, 0) as total_purchases,
			   COALESCE(stats.total_returns, 0) as total_returns,
			   COALESCE(stats.outstanding_amount, 0) as outstanding_amount,
			   stats.last_purchase_date
		FROM suppliers s
		LEFT JOIN (
			SELECT supplier_id,
				   SUM(CASE WHEN p.status != 'CANCELLED' THEN p.total_amount ELSE 0 END) as total_purchases,
				   SUM(COALESCE(pr.total_amount, 0)) as total_returns,
				   SUM(CASE WHEN p.status != 'CANCELLED' THEN (p.total_amount - p.paid_amount) ELSE 0 END) as outstanding_amount,
				   MAX(p.purchase_date) as last_purchase_date
			FROM purchases p
			LEFT JOIN purchase_returns pr ON p.purchase_id = pr.purchase_id
			WHERE p.is_deleted = FALSE
			GROUP BY supplier_id
		) stats ON s.supplier_id = stats.supplier_id
		WHERE s.supplier_id = $1 AND s.company_id = $2
	`

	var supplier models.SupplierWithStats
	err := s.db.QueryRow(query, supplierID, companyID).Scan(
		&supplier.SupplierID, &supplier.CompanyID, &supplier.Name, &supplier.ContactPerson,
		&supplier.Phone, &supplier.Email, &supplier.Address, &supplier.TaxNumber,
		&supplier.PaymentTerms, &supplier.CreditLimit, &supplier.IsActive,
		&supplier.SyncStatus, &supplier.CreatedAt, &supplier.UpdatedAt,
		&supplier.TotalPurchases, &supplier.TotalReturns, &supplier.OutstandingAmount,
		&supplier.LastPurchaseDate,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("supplier not found")
		}
		return nil, fmt.Errorf("failed to get supplier: %w", err)
	}

	return &supplier, nil
}

func (s *SupplierService) CreateSupplier(companyID int, req *models.CreateSupplierRequest) (*models.Supplier, error) {
	// Check if supplier with same name already exists
	var existingID int
	err := s.db.QueryRow(`
		SELECT supplier_id FROM suppliers 
		WHERE company_id = $1 AND LOWER(name) = LOWER($2)
	`, companyID, req.Name).Scan(&existingID)
	if err == nil {
		return nil, fmt.Errorf("supplier with this name already exists")
	} else if err != sql.ErrNoRows {
		return nil, fmt.Errorf("failed to check existing supplier: %w", err)
	}

	// Set defaults
	paymentTerms := 0
	if req.PaymentTerms != nil {
		paymentTerms = *req.PaymentTerms
	}

	creditLimit := float64(0)
	if req.CreditLimit != nil {
		creditLimit = *req.CreditLimit
	}

	// Insert supplier
	insertQuery := `
		INSERT INTO suppliers (company_id, name, contact_person, phone, email, address,
							  tax_number, payment_terms, credit_limit, is_active)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING supplier_id, created_at
	`

	var supplier models.Supplier
	err = s.db.QueryRow(insertQuery,
		companyID, req.Name, req.ContactPerson, req.Phone, req.Email, req.Address,
		req.TaxNumber, paymentTerms, creditLimit, true,
	).Scan(&supplier.SupplierID, &supplier.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to insert supplier: %w", err)
	}

	// Set response data
	supplier.CompanyID = companyID
	supplier.Name = req.Name
	supplier.ContactPerson = req.ContactPerson
	supplier.Phone = req.Phone
	supplier.Email = req.Email
	supplier.Address = req.Address
	supplier.TaxNumber = req.TaxNumber
	supplier.PaymentTerms = paymentTerms
	supplier.CreditLimit = creditLimit
	supplier.IsActive = true

	return &supplier, nil
}

func (s *SupplierService) UpdateSupplier(supplierID, companyID int, req *models.UpdateSupplierRequest) error {
	// Verify supplier exists and belongs to company
	var exists bool
	err := s.db.QueryRow("SELECT TRUE FROM suppliers WHERE supplier_id = $1 AND company_id = $2",
		supplierID, companyID).Scan(&exists)
	if err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("supplier not found")
		}
		return fmt.Errorf("failed to verify supplier: %w", err)
	}

	// Check for duplicate name if updating name
	if req.Name != nil {
		var existingID int
		err := s.db.QueryRow(`
			SELECT supplier_id FROM suppliers 
			WHERE company_id = $1 AND LOWER(name) = LOWER($2) AND supplier_id != $3
		`, companyID, *req.Name, supplierID).Scan(&existingID)
		if err == nil {
			return fmt.Errorf("supplier with this name already exists")
		} else if err != sql.ErrNoRows {
			return fmt.Errorf("failed to check existing supplier: %w", err)
		}
	}

	// Build update query
	updates := []string{}
	args := []interface{}{}
	argCount := 0

	if req.Name != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("name = $%d", argCount))
		args = append(args, *req.Name)
	}

	if req.ContactPerson != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("contact_person = $%d", argCount))
		args = append(args, *req.ContactPerson)
	}

	if req.Phone != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("phone = $%d", argCount))
		args = append(args, *req.Phone)
	}

	if req.Email != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("email = $%d", argCount))
		args = append(args, *req.Email)
	}

	if req.Address != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("address = $%d", argCount))
		args = append(args, *req.Address)
	}

	if req.TaxNumber != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("tax_number = $%d", argCount))
		args = append(args, *req.TaxNumber)
	}

	if req.PaymentTerms != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("payment_terms = $%d", argCount))
		args = append(args, *req.PaymentTerms)
	}

	if req.CreditLimit != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("credit_limit = $%d", argCount))
		args = append(args, *req.CreditLimit)
	}

	if req.IsActive != nil {
		argCount++
		updates = append(updates, fmt.Sprintf("is_active = $%d", argCount))
		args = append(args, *req.IsActive)
	}

	if len(updates) == 0 {
		return nil // No updates requested
	}

	// Add updated_at
	argCount++
	updates = append(updates, fmt.Sprintf("updated_at = $%d", argCount))
	args = append(args, time.Now())

	// Add WHERE clause
	argCount++
	query := fmt.Sprintf("UPDATE suppliers SET %s WHERE supplier_id = $%d",
		fmt.Sprintf("%s", updates), argCount)
	args = append(args, supplierID)

	_, err = s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update supplier: %w", err)
	}

	return nil
}

func (s *SupplierService) DeleteSupplier(supplierID, companyID int) error {
	// Check if supplier has any purchases
	var purchaseCount int
	err := s.db.QueryRow(`
		SELECT COUNT(*) FROM purchases 
		WHERE supplier_id = $1 AND is_deleted = FALSE
	`, supplierID).Scan(&purchaseCount)
	if err != nil {
		return fmt.Errorf("failed to check supplier usage: %w", err)
	}

	if purchaseCount > 0 {
		return fmt.Errorf("cannot delete supplier with existing purchases")
	}

	// Verify supplier exists and belongs to company
	var exists bool
	err = s.db.QueryRow("SELECT TRUE FROM suppliers WHERE supplier_id = $1 AND company_id = $2",
		supplierID, companyID).Scan(&exists)
	if err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("supplier not found")
		}
		return fmt.Errorf("failed to verify supplier: %w", err)
	}

	// Soft delete by deactivating
	_, err = s.db.Exec(`
		UPDATE suppliers SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP
		WHERE supplier_id = $1
	`, supplierID)
	if err != nil {
		return fmt.Errorf("failed to delete supplier: %w", err)
	}

	return nil
}
