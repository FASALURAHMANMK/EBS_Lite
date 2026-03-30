package services

import (
	"regexp"
	"testing"
	"time"

	sqlmock "github.com/DATA-DOG/go-sqlmock"
)

func TestNotificationsService_ListNotifications_ReadStateApplied(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	svc := &NotificationsService{db: db}

	const (
		companyID = 1
		userID    = 2
		location  = 1
	)

	lowStockKey := "low_stock:loc:1:product:2"
	workflowKey := "workflow_request:10"

	mock.ExpectQuery(regexp.QuoteMeta("SELECT notification_key FROM notification_reads WHERE company_id=$1 AND user_id=$2")).
		WithArgs(companyID, userID).
		WillReturnRows(sqlmock.NewRows([]string{"notification_key"}).
			AddRow(lowStockKey).
			AddRow(workflowKey))

	mock.ExpectQuery(regexp.QuoteMeta("SELECT COALESCE(role_id, 0) FROM users WHERE user_id = $1")).
		WithArgs(userID).
		WillReturnRows(sqlmock.NewRows([]string{"role_id"}).AddRow(3))

	updated := time.Date(2026, 3, 2, 10, 0, 0, 0, time.UTC)
	mock.ExpectQuery("(?s)FROM stock st.*WHERE l\\.company_id = \\$1.*st\\.location_id = \\$2.*LIMIT 50").
		WithArgs(companyID, location).
		WillReturnRows(sqlmock.NewRows([]string{
			"location_id",
			"location_name",
			"product_id",
			"product_name",
			"barcode",
			"quantity",
			"reorder_level",
			"last_updated",
		}).AddRow(1, "Main", 2, "Item A", "ABC123", 3.0, 5, updated))

	dueAt := updated.Add(-2 * time.Hour)
	mock.ExpectQuery("(?s)FROM workflow_requests.*WHERE company_id = \\$1.*approver_role_id = \\$2.*status = 'PENDING'.*LIMIT 50").
		WithArgs(companyID, 3).
		WillReturnRows(sqlmock.NewRows([]string{
			"approval_id",
			"entity_type",
			"entity_id",
			"title",
			"summary",
			"priority",
			"due_at",
			"created_at",
		}).AddRow(10, "PURCHASE_ORDER", 44, "Approve purchase order PO-0001", "Supplier ACME", "HIGH", dueAt, updated))

	items, err := svc.ListNotifications(companyID, userID, func() *int { v := location; return &v }())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(items) != 2 {
		t.Fatalf("expected 2 notifications, got %d", len(items))
	}

	seen := map[string]bool{}
	for _, it := range items {
		seen[it.Key] = it.IsRead
	}
	if seen[lowStockKey] != true {
		t.Fatalf("expected low stock notification to be read")
	}
	if seen[workflowKey] != true {
		t.Fatalf("expected workflow notification to be read")
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}

func TestNotificationsService_MarkRead_InsertsKeys(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	svc := &NotificationsService{db: db}

	mock.ExpectBegin()
	mock.ExpectPrepare(regexp.QuoteMeta(`
        INSERT INTO notification_reads (company_id, user_id, notification_key, read_at)
        VALUES ($1,$2,$3,CURRENT_TIMESTAMP)
        ON CONFLICT (company_id, user_id, notification_key) DO NOTHING
    `))
	mock.ExpectExec(regexp.QuoteMeta(`
        INSERT INTO notification_reads (company_id, user_id, notification_key, read_at)
        VALUES ($1,$2,$3,CURRENT_TIMESTAMP)
        ON CONFLICT (company_id, user_id, notification_key) DO NOTHING
    `)).
		WithArgs(1, 2, "workflow_request:10").
		WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectExec(regexp.QuoteMeta(`
        INSERT INTO notification_reads (company_id, user_id, notification_key, read_at)
        VALUES ($1,$2,$3,CURRENT_TIMESTAMP)
        ON CONFLICT (company_id, user_id, notification_key) DO NOTHING
    `)).
		WithArgs(1, 2, "low_stock:loc:1:product:2").
		WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectCommit()

	if err := svc.MarkRead(1, 2, []string{" workflow_request:10 ", "", "low_stock:loc:1:product:2"}); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}
