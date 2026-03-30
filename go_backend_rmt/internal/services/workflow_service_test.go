package services

import (
	"regexp"
	"strings"
	"testing"
	"time"

	sqlmock "github.com/DATA-DOG/go-sqlmock"
)

func workflowRequestRows(now time.Time) *sqlmock.Rows {
	return sqlmock.NewRows([]string{
		"approval_id",
		"company_id",
		"location_id",
		"module",
		"entity_type",
		"entity_id",
		"action_type",
		"title",
		"summary",
		"request_reason",
		"status",
		"priority",
		"approver_role_id",
		"approver_role_name",
		"payload",
		"result_snapshot",
		"due_at",
		"escalation_level",
		"created_by",
		"created_by_name",
		"updated_by",
		"approved_by",
		"approved_by_name",
		"approved_at",
		"decision_reason",
		"created_at",
		"updated_at",
	}).AddRow(
		11,
		1,
		2,
		"PURCHASES",
		"PURCHASE_ORDER",
		12,
		"APPROVE_PURCHASE_ORDER",
		"Approve purchase order PO-0001",
		"Supplier ACME • total 100.00",
		nil,
		"PENDING",
		"HIGH",
		7,
		"Purchase Manager",
		`{"purchase_id":12}`,
		`{}`,
		now.Add(2*time.Hour),
		0,
		5,
		"Requester",
		5,
		nil,
		nil,
		nil,
		nil,
		now,
		now,
	)
}

func TestWorkflowService_ApproveRequest_TransitionsPendingPurchase(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	svc := &WorkflowService{db: db}
	now := time.Date(2026, 3, 30, 10, 0, 0, 0, time.UTC)

	mock.ExpectBegin()
	mock.ExpectQuery("(?s)FROM workflow_requests wr.*WHERE wr\\.company_id = \\$1.*wr\\.approval_id = \\$2.*FOR UPDATE").
		WithArgs(1, 11).
		WillReturnRows(workflowRequestRows(now))
	mock.ExpectQuery(regexp.QuoteMeta("SELECT COALESCE(role_id, 0) FROM users WHERE user_id = $1")).
		WithArgs(22).
		WillReturnRows(sqlmock.NewRows([]string{"role_id"}).AddRow(7))
	mock.ExpectExec("(?s)UPDATE purchases p.*SET status = 'APPROVED'.*WHERE p\\.purchase_id = \\$2.*").
		WithArgs(22, 12, 1).
		WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectExec("(?s)UPDATE workflow_requests.*SET status = \\$1,.*approved_by = \\$4.*WHERE approval_id = \\$7.*company_id = \\$8").
		WithArgs(
			"APPROVED",
			sqlmock.AnyArg(),
			sqlmock.AnyArg(),
			22,
			sqlmock.AnyArg(),
			"approved after review",
			11,
			1,
		).
		WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectExec("(?s)INSERT INTO workflow_request_events .*VALUES \\(\\$1, \\$2, \\$3, \\$4, \\$5, \\$6, NULLIF\\(\\$7, '\\{\\}'::jsonb\\)\\)").
		WithArgs(
			11,
			"APPROVED",
			22,
			"PENDING",
			"APPROVED",
			"approved after review",
			sqlmock.AnyArg(),
		).
		WillReturnResult(sqlmock.NewResult(1, 1))
	mock.ExpectCommit()

	remarks := "approved after review"
	if err := svc.ApproveRequest(1, 11, 22, &remarks); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}

func TestWorkflowService_ApproveRequest_RejectsWrongApproverRole(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("failed to create sqlmock: %v", err)
	}
	defer db.Close()

	svc := &WorkflowService{db: db}
	now := time.Date(2026, 3, 30, 10, 0, 0, 0, time.UTC)

	mock.ExpectBegin()
	mock.ExpectQuery("(?s)FROM workflow_requests wr.*WHERE wr\\.company_id = \\$1.*wr\\.approval_id = \\$2.*FOR UPDATE").
		WithArgs(1, 11).
		WillReturnRows(workflowRequestRows(now))
	mock.ExpectQuery(regexp.QuoteMeta("SELECT COALESCE(role_id, 0) FROM users WHERE user_id = $1")).
		WithArgs(22).
		WillReturnRows(sqlmock.NewRows([]string{"role_id"}).AddRow(3))
	mock.ExpectRollback()

	err = svc.ApproveRequest(1, 11, 22, nil)
	if err == nil {
		t.Fatalf("expected permission error")
	}
	if !strings.Contains(err.Error(), "different approver role") {
		t.Fatalf("expected approver role error, got %v", err)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}
