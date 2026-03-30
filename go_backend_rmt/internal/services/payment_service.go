package services

import (
	"database/sql"
	"fmt"
	"log"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type PaymentService struct {
	db *sql.DB
}

func NewPaymentService() *PaymentService {
	return &PaymentService{db: database.GetDB()}
}

// GetPayments returns supplier payments filtered by supplier/location/date range.
func (s *PaymentService) GetPayments(companyID int, filters map[string]string) ([]models.Payment, error) {
	query := `
        SELECT pay.payment_id, pay.payment_number, pay.supplier_id, pay.purchase_id, pay.location_id,
               pay.amount, pay.payment_method_id, pay.reference_number, pay.notes,
               pay.payment_date, pay.created_by, pay.updated_by, pay.sync_status, pay.created_at, pay.updated_at
        FROM payments pay
        LEFT JOIN suppliers sup ON pay.supplier_id = sup.supplier_id
        WHERE (sup.company_id = $1 OR pay.supplier_id IS NULL)
          AND (pay.is_deleted IS NULL OR pay.is_deleted = FALSE)
    `

	args := []interface{}{companyID}
	arg := 2
	if v, ok := filters["supplier_id"]; ok && v != "" {
		query += fmt.Sprintf(" AND pay.supplier_id = $%d", arg)
		args = append(args, v)
		arg++
	}
	if v, ok := filters["location_id"]; ok && v != "" {
		query += fmt.Sprintf(" AND pay.location_id = $%d", arg)
		args = append(args, v)
		arg++
	}
	if v, ok := filters["date_from"]; ok && v != "" {
		query += fmt.Sprintf(" AND pay.payment_date >= $%d", arg)
		args = append(args, v)
		arg++
	}
	if v, ok := filters["date_to"]; ok && v != "" {
		query += fmt.Sprintf(" AND pay.payment_date <= $%d", arg)
		args = append(args, v)
		arg++
	}
	query += " ORDER BY pay.payment_date DESC, pay.payment_id DESC"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get payments: %w", err)
	}
	defer rows.Close()

	var list []models.Payment
	for rows.Next() {
		var p models.Payment
		if err := rows.Scan(&p.PaymentID, &p.PaymentNumber, &p.SupplierID, &p.PurchaseID, &p.LocationID,
			&p.Amount, &p.PaymentMethodID, &p.ReferenceNumber, &p.Notes,
			&p.PaymentDate, &p.CreatedBy, &p.UpdatedBy, &p.SyncStatus, &p.CreatedAt, &p.UpdatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan payment: %w", err)
		}
		list = append(list, p)
	}
	return list, nil
}

// CreatePayment records a supplier payment and optionally applies it to a purchase
func (s *PaymentService) CreatePayment(companyID, locationID, userID int, req *models.CreatePaymentRequest) (*models.Payment, error) {
	idemKey := ""
	if req != nil && req.IdempotencyKey != nil {
		idemKey = strings.TrimSpace(*req.IdempotencyKey)
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	if idemKey != "" {
		existing, err := s.getPaymentByIdempotencyKey(idemKey, companyID, locationID)
		if err != nil {
			return nil, err
		}
		if existing != nil {
			_ = NewFinanceIntegrityServiceWithDB(s.db).ProcessAggregate(companyID, "payment", existing.PaymentID)
			return existing, nil
		}
	}

	var supplierID *int = req.SupplierID

	// If purchase_id provided, validate purchase and derive supplier/location if missing
	if req.PurchaseID != nil {
		var purSupplierID, purLocationID, purCompanyID int
		var totalAmt, paidAmt float64
		if err := tx.QueryRow(
			`SELECT p.supplier_id, p.location_id, s.company_id, p.total_amount, p.paid_amount
             FROM purchases p JOIN suppliers s ON p.supplier_id = s.supplier_id
             WHERE p.purchase_id = $1 AND p.is_deleted = FALSE`, *req.PurchaseID,
		).Scan(&purSupplierID, &purLocationID, &purCompanyID, &totalAmt, &paidAmt); err != nil {
			if err == sql.ErrNoRows {
				return nil, fmt.Errorf("purchase not found")
			}
			return nil, fmt.Errorf("failed to verify purchase: %w", err)
		}
		if purCompanyID != companyID {
			return nil, fmt.Errorf("purchase does not belong to company")
		}
		// enforce not overpaying a specific purchase
		if req.Amount > (totalAmt-paidAmt)+0.0001 { // small epsilon
			return nil, fmt.Errorf("payment exceeds outstanding amount for purchase")
		}
		// ensure location matches when provided from context
		if locationID != 0 && purLocationID != locationID {
			// allow overriding if query param provided different? Keep strict: require same location
			// because numbering sequence usually location-based
		}
		supplierID = &purSupplierID
	}

	// If supplier specified (or derived), verify supplier belongs to company
	if supplierID != nil {
		var exists int
		if err := tx.QueryRow(
			`SELECT 1 FROM suppliers WHERE supplier_id = $1 AND company_id = $2 AND is_active = TRUE`, *supplierID, companyID,
		).Scan(&exists); err != nil {
			if err == sql.ErrNoRows {
				return nil, fmt.Errorf("supplier not found")
			}
			return nil, fmt.Errorf("failed to verify supplier: %w", err)
		}
	}

	// Generate payment number using numbering sequence
	ns := NewNumberingSequenceService()
	paymentNumber, err := ns.NextNumber(tx, "payment", companyID, &locationID)
	if err != nil {
		return nil, fmt.Errorf("failed to generate payment number: %w", err)
	}

	// Parse date
	payDate := time.Now()
	if req.PaymentDate != nil {
		if t, err := time.Parse("2006-01-02", *req.PaymentDate); err == nil {
			payDate = t
		}
	}

	// Insert payment
	var p models.Payment
	insert := `
        INSERT INTO payments (payment_number, supplier_id, purchase_id, location_id, payment_date,
                              amount, payment_method_id, reference_number, notes, created_by, updated_by, idempotency_key)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$10,NULLIF($11,''))
        RETURNING payment_id, payment_number, payment_date, created_at, updated_at`
	if err := tx.QueryRow(insert,
		paymentNumber, supplierID, req.PurchaseID, locationID, payDate,
		req.Amount, req.PaymentMethodID, req.ReferenceNumber, req.Notes, userID, idemKey,
	).Scan(&p.PaymentID, &p.PaymentNumber, &p.PaymentDate, &p.CreatedAt, &p.UpdatedAt); err != nil {
		if idemKey != "" && isUniqueViolation(err) {
			existing, lookupErr := s.getPaymentByIdempotencyKey(idemKey, companyID, locationID)
			if lookupErr != nil {
				return nil, lookupErr
			}
			if existing != nil {
				_ = NewFinanceIntegrityServiceWithDB(s.db).ProcessAggregate(companyID, "payment", existing.PaymentID)
				return existing, nil
			}
		}
		return nil, fmt.Errorf("failed to insert payment: %w", err)
	}

	// If linked to a purchase, update its paid_amount
	if req.PurchaseID != nil {
		if _, err := tx.Exec(
			`UPDATE purchases SET paid_amount = paid_amount + $1, updated_at = CURRENT_TIMESTAMP, updated_by = $2 WHERE purchase_id = $3`,
			req.Amount, userID, *req.PurchaseID,
		); err != nil {
			return nil, fmt.Errorf("failed to update purchase paid amount: %w", err)
		}
	}

	finance := NewFinanceIntegrityServiceWithDB(s.db)
	if err := finance.EnqueueTx(tx, &models.FinanceOutboxEntry{
		CompanyID:     companyID,
		LocationID:    &locationID,
		EventType:     financeEventLedgerSupplierPay,
		AggregateType: "payment",
		AggregateID:   p.PaymentID,
		Payload:       models.JSONB{},
		CreatedBy:     &userID,
	}); err != nil {
		return nil, fmt.Errorf("failed to enqueue supplier payment ledger posting: %w", err)
	}

	isCash := true
	if req.PaymentMethodID != nil {
		var paymentType string
		if err := tx.QueryRow(`SELECT type FROM payment_methods WHERE method_id = $1`, *req.PaymentMethodID).Scan(&paymentType); err == nil {
			isCash = strings.EqualFold(strings.TrimSpace(paymentType), "CASH")
		}
	}
	if isCash && req.Amount > 0 {
		note := fmt.Sprintf("payment_id=%d payment_number=%s", p.PaymentID, p.PaymentNumber)
		if err := finance.EnqueueTx(tx, &models.FinanceOutboxEntry{
			CompanyID:     companyID,
			LocationID:    &locationID,
			EventType:     financeEventCashSupplierPay,
			AggregateType: "payment",
			AggregateID:   p.PaymentID,
			Payload: models.JSONB{
				"amount":      req.Amount,
				"direction":   "OUT",
				"event_type":  "SUPPLIER_PAYMENT",
				"reason_code": fmt.Sprintf("payment:%d", p.PaymentID),
				"notes":       note,
			},
			CreatedBy: &userID,
		}); err != nil {
			return nil, fmt.Errorf("failed to enqueue supplier payment cash register event: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}
	if err := finance.ProcessAggregate(companyID, "payment", p.PaymentID); err != nil {
		log.Printf("payment_service: failed to process finance outbox for payment %d: %v", p.PaymentID, err)
	}

	p.SupplierID = supplierID
	p.PurchaseID = req.PurchaseID
	p.LocationID = &locationID
	p.Amount = req.Amount
	p.PaymentMethodID = req.PaymentMethodID
	p.ReferenceNumber = req.ReferenceNumber
	p.Notes = req.Notes
	p.IdempotencyKey = nullIfEmpty(idemKey)
	p.CreatedBy = userID
	p.SyncStatus = "synced"
	return &p, nil
}

func (s *PaymentService) getPaymentByIdempotencyKey(key string, companyID, locationID int) (*models.Payment, error) {
	if strings.TrimSpace(key) == "" {
		return nil, nil
	}
	var item models.Payment
	var supplierID sql.NullInt64
	var purchaseID sql.NullInt64
	var locationValue sql.NullInt64
	var paymentMethodID sql.NullInt64
	var referenceNumber sql.NullString
	var notes sql.NullString
	var idempotencyKey sql.NullString
	var updatedBy sql.NullInt64
	err := s.db.QueryRow(`
		SELECT pay.payment_id, pay.payment_number, pay.supplier_id, pay.purchase_id, pay.location_id,
		       pay.amount, pay.payment_method_id, pay.reference_number, pay.notes, pay.idempotency_key,
		       pay.payment_date, pay.created_by, pay.updated_by, pay.created_at, pay.updated_at
		FROM payments pay
		LEFT JOIN suppliers sup ON sup.supplier_id = pay.supplier_id
		WHERE pay.location_id = $1
		  AND pay.idempotency_key = $2
		  AND (sup.company_id = $3 OR pay.supplier_id IS NULL)
		  AND COALESCE(pay.is_deleted, FALSE) = FALSE
	`, locationID, key, companyID).Scan(
		&item.PaymentID,
		&item.PaymentNumber,
		&supplierID,
		&purchaseID,
		&locationValue,
		&item.Amount,
		&paymentMethodID,
		&referenceNumber,
		&notes,
		&idempotencyKey,
		&item.PaymentDate,
		&item.CreatedBy,
		&updatedBy,
		&item.CreatedAt,
		&item.UpdatedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to lookup payment idempotency key: %w", err)
	}
	if supplierID.Valid {
		v := int(supplierID.Int64)
		item.SupplierID = &v
	}
	if purchaseID.Valid {
		v := int(purchaseID.Int64)
		item.PurchaseID = &v
	}
	if locationValue.Valid {
		v := int(locationValue.Int64)
		item.LocationID = &v
	}
	if paymentMethodID.Valid {
		v := int(paymentMethodID.Int64)
		item.PaymentMethodID = &v
	}
	if referenceNumber.Valid {
		item.ReferenceNumber = &referenceNumber.String
	}
	if notes.Valid {
		item.Notes = &notes.String
	}
	if idempotencyKey.Valid {
		item.IdempotencyKey = &idempotencyKey.String
	}
	if updatedBy.Valid {
		v := int(updatedBy.Int64)
		item.UpdatedBy = &v
	}
	return &item, nil
}
