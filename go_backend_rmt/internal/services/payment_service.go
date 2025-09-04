package services

import (
    "database/sql"
    "fmt"

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

