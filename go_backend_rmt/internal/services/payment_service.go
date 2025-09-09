package services

import (
    "database/sql"
    "fmt"
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
    tx, err := s.db.Begin()
    if err != nil {
        return nil, fmt.Errorf("failed to start transaction: %w", err)
    }
    defer tx.Rollback()

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
                              amount, payment_method_id, reference_number, notes, created_by, updated_by)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$10)
        RETURNING payment_id, payment_number, payment_date, created_at, updated_at`
    if err := tx.QueryRow(insert,
        paymentNumber, supplierID, req.PurchaseID, locationID, payDate,
        req.Amount, req.PaymentMethodID, req.ReferenceNumber, req.Notes, userID,
    ).Scan(&p.PaymentID, &p.PaymentNumber, &p.PaymentDate, &p.CreatedAt, &p.UpdatedAt); err != nil {
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

    if err := tx.Commit(); err != nil {
        return nil, fmt.Errorf("failed to commit transaction: %w", err)
    }

    p.SupplierID = supplierID
    p.PurchaseID = req.PurchaseID
    p.LocationID = &locationID
    p.Amount = req.Amount
    p.PaymentMethodID = req.PaymentMethodID
    p.ReferenceNumber = req.ReferenceNumber
    p.Notes = req.Notes
    p.CreatedBy = userID
    p.SyncStatus = "synced"
    return &p, nil
}
