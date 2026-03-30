package models

import "time"

type FinanceOutboxEntry struct {
	OutboxID      int        `json:"outbox_id" db:"outbox_id"`
	CompanyID     int        `json:"company_id" db:"company_id"`
	LocationID    *int       `json:"location_id,omitempty" db:"location_id"`
	EventType     string     `json:"event_type" db:"event_type"`
	AggregateType string     `json:"aggregate_type" db:"aggregate_type"`
	AggregateID   int        `json:"aggregate_id" db:"aggregate_id"`
	Payload       JSONB      `json:"payload" db:"payload"`
	Status        string     `json:"status" db:"status"`
	AttemptCount  int        `json:"attempt_count" db:"attempt_count"`
	LastError     *string    `json:"last_error,omitempty" db:"last_error"`
	LastAttemptAt *time.Time `json:"last_attempt_at,omitempty" db:"last_attempt_at"`
	NextAttemptAt time.Time  `json:"next_attempt_at" db:"next_attempt_at"`
	ProcessedAt   *time.Time `json:"processed_at,omitempty" db:"processed_at"`
	CreatedBy     *int       `json:"created_by,omitempty" db:"created_by"`
	CreatedAt     time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at" db:"updated_at"`
}

type FinanceIntegritySummary struct {
	PendingCount    int                      `json:"pending_count"`
	ProcessingCount int                      `json:"processing_count"`
	FailedCount     int                      `json:"failed_count"`
	CompletedCount  int                      `json:"completed_count"`
	EventBuckets    []FinanceIntegrityBucket `json:"event_buckets"`
}

type FinanceIntegrityBucket struct {
	EventType string `json:"event_type"`
	Status    string `json:"status"`
	Count     int    `json:"count"`
}

type FinanceLedgerMismatch struct {
	DocumentType   string     `json:"document_type"`
	DocumentID     int        `json:"document_id"`
	DocumentNumber string     `json:"document_number"`
	LocationID     *int       `json:"location_id,omitempty"`
	DocumentDate   *time.Time `json:"document_date,omitempty"`
	TotalAmount    float64    `json:"total_amount"`
	Diagnostic     string     `json:"diagnostic"`
}

type FinanceIntegrityDiagnostics struct {
	Summary              FinanceIntegritySummary `json:"summary"`
	OutboxEntries        []FinanceOutboxEntry    `json:"outbox_entries"`
	MissingLedgerEntries []FinanceLedgerMismatch `json:"missing_ledger_entries"`
}

type FinanceReplayRequest struct {
	OutboxIDs []int `json:"outbox_ids,omitempty"`
	Limit     *int  `json:"limit,omitempty"`
}

type FinanceReplayResult struct {
	ProcessedCount int                  `json:"processed_count"`
	SucceededCount int                  `json:"succeeded_count"`
	FailedCount    int                  `json:"failed_count"`
	Entries        []FinanceOutboxEntry `json:"entries,omitempty"`
}

type FinanceRepairLedgerRequest struct {
	Limit *int `json:"limit,omitempty"`
}

type FinanceRepairLedgerResult struct {
	EnqueuedCount  int                  `json:"enqueued_count"`
	ProcessedCount int                  `json:"processed_count"`
	FailedCount    int                  `json:"failed_count"`
	Entries        []FinanceOutboxEntry `json:"entries,omitempty"`
}
