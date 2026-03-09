package services

import (
	"regexp"
	"testing"
	"time"

	sqlmock "github.com/DATA-DOG/go-sqlmock"
)

func TestDashboardService_GetRecentCashFlowTransactions(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	svc := &DashboardService{db: db}

	const (
		companyID  = 1
		locationID = 2
	)

	occurredAt := time.Date(2026, 3, 9, 10, 30, 0, 0, time.UTC)
	mock.ExpectQuery(regexp.QuoteMeta("SELECT id, transaction_type, entity_name, reference_number, amount, flow_direction, status, occurred_at")).
		WithArgs(companyID, locationID).
		WillReturnRows(sqlmock.NewRows([]string{
			"id",
			"transaction_type",
			"entity_name",
			"reference_number",
			"amount",
			"flow_direction",
			"status",
			"occurred_at",
		}).AddRow(
			"sale-10",
			"SALE",
			"Acme Corp",
			"INV-00010",
			5000.00,
			"IN",
			"COMPLETED",
			occurredAt,
		))

	items, err := svc.GetRecentCashFlowTransactions(companyID, func() *int {
		v := locationID
		return &v
	}(), 10)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("expected 1 transaction, got %d", len(items))
	}
	if items[0].TransactionType != "SALE" || items[0].EntityName != "Acme Corp" {
		t.Fatalf("unexpected transaction payload: %#v", items[0])
	}
	if items[0].FlowDirection != "IN" {
		t.Fatalf("expected flow direction IN, got %s", items[0].FlowDirection)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}

func TestDashboardService_GetLowStockItems(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	svc := &DashboardService{db: db}

	const companyID = 1
	mock.ExpectQuery(regexp.QuoteMeta("SELECT st.product_id,")).
		WithArgs(companyID).
		WillReturnRows(sqlmock.NewRows([]string{
			"product_id",
			"product_name",
			"location_name",
			"current_stock",
			"reorder_level",
			"severity",
		}).AddRow(5, "Item A", "Main", 3.0, 10, "CRITICAL"))

	items, err := svc.GetLowStockItems(companyID, nil, 8)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("expected 1 item, got %d", len(items))
	}
	if items[0].Severity != "CRITICAL" {
		t.Fatalf("expected CRITICAL severity, got %s", items[0].Severity)
	}
	if items[0].ProductName != "Item A" {
		t.Fatalf("unexpected product payload: %#v", items[0])
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}
