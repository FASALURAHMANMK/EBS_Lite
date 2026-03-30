package services

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"strings"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

const (
	financeOutboxStatusPending    = "PENDING"
	financeOutboxStatusProcessing = "PROCESSING"
	financeOutboxStatusFailed     = "FAILED"
	financeOutboxStatusCompleted  = "COMPLETED"

	financeEventLedgerSale           = "ledger.sale.record"
	financeEventLedgerPurchase       = "ledger.purchase.record"
	financeEventLedgerCollection     = "ledger.collection.record"
	financeEventLedgerExpense        = "ledger.expense.record"
	financeEventLedgerSupplierPay    = "ledger.supplier_payment.record"
	financeEventLedgerSaleReturn     = "ledger.sale_return.record"
	financeEventLedgerPurchaseReturn = "ledger.purchase_return.record"

	financeEventCashSale        = "cash.sale.record"
	financeEventCashPurchase    = "cash.purchase.record"
	financeEventCashCollection  = "cash.collection.record"
	financeEventCashExpense     = "cash.expense.record"
	financeEventCashSupplierPay = "cash.supplier_payment.record"

	financeEventLoyaltyAward  = "loyalty.sale.award_points"
	financeEventLoyaltyRedeem = "loyalty.sale.redeem_points"
	financeEventCouponRedeem  = "promotion.sale.redeem_coupon"
	financeEventRaffleIssue   = "promotion.sale.issue_raffle"
)

type FinanceIntegrityService struct {
	db *sql.DB
}

func NewFinanceIntegrityService() *FinanceIntegrityService {
	return &FinanceIntegrityService{db: database.GetDB()}
}

func NewFinanceIntegrityServiceWithDB(db *sql.DB) *FinanceIntegrityService {
	if db == nil {
		db = database.GetDB()
	}
	return &FinanceIntegrityService{db: db}
}

func (s *FinanceIntegrityService) EnqueueTx(tx *sql.Tx, entry *models.FinanceOutboxEntry) error {
	if tx == nil {
		return fmt.Errorf("transaction is required")
	}
	if entry == nil {
		return fmt.Errorf("outbox entry is required")
	}
	if strings.TrimSpace(entry.EventType) == "" || strings.TrimSpace(entry.AggregateType) == "" || entry.AggregateID <= 0 {
		return fmt.Errorf("invalid outbox entry")
	}
	if entry.Payload == nil {
		entry.Payload = models.JSONB{}
	}

	_, err := tx.Exec(`
		INSERT INTO finance_integrity_outbox (
			company_id, location_id, event_type, aggregate_type, aggregate_id,
			payload, status, next_attempt_at, created_by
		) VALUES (
			$1, $2, $3, $4, $5,
			$6, 'PENDING', CURRENT_TIMESTAMP, $7
		)
		ON CONFLICT (event_type, aggregate_type, aggregate_id)
		DO UPDATE SET
			payload = EXCLUDED.payload,
			location_id = EXCLUDED.location_id,
			created_by = EXCLUDED.created_by,
			updated_at = CURRENT_TIMESTAMP,
			last_error = NULL,
			next_attempt_at = CURRENT_TIMESTAMP,
			status = CASE
				WHEN finance_integrity_outbox.status = 'COMPLETED' THEN finance_integrity_outbox.status
				ELSE 'PENDING'
			END
	`, entry.CompanyID, entry.LocationID, entry.EventType, entry.AggregateType, entry.AggregateID, entry.Payload, entry.CreatedBy)
	if err != nil {
		return fmt.Errorf("failed to enqueue finance outbox entry: %w", err)
	}
	return nil
}

func (s *FinanceIntegrityService) ProcessAggregate(companyID int, aggregateType string, aggregateID int) error {
	rows, err := s.db.Query(`
		SELECT outbox_id
		FROM finance_integrity_outbox
		WHERE company_id = $1
		  AND aggregate_type = $2
		  AND aggregate_id = $3
		  AND status IN ('PENDING', 'FAILED')
		ORDER BY outbox_id
	`, companyID, aggregateType, aggregateID)
	if err != nil {
		return fmt.Errorf("failed to load finance outbox entries: %w", err)
	}
	defer rows.Close()

	var ids []int
	for rows.Next() {
		var id int
		if err := rows.Scan(&id); err != nil {
			return fmt.Errorf("failed to scan finance outbox id: %w", err)
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("failed to iterate finance outbox ids: %w", err)
	}
	for _, id := range ids {
		if _, err := s.processEntry(companyID, id); err != nil {
			log.Printf("finance_integrity: aggregate replay failed company_id=%d aggregate_type=%s aggregate_id=%d outbox_id=%d err=%v", companyID, aggregateType, aggregateID, id, err)
		}
	}
	return nil
}

func (s *FinanceIntegrityService) Replay(companyID int, ids []int, limit int) (*models.FinanceReplayResult, error) {
	if limit <= 0 {
		limit = 50
	}

	targetIDs := ids
	if len(targetIDs) == 0 {
		rows, err := s.db.Query(`
			SELECT outbox_id
			FROM finance_integrity_outbox
			WHERE company_id = $1
			  AND status IN ('PENDING', 'FAILED')
			  AND next_attempt_at <= CURRENT_TIMESTAMP
			ORDER BY outbox_id
			LIMIT $2
		`, companyID, limit)
		if err != nil {
			return nil, fmt.Errorf("failed to load replay candidates: %w", err)
		}
		defer rows.Close()
		for rows.Next() {
			var id int
			if err := rows.Scan(&id); err != nil {
				return nil, fmt.Errorf("failed to scan replay candidate: %w", err)
			}
			targetIDs = append(targetIDs, id)
		}
		if err := rows.Err(); err != nil {
			return nil, fmt.Errorf("failed to iterate replay candidates: %w", err)
		}
	}

	result := &models.FinanceReplayResult{}
	for _, id := range targetIDs {
		entry, err := s.processEntry(companyID, id)
		if entry != nil {
			result.Entries = append(result.Entries, *entry)
		}
		if err != nil {
			result.ProcessedCount++
			result.FailedCount++
			continue
		}
		result.ProcessedCount++
		if strings.EqualFold(entry.Status, financeOutboxStatusCompleted) {
			result.SucceededCount++
		} else {
			result.FailedCount++
		}
	}
	return result, nil
}

func (s *FinanceIntegrityService) GetDiagnostics(companyID, limit int, status string) (*models.FinanceIntegrityDiagnostics, error) {
	if limit <= 0 {
		limit = 25
	}

	summary, err := s.loadSummary(companyID)
	if err != nil {
		return nil, err
	}
	entries, err := s.loadEntries(companyID, limit, status)
	if err != nil {
		return nil, err
	}
	missingLedger, err := s.loadMissingLedger(companyID, limit)
	if err != nil {
		return nil, err
	}

	return &models.FinanceIntegrityDiagnostics{
		Summary:              *summary,
		OutboxEntries:        entries,
		MissingLedgerEntries: missingLedger,
	}, nil
}

func (s *FinanceIntegrityService) RepairMissingLedger(companyID, userID, limit int) (*models.FinanceRepairLedgerResult, error) {
	if limit <= 0 {
		limit = 50
	}
	missing, err := s.loadMissingLedger(companyID, limit)
	if err != nil {
		return nil, err
	}
	if len(missing) == 0 {
		return &models.FinanceRepairLedgerResult{}, nil
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to begin ledger repair transaction: %w", err)
	}
	defer tx.Rollback()

	result := &models.FinanceRepairLedgerResult{}
	for _, item := range missing {
		eventType, ok := ledgerRepairEventType(item.DocumentType)
		if !ok {
			continue
		}
		entry := &models.FinanceOutboxEntry{
			CompanyID:     companyID,
			LocationID:    item.LocationID,
			EventType:     eventType,
			AggregateType: item.DocumentType,
			AggregateID:   item.DocumentID,
			Payload:       models.JSONB{},
			CreatedBy:     &userID,
		}
		if err := s.EnqueueTx(tx, entry); err != nil {
			return nil, err
		}
		result.EnqueuedCount++
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit ledger repair transaction: %w", err)
	}

	replay, err := s.Replay(companyID, nil, limit)
	if err != nil {
		return nil, err
	}
	result.ProcessedCount = replay.ProcessedCount
	result.FailedCount = replay.FailedCount
	result.Entries = replay.Entries
	return result, nil
}

func (s *FinanceIntegrityService) processEntry(companyID, outboxID int) (*models.FinanceOutboxEntry, error) {
	entry, err := s.loadEntry(companyID, outboxID)
	if err != nil {
		return nil, err
	}

	if entry.Status == financeOutboxStatusCompleted {
		return entry, nil
	}

	if _, err := s.db.Exec(`
		UPDATE finance_integrity_outbox
		SET status = 'PROCESSING',
		    attempt_count = attempt_count + 1,
		    last_attempt_at = CURRENT_TIMESTAMP,
		    updated_at = CURRENT_TIMESTAMP
		WHERE outbox_id = $1 AND company_id = $2
	`, outboxID, companyID); err != nil {
		return nil, fmt.Errorf("failed to mark finance outbox entry processing: %w", err)
	}

	if err := s.handleEntry(entry); err != nil {
		msg := err.Error()
		if _, updateErr := s.db.Exec(`
			UPDATE finance_integrity_outbox
			SET status = 'FAILED',
			    last_error = $3,
			    next_attempt_at = CURRENT_TIMESTAMP + INTERVAL '5 minutes',
			    updated_at = CURRENT_TIMESTAMP
			WHERE outbox_id = $1 AND company_id = $2
		`, outboxID, companyID, msg); updateErr != nil {
			return nil, fmt.Errorf("failed to mark finance outbox entry failed: %w", updateErr)
		}
		updatedEntry, loadErr := s.loadEntry(companyID, outboxID)
		if loadErr != nil {
			return nil, err
		}
		return updatedEntry, err
	}

	if _, err := s.db.Exec(`
		UPDATE finance_integrity_outbox
		SET status = 'COMPLETED',
		    last_error = NULL,
		    processed_at = CURRENT_TIMESTAMP,
		    next_attempt_at = CURRENT_TIMESTAMP,
		    updated_at = CURRENT_TIMESTAMP
		WHERE outbox_id = $1 AND company_id = $2
	`, outboxID, companyID); err != nil {
		return nil, fmt.Errorf("failed to mark finance outbox entry completed: %w", err)
	}

	return s.loadEntry(companyID, outboxID)
}

func (s *FinanceIntegrityService) handleEntry(entry *models.FinanceOutboxEntry) error {
	switch entry.EventType {
	case financeEventLedgerSale:
		return (&LedgerService{db: s.db}).RecordSale(entry.CompanyID, entry.AggregateID, createdByOrZero(entry.CreatedBy))
	case financeEventLedgerPurchase:
		return (&LedgerService{db: s.db}).RecordPurchase(entry.CompanyID, entry.AggregateID, createdByOrZero(entry.CreatedBy))
	case financeEventLedgerCollection:
		return (&LedgerService{db: s.db}).RecordCollection(entry.CompanyID, entry.AggregateID, createdByOrZero(entry.CreatedBy))
	case financeEventLedgerExpense:
		return (&LedgerService{db: s.db}).RecordExpense(entry.CompanyID, entry.AggregateID, createdByOrZero(entry.CreatedBy))
	case financeEventLedgerSupplierPay:
		return (&LedgerService{db: s.db}).RecordSupplierPayment(entry.CompanyID, entry.AggregateID, createdByOrZero(entry.CreatedBy))
	case financeEventLedgerSaleReturn:
		return (&LedgerService{db: s.db}).RecordSaleReturn(entry.CompanyID, entry.AggregateID, createdByOrZero(entry.CreatedBy))
	case financeEventLedgerPurchaseReturn:
		return (&LedgerService{db: s.db}).RecordPurchaseReturn(entry.CompanyID, entry.AggregateID, createdByOrZero(entry.CreatedBy))
	case financeEventCashSale, financeEventCashPurchase, financeEventCashCollection, financeEventCashExpense, financeEventCashSupplierPay:
		return s.handleCashEntry(entry)
	case financeEventLoyaltyAward:
		payload := loyaltyAwardPayload{}
		if err := decodeFinancePayload(entry.Payload, &payload); err != nil {
			return err
		}
		return NewLoyaltyService().AwardPoints(entry.CompanyID, payload.CustomerID, payload.SaleAmount, entry.AggregateID)
	case financeEventLoyaltyRedeem:
		payload := loyaltyRedeemPayload{}
		if err := decodeFinancePayload(entry.Payload, &payload); err != nil {
			return err
		}
		_, _, err := NewLoyaltyService().RedeemPointsForSale(entry.CompanyID, payload.CustomerID, entry.AggregateID, payload.RequestedPoints)
		return err
	case financeEventCouponRedeem:
		payload := couponRedeemPayload{}
		if err := decodeFinancePayload(entry.Payload, &payload); err != nil {
			return err
		}
		return NewLoyaltyService().RedeemCouponCode(entry.CompanyID, payload.Code, entry.AggregateID, payload.CustomerID)
	case financeEventRaffleIssue:
		payload := raffleIssuePayload{}
		if err := decodeFinancePayload(entry.Payload, &payload); err != nil {
			return err
		}
		_, err := NewLoyaltyService().IssueRaffleCouponsForSale(entry.CompanyID, entry.AggregateID, payload.CustomerID, payload.AutoFillCustomerData)
		return err
	default:
		return fmt.Errorf("unsupported finance outbox event type: %s", entry.EventType)
	}
}

func (s *FinanceIntegrityService) handleCashEntry(entry *models.FinanceOutboxEntry) error {
	payload := cashPostingPayload{}
	if err := decodeFinancePayload(entry.Payload, &payload); err != nil {
		return err
	}
	locationID := 0
	if entry.LocationID != nil {
		locationID = *entry.LocationID
	}
	requestID := financeRequestID(entry)
	return (&CashRegisterService{db: s.db}).RecordCashTransactionTx(
		nil,
		entry.CompanyID,
		locationID,
		createdByOrZero(entry.CreatedBy),
		payload.Direction,
		payload.Amount,
		payload.EventType,
		payload.ReasonCode,
		payload.Notes,
		"",
		requestID,
	)
}

func (s *FinanceIntegrityService) loadSummary(companyID int) (*models.FinanceIntegritySummary, error) {
	rows, err := s.db.Query(`
		SELECT status, COUNT(*)::int
		FROM finance_integrity_outbox
		WHERE company_id = $1
		GROUP BY status
	`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to load finance outbox summary: %w", err)
	}
	defer rows.Close()

	summary := &models.FinanceIntegritySummary{}
	for rows.Next() {
		var status string
		var count int
		if err := rows.Scan(&status, &count); err != nil {
			return nil, fmt.Errorf("failed to scan finance outbox summary: %w", err)
		}
		switch strings.ToUpper(status) {
		case financeOutboxStatusPending:
			summary.PendingCount = count
		case financeOutboxStatusProcessing:
			summary.ProcessingCount = count
		case financeOutboxStatusFailed:
			summary.FailedCount = count
		case financeOutboxStatusCompleted:
			summary.CompletedCount = count
		}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to iterate finance outbox summary: %w", err)
	}

	bucketRows, err := s.db.Query(`
		SELECT event_type, status, COUNT(*)::int
		FROM finance_integrity_outbox
		WHERE company_id = $1
		GROUP BY event_type, status
		ORDER BY event_type, status
	`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to load finance outbox buckets: %w", err)
	}
	defer bucketRows.Close()
	for bucketRows.Next() {
		var bucket models.FinanceIntegrityBucket
		if err := bucketRows.Scan(&bucket.EventType, &bucket.Status, &bucket.Count); err != nil {
			return nil, fmt.Errorf("failed to scan finance outbox bucket: %w", err)
		}
		summary.EventBuckets = append(summary.EventBuckets, bucket)
	}
	if err := bucketRows.Err(); err != nil {
		return nil, fmt.Errorf("failed to iterate finance outbox buckets: %w", err)
	}

	return summary, nil
}

func (s *FinanceIntegrityService) loadEntries(companyID, limit int, status string) ([]models.FinanceOutboxEntry, error) {
	args := []interface{}{companyID}
	query := `
		SELECT outbox_id, company_id, location_id, event_type, aggregate_type, aggregate_id,
		       payload, status, attempt_count, last_error, last_attempt_at, next_attempt_at,
		       processed_at, created_by, created_at, updated_at
		FROM finance_integrity_outbox
		WHERE company_id = $1
	`
	if trimmed := strings.ToUpper(strings.TrimSpace(status)); trimmed != "" {
		args = append(args, trimmed)
		query += fmt.Sprintf(" AND status = $%d", len(args))
	}
	args = append(args, limit)
	query += fmt.Sprintf(" ORDER BY created_at DESC, outbox_id DESC LIMIT $%d", len(args))

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to load finance outbox entries: %w", err)
	}
	defer rows.Close()

	entries := make([]models.FinanceOutboxEntry, 0)
	for rows.Next() {
		entry, err := scanFinanceOutboxEntry(rows)
		if err != nil {
			return nil, err
		}
		entries = append(entries, *entry)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to iterate finance outbox entries: %w", err)
	}
	return entries, nil
}

func (s *FinanceIntegrityService) loadEntry(companyID, outboxID int) (*models.FinanceOutboxEntry, error) {
	row := s.db.QueryRow(`
		SELECT outbox_id, company_id, location_id, event_type, aggregate_type, aggregate_id,
		       payload, status, attempt_count, last_error, last_attempt_at, next_attempt_at,
		       processed_at, created_by, created_at, updated_at
		FROM finance_integrity_outbox
		WHERE company_id = $1 AND outbox_id = $2
	`, companyID, outboxID)
	return scanFinanceOutboxEntry(row)
}

func (s *FinanceIntegrityService) loadMissingLedger(companyID, limit int) ([]models.FinanceLedgerMismatch, error) {
	rows, err := s.db.Query(fmt.Sprintf(`
		SELECT document_type, document_id, document_number, location_id, document_date, total_amount, diagnostic
		FROM (
			SELECT 'sale'::text AS document_type,
			       s.sale_id AS document_id,
			       s.sale_number AS document_number,
			       s.location_id,
			       s.sale_date AS document_date,
			       s.total_amount::float8 AS total_amount,
			       'Missing sale ledger posting'::text AS diagnostic
			FROM sales s
			JOIN locations l ON l.location_id = s.location_id
			WHERE l.company_id = $1
			  AND s.is_deleted = FALSE
			  AND s.status = 'COMPLETED'
			  AND COALESCE(s.is_training, FALSE) = FALSE
			  AND NOT EXISTS (
				SELECT 1 FROM ledger_entries le
				WHERE le.company_id = $1 AND le.transaction_type = 'sale' AND le.transaction_id = s.sale_id
			  )
			UNION ALL
			SELECT 'purchase'::text, p.purchase_id, p.purchase_number, p.location_id, p.purchase_date,
			       p.total_amount::float8, 'Missing purchase ledger posting'::text
			FROM purchases p
			JOIN locations l ON l.location_id = p.location_id
			WHERE l.company_id = $1
			  AND p.is_deleted = FALSE
			  AND NOT EXISTS (
				SELECT 1 FROM ledger_entries le
				WHERE le.company_id = $1 AND le.transaction_type = 'purchase' AND le.transaction_id = p.purchase_id
			  )
			UNION ALL
			SELECT 'collection'::text, c.collection_id, c.collection_number, c.location_id, c.collection_date,
			       c.amount::float8, 'Missing collection ledger posting'::text
			FROM collections c
			JOIN customers cu ON cu.customer_id = c.customer_id
			WHERE cu.company_id = $1
			  AND NOT EXISTS (
				SELECT 1 FROM ledger_entries le
				WHERE le.company_id = $1 AND le.transaction_type = 'collection' AND le.transaction_id = c.collection_id
			  )
			UNION ALL
			SELECT 'expense'::text, e.expense_id, e.expense_number, e.location_id, e.expense_date,
			       e.amount::float8, 'Missing expense ledger posting'::text
			FROM expenses e
			JOIN expense_categories ec ON ec.category_id = e.category_id
			WHERE ec.company_id = $1
			  AND e.is_deleted = FALSE
			  AND NOT EXISTS (
				SELECT 1 FROM ledger_entries le
				WHERE le.company_id = $1 AND le.transaction_type = 'expense' AND le.transaction_id = e.expense_id
			  )
			UNION ALL
			SELECT 'payment'::text, pay.payment_id, pay.payment_number, pay.location_id, pay.payment_date,
			       pay.amount::float8, 'Missing supplier payment ledger posting'::text
			FROM payments pay
			LEFT JOIN suppliers sup ON sup.supplier_id = pay.supplier_id
			WHERE (sup.company_id = $1 OR pay.supplier_id IS NULL)
			  AND COALESCE(pay.is_deleted, FALSE) = FALSE
			  AND NOT EXISTS (
				SELECT 1 FROM ledger_entries le
				WHERE le.company_id = $1 AND le.transaction_type = 'payment' AND le.transaction_id = pay.payment_id
			  )
			UNION ALL
			SELECT 'sale_return'::text, sr.return_id, sr.return_number, sr.location_id, sr.return_date,
			       sr.total_amount::float8, 'Missing sale return ledger posting'::text
			FROM sale_returns sr
			JOIN locations l ON l.location_id = sr.location_id
			WHERE l.company_id = $1
			  AND sr.is_deleted = FALSE
			  AND NOT EXISTS (
				SELECT 1 FROM ledger_entries le
				WHERE le.company_id = $1 AND le.transaction_type = 'sale_return' AND le.transaction_id = sr.return_id
			  )
			UNION ALL
			SELECT 'purchase_return'::text, pr.return_id, pr.return_number, pr.location_id, pr.return_date,
			       pr.total_amount::float8, 'Missing purchase return ledger posting'::text
			FROM purchase_returns pr
			JOIN purchases p ON p.purchase_id = pr.purchase_id
			JOIN suppliers sup ON sup.supplier_id = p.supplier_id
			WHERE sup.company_id = $1
			  AND pr.is_deleted = FALSE
			  AND NOT EXISTS (
				SELECT 1 FROM ledger_entries le
				WHERE le.company_id = $1 AND le.transaction_type = 'purchase_return' AND le.transaction_id = pr.return_id
			  )
		) missing
		ORDER BY document_date DESC NULLS LAST, document_id DESC
		LIMIT %d
	`, limit), companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to load missing ledger diagnostics: %w", err)
	}
	defer rows.Close()

	items := make([]models.FinanceLedgerMismatch, 0)
	for rows.Next() {
		var item models.FinanceLedgerMismatch
		var locationID sql.NullInt64
		var documentDate sql.NullTime
		if err := rows.Scan(
			&item.DocumentType,
			&item.DocumentID,
			&item.DocumentNumber,
			&locationID,
			&documentDate,
			&item.TotalAmount,
			&item.Diagnostic,
		); err != nil {
			return nil, fmt.Errorf("failed to scan missing ledger diagnostic: %w", err)
		}
		if locationID.Valid {
			v := int(locationID.Int64)
			item.LocationID = &v
		}
		if documentDate.Valid {
			v := documentDate.Time
			item.DocumentDate = &v
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to iterate missing ledger diagnostics: %w", err)
	}
	return items, nil
}

type financeOutboxScanner interface {
	Scan(dest ...interface{}) error
}

func scanFinanceOutboxEntry(scanner financeOutboxScanner) (*models.FinanceOutboxEntry, error) {
	entry := &models.FinanceOutboxEntry{}
	var locationID sql.NullInt64
	var lastError sql.NullString
	var lastAttemptAt sql.NullTime
	var processedAt sql.NullTime
	var createdBy sql.NullInt64
	if err := scanner.Scan(
		&entry.OutboxID,
		&entry.CompanyID,
		&locationID,
		&entry.EventType,
		&entry.AggregateType,
		&entry.AggregateID,
		&entry.Payload,
		&entry.Status,
		&entry.AttemptCount,
		&lastError,
		&lastAttemptAt,
		&entry.NextAttemptAt,
		&processedAt,
		&createdBy,
		&entry.CreatedAt,
		&entry.UpdatedAt,
	); err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("finance outbox entry not found")
		}
		return nil, fmt.Errorf("failed to scan finance outbox entry: %w", err)
	}
	if locationID.Valid {
		v := int(locationID.Int64)
		entry.LocationID = &v
	}
	if lastError.Valid {
		entry.LastError = &lastError.String
	}
	if lastAttemptAt.Valid {
		v := lastAttemptAt.Time
		entry.LastAttemptAt = &v
	}
	if processedAt.Valid {
		v := processedAt.Time
		entry.ProcessedAt = &v
	}
	if createdBy.Valid {
		v := int(createdBy.Int64)
		entry.CreatedBy = &v
	}
	return entry, nil
}

func financeRequestID(entry *models.FinanceOutboxEntry) string {
	return fmt.Sprintf("finance:%s:%s:%d", entry.EventType, entry.AggregateType, entry.AggregateID)
}

func createdByOrZero(userID *int) int {
	if userID == nil {
		return 0
	}
	return *userID
}

func ledgerRepairEventType(documentType string) (string, bool) {
	switch documentType {
	case "sale":
		return financeEventLedgerSale, true
	case "purchase":
		return financeEventLedgerPurchase, true
	case "collection":
		return financeEventLedgerCollection, true
	case "expense":
		return financeEventLedgerExpense, true
	case "payment":
		return financeEventLedgerSupplierPay, true
	case "sale_return":
		return financeEventLedgerSaleReturn, true
	case "purchase_return":
		return financeEventLedgerPurchaseReturn, true
	default:
		return "", false
	}
}

type cashPostingPayload struct {
	Amount     float64 `json:"amount"`
	Direction  string  `json:"direction"`
	EventType  string  `json:"event_type"`
	ReasonCode string  `json:"reason_code"`
	Notes      *string `json:"notes,omitempty"`
}

type loyaltyAwardPayload struct {
	CustomerID int     `json:"customer_id"`
	SaleAmount float64 `json:"sale_amount"`
}

type loyaltyRedeemPayload struct {
	CustomerID      int     `json:"customer_id"`
	RequestedPoints float64 `json:"requested_points"`
}

type couponRedeemPayload struct {
	Code       string `json:"code"`
	CustomerID *int   `json:"customer_id,omitempty"`
}

type raffleIssuePayload struct {
	CustomerID           *int  `json:"customer_id,omitempty"`
	AutoFillCustomerData *bool `json:"auto_fill_customer_data,omitempty"`
}

func decodeFinancePayload(payload models.JSONB, target interface{}) error {
	raw, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to encode finance outbox payload: %w", err)
	}
	if err := json.Unmarshal(raw, target); err != nil {
		return fmt.Errorf("failed to decode finance outbox payload: %w", err)
	}
	return nil
}
