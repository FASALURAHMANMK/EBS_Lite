package services

import (
	"database/sql"
	"fmt"
	"strings"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type ReturnsService struct {
    db *sql.DB
}

func NewReturnsService() *ReturnsService {
    return &ReturnsService{
        db: database.GetDB(),
    }
}

// FindReturnableSaleForCustomer attempts to find a single completed sale for
// the given customer within the company that can fully cover the requested
// return quantities for all provided items. It returns the sale_id to attach
// the return to. If none is found, an error is returned instructing the caller
// to specify an invoice.
func (s *ReturnsService) FindReturnableSaleForCustomer(companyID, customerID int, items []models.CreateSaleReturnItemRequest) (int, error) {
    // Verify customer belongs to company
    var cnt int
    if err := s.db.QueryRow(`SELECT COUNT(*) FROM customers WHERE customer_id=$1 AND company_id=$2 AND is_deleted=FALSE`, customerID, companyID).Scan(&cnt); err != nil {
        return 0, fmt.Errorf("failed to verify customer: %w", err)
    }
    if cnt == 0 {
        return 0, fmt.Errorf("customer not found")
    }

    // Candidate sales: most recent first
    rows, err := s.db.Query(`
        SELECT s.sale_id
        FROM sales s
        JOIN locations l ON s.location_id=l.location_id
        WHERE l.company_id=$1 AND s.customer_id=$2 AND s.status='COMPLETED' AND s.is_deleted=FALSE
        ORDER BY s.sale_date DESC, s.created_at DESC, s.sale_id DESC
    `, companyID, customerID)
    if err != nil {
        return 0, fmt.Errorf("failed to query candidate sales: %w", err)
    }
    defer rows.Close()

    for rows.Next() {
        var saleID int
        if err := rows.Scan(&saleID); err != nil {
            return 0, fmt.Errorf("failed to scan sale id: %w", err)
        }
        // Check if this sale can cover all items
        ok := true
        for _, it := range items {
            valid, err := s.validateReturnItem(saleID, it.ProductID, it.Quantity)
            if err != nil || !valid {
                ok = false
                break
            }
        }
        if ok {
            return saleID, nil
        }
    }
    if err := rows.Err(); err != nil {
        return 0, fmt.Errorf("failed to iterate candidate sales: %w", err)
    }

    return 0, fmt.Errorf("no single invoice can cover requested quantities; please specify an invoice")
}

func (s *ReturnsService) GetSaleReturns(companyID int, filters map[string]string) ([]models.SaleReturn, error) {
	query := `
		SELECT sr.return_id, sr.return_number, sr.sale_id, sr.location_id, sr.customer_id,
			   sr.return_date, sr.total_amount, sr.reason, sr.status, sr.created_by,
			   sr.sync_status, sr.created_at, sr.updated_at, sr.is_deleted,
			   s.sale_number, c.name as customer_name
		FROM sale_returns sr
		LEFT JOIN sales s ON sr.sale_id = s.sale_id
		LEFT JOIN customers c ON sr.customer_id = c.customer_id
		JOIN locations l ON sr.location_id = l.location_id
		WHERE l.company_id = $1 AND sr.is_deleted = FALSE
	`

	args := []interface{}{companyID}
	argCount := 1

	// Add filters
	if dateFrom := filters["date_from"]; dateFrom != "" {
		argCount++
		query += fmt.Sprintf(" AND sr.return_date >= $%d", argCount)
		args = append(args, dateFrom)
	}

	if dateTo := filters["date_to"]; dateTo != "" {
		argCount++
		query += fmt.Sprintf(" AND sr.return_date <= $%d", argCount)
		args = append(args, dateTo)
	}

	if customerID := filters["customer_id"]; customerID != "" {
		argCount++
		query += fmt.Sprintf(" AND sr.customer_id = $%d", argCount)
		args = append(args, customerID)
	}

	if saleID := filters["sale_id"]; saleID != "" {
		argCount++
		query += fmt.Sprintf(" AND sr.sale_id = $%d", argCount)
		args = append(args, saleID)
	}

	if status := filters["status"]; status != "" {
		argCount++
		query += fmt.Sprintf(" AND sr.status = $%d", argCount)
		args = append(args, status)
	}

	query += " ORDER BY sr.created_at DESC"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get sale returns: %w", err)
	}
	defer rows.Close()

	var returns []models.SaleReturn
	for rows.Next() {
		var saleReturn models.SaleReturn
		var saleNumber, customerName sql.NullString

		err := rows.Scan(
			&saleReturn.ReturnID, &saleReturn.ReturnNumber, &saleReturn.SaleID,
			&saleReturn.LocationID, &saleReturn.CustomerID, &saleReturn.ReturnDate,
			&saleReturn.TotalAmount, &saleReturn.Reason, &saleReturn.Status,
			&saleReturn.CreatedBy, &saleReturn.SyncStatus, &saleReturn.CreatedAt,
			&saleReturn.UpdatedAt, &saleReturn.IsDeleted, &saleNumber, &customerName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan sale return: %w", err)
		}

		// Get return items
		items, err := s.getSaleReturnItems(saleReturn.ReturnID)
		if err != nil {
			return nil, fmt.Errorf("failed to get return items: %w", err)
		}
		saleReturn.Items = items

		returns = append(returns, saleReturn)
	}

	return returns, nil
}

func (s *ReturnsService) GetSaleReturnByID(returnID, companyID int) (*models.SaleReturn, error) {
	query := `
		SELECT sr.return_id, sr.return_number, sr.sale_id, sr.location_id, sr.customer_id,
			   sr.return_date, sr.total_amount, sr.reason, sr.status, sr.created_by,
			   sr.sync_status, sr.created_at, sr.updated_at, sr.is_deleted,
			   s.sale_number, c.name as customer_name
		FROM sale_returns sr
		LEFT JOIN sales s ON sr.sale_id = s.sale_id
		LEFT JOIN customers c ON sr.customer_id = c.customer_id
		JOIN locations l ON sr.location_id = l.location_id
		WHERE sr.return_id = $1 AND l.company_id = $2 AND sr.is_deleted = FALSE
	`

	var saleReturn models.SaleReturn
	var saleNumber, customerName sql.NullString

	err := s.db.QueryRow(query, returnID, companyID).Scan(
		&saleReturn.ReturnID, &saleReturn.ReturnNumber, &saleReturn.SaleID,
		&saleReturn.LocationID, &saleReturn.CustomerID, &saleReturn.ReturnDate,
		&saleReturn.TotalAmount, &saleReturn.Reason, &saleReturn.Status,
		&saleReturn.CreatedBy, &saleReturn.SyncStatus, &saleReturn.CreatedAt,
		&saleReturn.UpdatedAt, &saleReturn.IsDeleted, &saleNumber, &customerName,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("sale return not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get sale return: %w", err)
	}

	// Get return items
	items, err := s.getSaleReturnItems(saleReturn.ReturnID)
	if err != nil {
		return nil, fmt.Errorf("failed to get return items: %w", err)
	}
	saleReturn.Items = items

	return &saleReturn, nil
}

func (s *ReturnsService) CreateSaleReturn(companyID, userID int, req *models.CreateSaleReturnRequest) (*models.SaleReturn, error) {
	// Verify sale exists and belongs to company
	err := s.verifySaleInCompany(req.SaleID, companyID)
	if err != nil {
		return nil, err
	}

	// Get sale details for location and customer
	var locationID int
	var customerID *int
	err = s.db.QueryRow(`
		SELECT s.location_id, s.customer_id
		FROM sales s
		JOIN locations l ON s.location_id = l.location_id
		WHERE s.sale_id = $1 AND l.company_id = $2
	`, req.SaleID, companyID).Scan(&locationID, &customerID)

	if err != nil {
		return nil, fmt.Errorf("failed to get sale details: %w", err)
	}

	// Validate return items against original sale
	for _, item := range req.Items {
		available, err := s.validateReturnItem(req.SaleID, item.ProductID, item.Quantity)
		if err != nil {
			return nil, fmt.Errorf("failed to validate return item %d: %w", item.ProductID, err)
		}
		if !available {
			return nil, fmt.Errorf("invalid return quantity for product %d", item.ProductID)
		}
	}

	// Calculate total amount
	totalAmount := float64(0)
	for _, item := range req.Items {
		totalAmount += item.Quantity * item.UnitPrice
	}

	// Start transaction
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	ns := NewNumberingSequenceService()
	returnNumber, err := ns.NextNumber(tx, "sale_return", companyID, &locationID)
	if err != nil {
		return nil, fmt.Errorf("failed to generate return number: %w", err)
	}

	// Create return
	var returnID int
	err = tx.QueryRow(`
               INSERT INTO sale_returns (return_number, sale_id, location_id, customer_id, return_date,
                                                                total_amount, reason, created_by, updated_by)
               VALUES ($1, $2, $3, $4, CURRENT_DATE, $5, $6, $7, $8)
               RETURNING return_id
       `, returnNumber, req.SaleID, locationID, customerID, totalAmount, req.Reason, userID, userID).Scan(&returnID)

	if err != nil {
		return nil, fmt.Errorf("failed to create return: %w", err)
	}

	// Create return items and update stock
	for _, item := range req.Items {
		lineTotal := item.Quantity * item.UnitPrice

		// Insert return detail
		_, err = tx.Exec(`
			INSERT INTO sale_return_details (return_id, product_id, quantity, unit_price, line_total)
			VALUES ($1, $2, $3, $4, $5)
		`, returnID, item.ProductID, item.Quantity, item.UnitPrice, lineTotal)

		if err != nil {
			return nil, fmt.Errorf("failed to create return item: %w", err)
		}

		// Update stock (add back returned quantity)
		err = s.updateStock(tx, locationID, item.ProductID, item.Quantity)
		if err != nil {
			return nil, fmt.Errorf("failed to update stock: %w", err)
		}
	}

	// Update original sale's paid amount if needed
	// This is optional business logic - you might want to create a credit note instead
	_, err = tx.Exec(`
		UPDATE sales 
		SET paid_amount = paid_amount - $1, updated_at = CURRENT_TIMESTAMP
		WHERE sale_id = $2
	`, totalAmount, req.SaleID)

	if err != nil {
		return nil, fmt.Errorf("failed to update original sale: %w", err)
	}

	// Commit transaction
	if err = tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Return created return record
	return s.GetSaleReturnByID(returnID, companyID)
}

func (s *ReturnsService) UpdateSaleReturn(returnID, companyID, userID int, updates map[string]interface{}) error {
	// Verify return belongs to company
	err := s.verifyReturnInCompany(returnID, companyID)
	if err != nil {
		return err
	}

	// Check if return can be updated
	var status string
	err = s.db.QueryRow("SELECT status FROM sale_returns WHERE return_id = $1", returnID).Scan(&status)
	if err != nil {
		return fmt.Errorf("failed to get return status: %w", err)
	}

	if status == "COMPLETED" {
		return fmt.Errorf("completed returns cannot be updated")
	}

	setParts := []string{}
	args := []interface{}{}
	argCount := 0

	for field, value := range updates {
		switch field {
		case "reason":
			argCount++
			setParts = append(setParts, fmt.Sprintf("reason = $%d", argCount))
			args = append(args, value)
		case "status":
			argCount++
			setParts = append(setParts, fmt.Sprintf("status = $%d", argCount))
			args = append(args, value)
		}
	}

	if len(setParts) == 0 {
		return fmt.Errorf("no valid fields to update")
	}

	argCount++
	setParts = append(setParts, fmt.Sprintf("updated_by = $%d", argCount))
	args = append(args, userID)

	argCount++
	setParts = append(setParts, "updated_at = CURRENT_TIMESTAMP")

	query := fmt.Sprintf("UPDATE sale_returns SET %s WHERE return_id = $%d",
		strings.Join(setParts, ", "), argCount)
	args = append(args, returnID)

	result, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update return: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("return not found")
	}

	return nil
}

func (s *ReturnsService) DeleteSaleReturn(returnID, companyID, userID int) error {
	// Verify return belongs to company
	err := s.verifyReturnInCompany(returnID, companyID)
	if err != nil {
		return err
	}

	// Check if return can be deleted
	var status string
	err = s.db.QueryRow("SELECT status FROM sale_returns WHERE return_id = $1", returnID).Scan(&status)
	if err != nil {
		return fmt.Errorf("failed to get return status: %w", err)
	}

	if status == "COMPLETED" {
		return fmt.Errorf("completed returns cannot be deleted")
	}

	query := `UPDATE sale_returns SET is_deleted = TRUE, updated_by = $2, updated_at = CURRENT_TIMESTAMP WHERE return_id = $1`

	result, err := s.db.Exec(query, returnID, userID)
	if err != nil {
		return fmt.Errorf("failed to delete return: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("return not found")
	}

	return nil
}

func (s *ReturnsService) GetReturnsSummary(companyID int, dateFrom, dateTo string) (map[string]interface{}, error) {
	query := `
		SELECT 
			COUNT(*) as total_returns,
			COALESCE(SUM(total_amount), 0) as total_amount,
			COALESCE(AVG(total_amount), 0) as average_amount
		FROM sale_returns sr
		JOIN locations l ON sr.location_id = l.location_id
		WHERE l.company_id = $1 AND sr.is_deleted = FALSE AND sr.status = 'COMPLETED'
	`

	args := []interface{}{companyID}
	argCount := 1

	if dateFrom != "" {
		argCount++
		query += fmt.Sprintf(" AND sr.return_date >= $%d", argCount)
		args = append(args, dateFrom)
	}

	if dateTo != "" {
		argCount++
		query += fmt.Sprintf(" AND sr.return_date <= $%d", argCount)
		args = append(args, dateTo)
	}

	var totalReturns int
	var totalAmount, averageAmount float64

	err := s.db.QueryRow(query, args...).Scan(&totalReturns, &totalAmount, &averageAmount)
	if err != nil {
		return nil, fmt.Errorf("failed to get returns summary: %w", err)
	}

	// Get top returned products
	topProductsQuery := `
		SELECT p.product_id, p.name, SUM(srd.quantity) as total_quantity, SUM(srd.line_total) as total_amount
		FROM sale_return_details srd
		JOIN sale_returns sr ON srd.return_id = sr.return_id
		JOIN products p ON srd.product_id = p.product_id
		JOIN locations l ON sr.location_id = l.location_id
		WHERE l.company_id = $1 AND sr.is_deleted = FALSE AND sr.status = 'COMPLETED'
	`

	topArgs := []interface{}{companyID}
	topArgCount := 1

	if dateFrom != "" {
		topArgCount++
		topProductsQuery += fmt.Sprintf(" AND sr.return_date >= $%d", topArgCount)
		topArgs = append(topArgs, dateFrom)
	}

	if dateTo != "" {
		topArgCount++
		topProductsQuery += fmt.Sprintf(" AND sr.return_date <= $%d", topArgCount)
		topArgs = append(topArgs, dateTo)
	}

	topProductsQuery += " GROUP BY p.product_id, p.name ORDER BY total_quantity DESC LIMIT 5"

	rows, err := s.db.Query(topProductsQuery, topArgs...)
	if err != nil {
		return nil, fmt.Errorf("failed to get top returned products: %w", err)
	}
	defer rows.Close()

	var topProducts []map[string]interface{}
	for rows.Next() {
		var productID int
		var productName string
		var totalQuantity float64
		var totalAmount float64

		err := rows.Scan(&productID, &productName, &totalQuantity, &totalAmount)
		if err != nil {
			return nil, fmt.Errorf("failed to scan top returned product: %w", err)
		}

		topProducts = append(topProducts, map[string]interface{}{
			"product_id":     productID,
			"product_name":   productName,
			"total_quantity": totalQuantity,
			"total_amount":   totalAmount,
		})
	}

	return map[string]interface{}{
		"total_returns":         totalReturns,
		"total_amount":          totalAmount,
		"average_amount":        averageAmount,
		"top_returned_products": topProducts,
	}, nil
}

// Helper methods
func (s *ReturnsService) getSaleReturnItems(returnID int) ([]models.SaleReturnDetail, error) {
	query := `
		SELECT srd.return_detail_id, srd.return_id, srd.sale_detail_id, srd.product_id,
			   srd.quantity, srd.unit_price, srd.line_total,
			   p.name as product_name
		FROM sale_return_details srd
		LEFT JOIN products p ON srd.product_id = p.product_id
		WHERE srd.return_id = $1
		ORDER BY srd.return_detail_id
	`

	rows, err := s.db.Query(query, returnID)
	if err != nil {
		return nil, fmt.Errorf("failed to get return items: %w", err)
	}
	defer rows.Close()

	var items []models.SaleReturnDetail
	for rows.Next() {
		var item models.SaleReturnDetail
		var productName sql.NullString

		err := rows.Scan(
			&item.ReturnDetailID, &item.ReturnID, &item.SaleDetailID, &item.ProductID,
			&item.Quantity, &item.UnitPrice, &item.LineTotal, &productName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan return item: %w", err)
		}

		items = append(items, item)
	}

	return items, nil
}

func (s *ReturnsService) GetReturnedQuantitiesBySaleDetail(saleID int) (map[int]float64, error) {
	query := `
                SELECT srd.sale_detail_id, COALESCE(SUM(srd.quantity), 0) as returned_quantity
                FROM sale_return_details srd
                JOIN sale_returns sr ON srd.return_id = sr.return_id
                WHERE sr.sale_id = $1 AND sr.status = 'COMPLETED' AND srd.sale_detail_id IS NOT NULL
                GROUP BY srd.sale_detail_id
        `

	rows, err := s.db.Query(query, saleID)
	if err != nil {
		return nil, fmt.Errorf("failed to get returned quantities: %w", err)
	}
	defer rows.Close()

	results := make(map[int]float64)
	for rows.Next() {
		var saleDetailID int
		var quantity float64
		if err := rows.Scan(&saleDetailID, &quantity); err != nil {
			return nil, fmt.Errorf("failed to scan returned quantity: %w", err)
		}
		results[saleDetailID] = quantity
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to iterate returned quantities: %w", err)
	}

	return results, nil
}

func (s *ReturnsService) validateReturnItem(saleID, productID int, returnQuantity float64) (bool, error) {
	// Get original sale quantity
	var originalQuantity float64
	err := s.db.QueryRow(`
		SELECT quantity FROM sale_details 
		WHERE sale_id = $1 AND product_id = $2
	`, saleID, productID).Scan(&originalQuantity)

	if err == sql.ErrNoRows {
		return false, fmt.Errorf("product not found in original sale")
	}
	if err != nil {
		return false, err
	}

	// Get total already returned for this product in this sale
	var totalReturned float64
	err = s.db.QueryRow(`
		SELECT COALESCE(SUM(srd.quantity), 0)
		FROM sale_return_details srd
		JOIN sale_returns sr ON srd.return_id = sr.return_id
		WHERE sr.sale_id = $1 AND srd.product_id = $2 AND sr.status = 'COMPLETED'
	`, saleID, productID).Scan(&totalReturned)

	if err != nil {
		return false, err
	}

	// Check if return quantity is valid
	availableForReturn := originalQuantity - totalReturned
	return returnQuantity <= availableForReturn, nil
}

func (s *ReturnsService) verifySaleInCompany(saleID, companyID int) error {
	var count int
	err := s.db.QueryRow(`
		SELECT COUNT(*) FROM sales s
		JOIN locations l ON s.location_id = l.location_id
		WHERE s.sale_id = $1 AND l.company_id = $2 AND s.is_deleted = FALSE
	`, saleID, companyID).Scan(&count)

	if err != nil {
		return fmt.Errorf("failed to verify sale: %w", err)
	}

	if count == 0 {
		return fmt.Errorf("sale not found")
	}

	return nil
}

func (s *ReturnsService) verifyReturnInCompany(returnID, companyID int) error {
	var count int
	err := s.db.QueryRow(`
		SELECT COUNT(*) FROM sale_returns sr
		JOIN locations l ON sr.location_id = l.location_id
		WHERE sr.return_id = $1 AND l.company_id = $2 AND sr.is_deleted = FALSE
	`, returnID, companyID).Scan(&count)

	if err != nil {
		return fmt.Errorf("failed to verify return: %w", err)
	}

	if count == 0 {
		return fmt.Errorf("return not found")
	}

	return nil
}

func (s *ReturnsService) updateStock(tx *sql.Tx, locationID, productID int, quantityChange float64) error {
	_, err := tx.Exec(`
		INSERT INTO stock (location_id, product_id, quantity, last_updated)
		VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
		ON CONFLICT (location_id, product_id)
		DO UPDATE SET 
			quantity = stock.quantity + $3,
			last_updated = CURRENT_TIMESTAMP
	`, locationID, productID, quantityChange)

	return err
}
