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
	workflowKey := "workflow_approval:10"

	mock.ExpectQuery(regexp.QuoteMeta("SELECT notification_key FROM notification_reads WHERE company_id=$1 AND user_id=$2")).
		WithArgs(companyID, userID).
		WillReturnRows(sqlmock.NewRows([]string{"notification_key"}).
			AddRow(lowStockKey).
			AddRow(workflowKey))

	updated := time.Date(2026, 3, 2, 10, 0, 0, 0, time.UTC)
	mock.ExpectQuery("(?s)FROM stock st.*WHERE l\\.company_id = \\$1.*st\\.location_id = \\$2.*LIMIT 50").
		WithArgs(companyID, location).
		WillReturnRows(sqlmock.NewRows([]string{
			"location_id",
			"location_name",
			"product_id",
			"product_name",
			"quantity",
			"reorder_level",
			"last_updated",
		}).AddRow(1, "Main", 2, "Item A", 3.0, 5, updated))

	mock.ExpectQuery("(?s)FROM workflow_approvals wa.*WHERE wa\\.status = 'PENDING'.*u\\.company_id = \\$1.*LIMIT 50").
		WithArgs(companyID).
		WillReturnRows(sqlmock.NewRows([]string{
			"approval_id",
			"state_id",
			"state_name",
			"approver_role_id",
			"created_by",
		}).AddRow(10, 7, "Review", 3, 99))

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
