package services

import (
	"database/sql"
	"fmt"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type CollectionService struct {
	db *sql.DB
}

func NewCollectionService() *CollectionService {
	return &CollectionService{db: database.GetDB()}
}

// GetCollections retrieves collection records for a company with optional filters
func (s *CollectionService) GetCollections(companyID int, filters map[string]string) ([]models.Collection, error) {
	query := `
                SELECT c.collection_id, c.collection_number, c.customer_id, c.location_id, c.amount,
                       c.collection_date, c.payment_method_id, pm.name as payment_method,
                       c.reference_number, c.notes, c.created_by, c.sync_status, c.created_at, c.updated_at
                FROM collections c
                JOIN customers cu ON c.customer_id = cu.customer_id
                LEFT JOIN payment_methods pm ON c.payment_method_id = pm.method_id
                WHERE cu.company_id = $1`

	args := []interface{}{companyID}
	argCount := 1

	if v, ok := filters["customer_id"]; ok && v != "" {
		argCount++
		query += fmt.Sprintf(" AND c.customer_id = $%d", argCount)
		args = append(args, v)
	}
	if v, ok := filters["date_from"]; ok && v != "" {
		argCount++
		query += fmt.Sprintf(" AND c.collection_date >= $%d", argCount)
		args = append(args, v)
	}
	if v, ok := filters["date_to"]; ok && v != "" {
		argCount++
		query += fmt.Sprintf(" AND c.collection_date <= $%d", argCount)
		args = append(args, v)
	}

	query += " ORDER BY c.collection_date DESC"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get collections: %w", err)
	}
	defer rows.Close()

	var collections []models.Collection
	for rows.Next() {
		var col models.Collection
		if err := rows.Scan(
			&col.CollectionID, &col.CollectionNumber, &col.CustomerID, &col.LocationID,
			&col.Amount, &col.CollectionDate, &col.PaymentMethodID, &col.PaymentMethod,
			&col.ReferenceNumber, &col.Notes, &col.CreatedBy, &col.SyncStatus, &col.CreatedAt, &col.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan collection: %w", err)
		}
		invRows, err := s.db.Query(`SELECT ci.sale_id, s.sale_number, ci.amount
                        FROM collection_invoices ci
                        JOIN sales s ON ci.sale_id = s.sale_id
                        WHERE ci.collection_id = $1`, col.CollectionID)
		if err == nil {
			for invRows.Next() {
				var inv models.CollectionInvoice
				if err := invRows.Scan(&inv.SaleID, &inv.SaleNumber, &inv.Amount); err == nil {
					col.Invoices = append(col.Invoices, inv)
				}
			}
			invRows.Close()
		}
		collections = append(collections, col)
	}

	return collections, nil
}

// CreateCollection records a customer payment
func (s *CollectionService) CreateCollection(companyID, locationID, userID int, req *models.CreateCollectionRequest) (*models.Collection, error) {
	// Verify customer belongs to company
	var custCompanyID int
	err := s.db.QueryRow("SELECT company_id FROM customers WHERE customer_id = $1 AND is_deleted = FALSE", req.CustomerID).Scan(&custCompanyID)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("customer not found")
		}
		return nil, fmt.Errorf("failed to verify customer: %w", err)
	}
	if custCompanyID != companyID {
		return nil, fmt.Errorf("customer does not belong to company")
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	// Generate collection number
	number, err := s.generateCollectionNumber(tx, locationID)
	if err != nil {
		return nil, fmt.Errorf("failed to generate collection number: %w", err)
	}

	// Parse date
	collectionDate := time.Now()
	if req.ReceivedDate != nil {
		if t, err := time.Parse("2006-01-02", *req.ReceivedDate); err == nil {
			collectionDate = t
		}
	}

	var col models.Collection
	insert := `
                INSERT INTO collections (collection_number, customer_id, location_id, amount,
                                         collection_date, payment_method_id, reference_number, notes, created_by)
                VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
                RETURNING collection_id, collection_number, collection_date, created_at, updated_at`

	err = tx.QueryRow(insert,
		number, req.CustomerID, locationID, req.Amount, collectionDate, req.PaymentMethodID,
		req.ReferenceNumber, req.Notes, userID,
	).Scan(&col.CollectionID, &col.CollectionNumber, &col.CollectionDate, &col.CreatedAt, &col.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to insert collection: %w", err)
	}

	// Link invoices if provided
	for _, inv := range req.Invoices {
		if _, err := tx.Exec(`INSERT INTO collection_invoices (collection_id, sale_id, amount) VALUES ($1,$2,$3)`,
			col.CollectionID, inv.SaleID, inv.Amount); err != nil {
			return nil, fmt.Errorf("failed to insert collection invoice: %w", err)
		}
		var saleNumber string
		_ = tx.QueryRow("SELECT sale_number FROM sales WHERE sale_id = $1", inv.SaleID).Scan(&saleNumber)
		col.Invoices = append(col.Invoices, models.CollectionInvoice{SaleID: inv.SaleID, SaleNumber: saleNumber, Amount: inv.Amount})
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	col.CustomerID = req.CustomerID
	col.LocationID = locationID
	col.Amount = req.Amount
	col.PaymentMethodID = req.PaymentMethodID
	col.ReferenceNumber = req.ReferenceNumber
	col.Notes = req.Notes
	col.CreatedBy = userID
	col.SyncStatus = "synced"

	// Fetch payment method name if available
	if col.PaymentMethodID != nil {
		_ = s.db.QueryRow("SELECT name FROM payment_methods WHERE method_id = $1", *col.PaymentMethodID).Scan(&col.PaymentMethod)
	}

	return &col, nil
}

// DeleteCollection removes a collection record
func (s *CollectionService) DeleteCollection(collectionID, companyID int) error {
	result, err := s.db.Exec(`
                DELETE FROM collections USING customers
                WHERE collections.collection_id = $1
                  AND collections.customer_id = customers.customer_id
                  AND customers.company_id = $2`, collectionID, companyID)
	if err != nil {
		return fmt.Errorf("failed to delete collection: %w", err)
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("collection not found")
	}
	return nil
}

func (s *CollectionService) generateCollectionNumber(tx *sql.Tx, locationID int) (string, error) {
	var count int
	err := tx.QueryRow(`
                SELECT COUNT(*) FROM collections
                WHERE location_id = $1 AND DATE(created_at) = CURRENT_DATE`, locationID).Scan(&count)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("COL-%d-%s-%04d", locationID, time.Now().Format("20060102"), count+1), nil
}

// GetCollectionByID retrieves a single collection with invoice references
func (s *CollectionService) GetCollectionByID(collectionID, companyID int) (*models.Collection, error) {
	query := `SELECT c.collection_id, c.collection_number, c.customer_id, c.location_id, c.amount,
                         c.collection_date, c.payment_method_id, pm.name as payment_method,
                         c.reference_number, c.notes, c.created_by, c.sync_status, c.created_at, c.updated_at
                  FROM collections c
                  JOIN customers cu ON c.customer_id = cu.customer_id
                  LEFT JOIN payment_methods pm ON c.payment_method_id = pm.method_id
                  WHERE c.collection_id = $1 AND cu.company_id = $2`

	var col models.Collection
	err := s.db.QueryRow(query, collectionID, companyID).Scan(
		&col.CollectionID, &col.CollectionNumber, &col.CustomerID, &col.LocationID,
		&col.Amount, &col.CollectionDate, &col.PaymentMethodID, &col.PaymentMethod,
		&col.ReferenceNumber, &col.Notes, &col.CreatedBy, &col.SyncStatus, &col.CreatedAt, &col.UpdatedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("collection not found")
		}
		return nil, fmt.Errorf("failed to get collection: %w", err)
	}

	rows, err := s.db.Query(`SELECT ci.sale_id, s.sale_number, ci.amount
                FROM collection_invoices ci
                JOIN sales s ON ci.sale_id = s.sale_id
                WHERE ci.collection_id = $1`, collectionID)
	if err == nil {
		for rows.Next() {
			var inv models.CollectionInvoice
			if err := rows.Scan(&inv.SaleID, &inv.SaleNumber, &inv.Amount); err == nil {
				col.Invoices = append(col.Invoices, inv)
			}
		}
		rows.Close()
	}

	return &col, nil
}
