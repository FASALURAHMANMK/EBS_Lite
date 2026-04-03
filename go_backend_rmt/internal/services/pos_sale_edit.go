package services

import (
	"database/sql"
	"fmt"
	"math"
	"strings"
	"time"

	"erp-backend/internal/models"

	"github.com/lib/pq"
)

type editableSaleHeader struct {
	SaleNumber       string
	LocationID       int
	Status           string
	SourceChannel    sql.NullString
	TransactionType  string
	RefundSourceSale sql.NullInt64
	IsTraining       bool
	CustomerID       sql.NullInt64
	TotalAmount      float64
	PaidAmount       float64
	PaymentMethodID  sql.NullInt64
	Notes            sql.NullString
	UpdatedAt        time.Time
}

type editableSaleLine struct {
	SaleDetailID   int
	ProductID      *int
	ComboProductID *int
	BarcodeID      *int
	Quantity       float64
	StockQuantity  float64
	SerialNumbers  []string
	CostPrice      float64
	Notes          *string
}

func (s *POSService) EditCompletedSale(companyID, locationID, userID, saleID int, req *models.POSEditSaleRequest, requestID string) (*models.Sale, error) {
	if req == nil {
		return nil, fmt.Errorf("request is required")
	}
	if len(req.Items) == 0 {
		return nil, fmt.Errorf("at least one item is required")
	}
	if err := s.validateLocationInCompany(locationID, companyID); err != nil {
		return nil, err
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	header, err := s.loadEditableSaleHeaderTx(tx, companyID, saleID)
	if err != nil {
		return nil, err
	}
	if header.LocationID != locationID {
		return nil, fmt.Errorf("invalid location for sale")
	}
	if req.TransactionType != nil {
		requestedType := normalizeTransactionType(*req.TransactionType)
		if requestedType == "" {
			return nil, fmt.Errorf("invalid transaction_type")
		}
		if requestedType != normalizeTransactionType(header.TransactionType) {
			return nil, fmt.Errorf("transaction_type mismatch for sale edit")
		}
	}
	if normalizeTransactionType(header.TransactionType) == "B2B" && req.CustomerID == nil {
		return nil, fmt.Errorf("b2b transactions require customer_id")
	}
	if !strings.EqualFold(header.Status, "COMPLETED") {
		return nil, fmt.Errorf("only completed sales can be edited")
	}
	if header.RefundSourceSale.Valid || strings.EqualFold(strings.TrimSpace(header.SourceChannel.String), "POS_REFUND") {
		return nil, fmt.Errorf("refund invoices cannot be edited")
	}
	if req.BaselineUpdatedAt == nil {
		return nil, fmt.Errorf("baseline updated_at is required")
	}
	if !timestampsMatch(header.UpdatedAt, *req.BaselineUpdatedAt) {
		return nil, fmt.Errorf("sale has changed since the edit session started")
	}
	if err := s.ensureSaleHasNoDependentRefundsTx(tx, companyID, saleID); err != nil {
		return nil, err
	}
	if err := requireSalesActionPassword(tx, companyID, userID, req.SalesActionPassword); err != nil {
		return nil, err
	}

	saleReq := &models.CreateSaleRequest{
		TransactionType:  &header.TransactionType,
		CustomerID:       req.CustomerID,
		Items:            req.Items,
		PaymentMethodID:  req.PaymentMethodID,
		DiscountAmount:   req.DiscountAmount,
		PaidAmount:       req.PaidAmount,
		Notes:            req.Notes,
		OverridePassword: req.OverridePassword,
	}
	subtotal, tax, total, err := s.salesService.CalculateTotals(companyID, saleReq)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate totals: %w", err)
	}
	if req.PaidAmount < 0 || req.PaidAmount > total {
		return nil, fmt.Errorf("invalid paid amount")
	}

	preTotal := subtotal + tax
	overrideApproverID, overrideUsed, err := s.enforceDiscountLimits(
		companyID,
		userID,
		req.Items,
		req.DiscountAmount,
		preTotal,
		req.ManagerOverrideToken,
		req.OverrideReason,
	)
	if err != nil {
		return nil, err
	}

	if !header.IsTraining && req.CustomerID != nil {
		oldOutstanding := header.TotalAmount - header.PaidAmount
		newOutstanding := total - req.PaidAmount
		outstandingDelta := newOutstanding
		if header.CustomerID.Valid && int(header.CustomerID.Int64) == *req.CustomerID {
			outstandingDelta = newOutstanding - oldOutstanding
		}
		if outstandingDelta > 0.0001 {
			if err := s.enforceCustomerCreditLimit(companyID, *req.CustomerID, outstandingDelta); err != nil {
				return nil, err
			}
		}
	}

	oldCashIn, err := s.cashInBaseFromExistingSaleTx(tx, saleID)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate existing cash posting: %w", err)
	}
	newCashIn, err := s.cashInBaseFromEditRequestTx(tx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate updated cash posting: %w", err)
	}

	lines, err := s.loadEditableSaleLinesTx(tx, companyID, saleID)
	if err != nil {
		return nil, err
	}
	if err := s.restoreEditedSaleStockTx(tx, companyID, locationID, userID, lines); err != nil {
		return nil, err
	}

	if _, err := tx.Exec(`DELETE FROM sale_details WHERE sale_id = $1`, saleID); err != nil {
		return nil, fmt.Errorf("failed to clear sale details: %w", err)
	}
	if _, err := tx.Exec(`DELETE FROM sale_payments WHERE sale_id = $1`, saleID); err != nil {
		return nil, fmt.Errorf("failed to clear sale payments: %w", err)
	}

	preparedLines, err := prepareSaleDetailsTx(tx, companyID, locationID, req.Items)
	if err != nil {
		return nil, err
	}
	trackingSvc := newInventoryTrackingService(s.db)
	actualCosts := make([]issuedSaleLineCost, 0, len(preparedLines))
	for _, line := range preparedLines {
		var saleDetailID int
		if err := tx.QueryRow(`
			INSERT INTO sale_details (
				sale_id, product_id, combo_product_id, barcode_id, product_name, quantity, unit_price,
				discount_percentage, discount_amount, tax_id, tax_amount, line_total, serial_numbers, notes, cost_price,
				stock_unit_id, selling_unit_id, selling_uom_mode, selling_to_stock_factor, stock_quantity
			)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20)
			RETURNING sale_detail_id
		`, saleID, line.ProductID, line.ComboProductID, line.BarcodeID, line.ProductName, line.Quantity, line.UnitPrice,
			line.DiscountPercent, line.DiscountAmount, line.TaxID, line.TaxAmount, line.LineTotal,
			pq.Array(line.SerialNumbers), line.Notes, line.Snapshot.CostPricePerUnit,
			line.Snapshot.StockUnitID, line.Snapshot.SellingUnitID, line.Snapshot.SellingUOMMode,
			line.Snapshot.SellingToStock, line.Snapshot.StockQuantity).Scan(&saleDetailID); err != nil {
			return nil, fmt.Errorf("failed to insert edited sale detail: %w", err)
		}

		if header.IsTraining || line.ProductID == nil {
			actualCosts = append(actualCosts, issuedSaleLineCost{
				BarcodeID:        line.BarcodeID,
				CostPricePerUnit: line.Snapshot.CostPricePerUnit,
				TotalCost:        line.Snapshot.CostPricePerUnit * line.Quantity,
			})
			continue
		}

		selection := inventorySelection{
			ProductID:        *line.ProductID,
			BarcodeID:        line.BarcodeID,
			ComboProductID:   line.ComboProductID,
			Quantity:         line.Snapshot.StockQuantity,
			SerialNumbers:    line.SerialNumbers,
			BatchAllocations: line.BatchAllocations,
			Notes:            line.Notes,
			OverridePassword: req.OverridePassword,
		}
		issue, err := trackingSvc.IssueStockTx(tx, companyID, locationID, userID, "SALE_EDIT", "sale_detail", &saleDetailID, nil, selection)
		if err != nil {
			return nil, fmt.Errorf("failed to update stock: %w", err)
		}
		actualCost := actualSaleLineCost(line, issue)
		actualCosts = append(actualCosts, actualCost)
		if _, err := tx.Exec(`
			UPDATE sale_details
			SET barcode_id = COALESCE($1, barcode_id),
			    cost_price = $2,
			    serial_numbers = $3
			WHERE sale_detail_id = $4
		`, issue.BarcodeID, actualCost.CostPricePerUnit, pq.Array(selection.SerialNumbers), saleDetailID); err != nil {
			return nil, fmt.Errorf("failed to update edited sale detail snapshot: %w", err)
		}
	}

	if !header.IsTraining {
		profitDetails := buildProfitGuardDetails(preparedLines, actualCosts, req.DiscountAmount)
		if err := s.salesService.enforceNegativeProfitPolicyTx(tx, companyID, req.OverridePassword, profitDetails); err != nil {
			return nil, err
		}
	}

	if _, err := tx.Exec(`
		UPDATE sales
		SET customer_id = $1,
		    subtotal = $2,
		    tax_amount = $3,
		    discount_amount = $4,
		    total_amount = $5,
		    paid_amount = $6,
		    payment_method_id = $7,
		    notes = COALESCE($8, notes),
		    updated_by = $9,
		    updated_at = CURRENT_TIMESTAMP
		WHERE sale_id = $10
	`, req.CustomerID, subtotal, tax, req.DiscountAmount, total, req.PaidAmount, req.PaymentMethodID, req.Notes, userID, saleID); err != nil {
		return nil, fmt.Errorf("failed to update sale header: %w", err)
	}

	if len(req.Payments) > 0 {
		if err := s.recordSalePaymentsTx(tx, saleID, req.Payments); err != nil {
			return nil, fmt.Errorf("failed to record payments: %w", err)
		}
	}

	recordID := saleID
	actorID := userID
	changes := models.JSONB{
		"edit_flow":             "in_place",
		"baseline_updated_at":   req.BaselineUpdatedAt.UTC().Format(time.RFC3339Nano),
		"previous_total_amount": header.TotalAmount,
		"updated_total_amount":  total,
		"request_id":            strings.TrimSpace(requestID),
	}
	if req.CustomerID != nil {
		changes["customer_id"] = *req.CustomerID
	}
	if err := LogAudit(tx, "UPDATE", "sales", &recordID, &actorID, nil, nil, &changes, nil, nil); err != nil {
		return nil, fmt.Errorf("failed to log sale edit audit: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit sale edit: %w", err)
	}

	if !header.IsTraining {
		if err := s.rebuildSaleLedger(companyID, saleID, userID); err != nil {
			return nil, err
		}
		cashDelta := newCashIn - oldCashIn
		if math.Abs(cashDelta) > 0.0001 {
			if err := s.recordSaleEditCashDelta(companyID, locationID, userID, saleID, header.SaleNumber, cashDelta, requestID); err != nil {
				return nil, err
			}
		}
	}

	if overrideUsed {
		tx2, err := s.db.Begin()
		if err == nil {
			recordID := saleID
			actorID := userID
			overrideChanges := models.JSONB{
				"override":             true,
				"override_type":        "discount",
				"override_approver_id": overrideApproverID,
				"manual_bill_discount": req.DiscountAmount,
			}
			_ = LogAudit(tx2, "OVERRIDE", "sales", &recordID, &actorID, nil, nil, &overrideChanges, nil, nil)
			_ = tx2.Commit()
		}
	}

	return s.salesService.GetSaleByID(saleID, companyID)
}

func (s *POSService) loadEditableSaleHeaderTx(tx *sql.Tx, companyID, saleID int) (*editableSaleHeader, error) {
	var header editableSaleHeader
	err := tx.QueryRow(`
		SELECT s.sale_number, s.location_id, s.status, s.source_channel, COALESCE(s.transaction_type, 'RETAIL'), s.refund_source_sale_id,
		       COALESCE(s.is_training, FALSE), s.customer_id, s.total_amount, s.paid_amount,
		       s.payment_method_id, s.notes, s.updated_at
		FROM sales s
		JOIN locations l ON s.location_id = l.location_id
		WHERE s.sale_id = $1 AND l.company_id = $2 AND s.is_deleted = FALSE
		FOR UPDATE
	`, saleID, companyID).Scan(
		&header.SaleNumber,
		&header.LocationID,
		&header.Status,
		&header.SourceChannel,
		&header.TransactionType,
		&header.RefundSourceSale,
		&header.IsTraining,
		&header.CustomerID,
		&header.TotalAmount,
		&header.PaidAmount,
		&header.PaymentMethodID,
		&header.Notes,
		&header.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("sale not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to load editable sale: %w", err)
	}
	return &header, nil
}

func (s *POSService) ensureSaleHasNoDependentRefundsTx(tx *sql.Tx, companyID, saleID int) error {
	var hasSaleReturns bool
	if err := tx.QueryRow(`
		SELECT EXISTS (
			SELECT 1
			FROM sale_returns sr
			JOIN sales s ON sr.sale_id = s.sale_id
			JOIN locations l ON s.location_id = l.location_id
			WHERE sr.sale_id = $1
			  AND l.company_id = $2
			  AND sr.is_deleted = FALSE
		)
	`, saleID, companyID).Scan(&hasSaleReturns); err != nil {
		return fmt.Errorf("failed to check sale returns: %w", err)
	}
	if hasSaleReturns {
		return fmt.Errorf("sales with returns or refunds cannot be edited")
	}

	var hasRefundInvoices bool
	if err := tx.QueryRow(`
		SELECT EXISTS (
			SELECT 1
			FROM sales s
			JOIN locations l ON s.location_id = l.location_id
			WHERE s.refund_source_sale_id = $1
			  AND l.company_id = $2
			  AND s.is_deleted = FALSE
		)
	`, saleID, companyID).Scan(&hasRefundInvoices); err != nil {
		return fmt.Errorf("failed to check refund invoices: %w", err)
	}
	if hasRefundInvoices {
		return fmt.Errorf("sales with returns or refunds cannot be edited")
	}
	return nil
}

func (s *POSService) loadEditableSaleLinesTx(tx *sql.Tx, companyID, saleID int) ([]editableSaleLine, error) {
	rows, err := tx.Query(`
		SELECT sd.sale_detail_id, sd.product_id, sd.combo_product_id, sd.barcode_id,
		       sd.quantity, COALESCE(sd.stock_quantity, 0)::float8, sd.serial_numbers,
		       COALESCE(sd.cost_price, 0)::float8, sd.notes
		FROM sale_details sd
		JOIN sales s ON sd.sale_id = s.sale_id
		JOIN locations l ON s.location_id = l.location_id
		WHERE sd.sale_id = $1 AND l.company_id = $2 AND s.is_deleted = FALSE
		ORDER BY sd.sale_detail_id
	`, saleID, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to load sale details: %w", err)
	}
	defer rows.Close()

	lines := make([]editableSaleLine, 0)
	for rows.Next() {
		var line editableSaleLine
		if err := rows.Scan(
			&line.SaleDetailID,
			&line.ProductID,
			&line.ComboProductID,
			&line.BarcodeID,
			&line.Quantity,
			&line.StockQuantity,
			pq.Array(&line.SerialNumbers),
			&line.CostPrice,
			&line.Notes,
		); err != nil {
			return nil, fmt.Errorf("failed to scan sale detail: %w", err)
		}
		lines = append(lines, line)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to iterate sale details: %w", err)
	}
	return lines, nil
}

func (s *POSService) restoreEditedSaleStockTx(tx *sql.Tx, companyID, locationID, userID int, lines []editableSaleLine) error {
	trackingSvc := newInventoryTrackingService(s.db)
	for _, line := range lines {
		if line.ProductID == nil || line.Quantity <= 0 {
			continue
		}
		quantity := math.Abs(line.StockQuantity)
		if quantity <= 0 {
			continue
		}
		if _, err := trackingSvc.ReceiveStockTx(tx, companyID, locationID, userID, "SALE_EDIT_REVERT", "sale_detail", &line.SaleDetailID, nil, inventorySelection{
			ProductID:      *line.ProductID,
			BarcodeID:      line.BarcodeID,
			ComboProductID: line.ComboProductID,
			Quantity:       quantity,
			SerialNumbers:  line.SerialNumbers,
			UnitCost:       line.CostPrice,
			Notes:          line.Notes,
		}); err != nil {
			return fmt.Errorf("failed to restore stock for sale detail %d: %w", line.SaleDetailID, err)
		}
	}
	return nil
}

func (s *POSService) cashInBaseFromExistingSaleTx(tx *sql.Tx, saleID int) (float64, error) {
	rows, err := tx.Query(`
		SELECT sp.base_amount, pm.type
		FROM sale_payments sp
		JOIN payment_methods pm ON sp.method_id = pm.method_id
		WHERE sp.sale_id = $1
	`, saleID)
	if err != nil {
		return 0, fmt.Errorf("failed to load sale payments: %w", err)
	}
	defer rows.Close()

	sum := 0.0
	found := false
	for rows.Next() {
		var amount float64
		var paymentType string
		if err := rows.Scan(&amount, &paymentType); err != nil {
			return 0, fmt.Errorf("failed to scan sale payment: %w", err)
		}
		found = true
		if strings.EqualFold(strings.TrimSpace(paymentType), "CASH") {
			sum += amount
		}
	}
	if err := rows.Err(); err != nil {
		return 0, fmt.Errorf("failed to iterate sale payments: %w", err)
	}
	if found {
		return sum, nil
	}

	var paidAmount float64
	var methodID sql.NullInt64
	if err := tx.QueryRow(`SELECT paid_amount, payment_method_id FROM sales WHERE sale_id = $1`, saleID).Scan(&paidAmount, &methodID); err != nil {
		return 0, fmt.Errorf("failed to load sale payment header: %w", err)
	}
	if !methodID.Valid || paidAmount <= 0 {
		return 0, nil
	}
	var paymentType string
	if err := tx.QueryRow(`SELECT type FROM payment_methods WHERE method_id = $1`, methodID.Int64).Scan(&paymentType); err != nil {
		if err == sql.ErrNoRows {
			return 0, nil
		}
		return 0, fmt.Errorf("failed to load payment method type: %w", err)
	}
	if strings.EqualFold(strings.TrimSpace(paymentType), "CASH") {
		return paidAmount, nil
	}
	return 0, nil
}

func (s *POSService) cashInBaseFromEditRequestTx(tx *sql.Tx, req *models.POSEditSaleRequest) (float64, error) {
	if req == nil {
		return 0, nil
	}
	if len(req.Payments) > 0 {
		return cashInBaseFromPaymentLinesTx(tx, req.Payments)
	}
	if req.PaymentMethodID == nil || req.PaidAmount <= 0 {
		return 0, nil
	}
	var paymentType string
	if err := tx.QueryRow(`SELECT type FROM payment_methods WHERE method_id = $1`, *req.PaymentMethodID).Scan(&paymentType); err != nil {
		if err == sql.ErrNoRows {
			return 0, nil
		}
		return 0, fmt.Errorf("failed to load payment method type: %w", err)
	}
	if strings.EqualFold(strings.TrimSpace(paymentType), "CASH") {
		return req.PaidAmount, nil
	}
	return 0, nil
}

func cashInBaseFromPaymentLinesTx(tx *sql.Tx, lines []models.POSPaymentLine) (float64, error) {
	methodIDs := make([]int, 0, len(lines))
	seen := make(map[int]struct{}, len(lines))
	for _, p := range lines {
		if p.MethodID <= 0 {
			continue
		}
		if _, ok := seen[p.MethodID]; ok {
			continue
		}
		seen[p.MethodID] = struct{}{}
		methodIDs = append(methodIDs, p.MethodID)
	}

	methodTypes := map[int]string{}
	if len(methodIDs) > 0 {
		rows, err := tx.Query(`SELECT method_id, type FROM payment_methods WHERE method_id = ANY($1)`, pq.Array(methodIDs))
		if err != nil {
			return 0, fmt.Errorf("failed to load payment method types: %w", err)
		}
		for rows.Next() {
			var id int
			var paymentType string
			if err := rows.Scan(&id, &paymentType); err == nil {
				methodTypes[id] = paymentType
			}
		}
		rows.Close()
	}

	sum := 0.0
	for _, p := range lines {
		if !strings.EqualFold(strings.TrimSpace(methodTypes[p.MethodID]), "CASH") {
			continue
		}
		rate := 1.0
		if p.CurrencyID != nil {
			err := tx.QueryRow(`
				SELECT COALESCE(pmc.exchange_rate, c.exchange_rate, 1.0)
				FROM currencies c
				LEFT JOIN payment_method_currencies pmc
				  ON pmc.currency_id = c.currency_id
				 AND pmc.method_id = $1
				WHERE c.currency_id = $2
			`, p.MethodID, *p.CurrencyID).Scan(&rate)
			if err != nil && err != sql.ErrNoRows {
				return 0, fmt.Errorf("failed to resolve exchange rate: %w", err)
			}
			if err == sql.ErrNoRows {
				rate = 1.0
			}
		}
		sum += p.Amount * rate
	}
	return sum, nil
}

func (s *POSService) rebuildSaleLedger(companyID, saleID, userID int) error {
	if _, err := s.db.Exec(`
		DELETE FROM ledger_entries
		WHERE company_id = $1
		  AND transaction_type = 'sale'
		  AND transaction_id = $2
	`, companyID, saleID); err != nil {
		return fmt.Errorf("failed to clear ledger entries for edited sale: %w", err)
	}
	if err := (&LedgerService{db: s.db}).RecordSale(companyID, saleID, userID); err != nil {
		return fmt.Errorf("failed to rebuild ledger for edited sale: %w", err)
	}
	return nil
}

func (s *POSService) recordSaleEditCashDelta(companyID, locationID, userID, saleID int, saleNumber string, delta float64, requestID string) error {
	direction := "IN"
	eventType := "SALE_EDIT"
	amount := delta
	if amount < 0 {
		direction = "OUT"
		eventType = "SALE_EDIT_REFUND"
		amount = -amount
	}
	note := fmt.Sprintf("sale_id=%d sale_number=%s", saleID, saleNumber)
	reasonCode := fmt.Sprintf("sale:%d:edit", saleID)
	return (&CashRegisterService{db: s.db}).RecordCashTransactionTx(
		nil,
		companyID,
		locationID,
		userID,
		direction,
		amount,
		eventType,
		reasonCode,
		&note,
		"",
		strings.TrimSpace(requestID),
	)
}

func timestampsMatch(a, b time.Time) bool {
	return a.UTC().Round(time.Millisecond).Equal(b.UTC().Round(time.Millisecond))
}
