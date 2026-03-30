package services

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

const (
	workflowStatusPending  = "PENDING"
	workflowStatusApproved = "APPROVED"
	workflowStatusRejected = "REJECTED"

	workflowPriorityNormal = "NORMAL"
	workflowPriorityHigh   = "HIGH"

	workflowModulePurchases = "PURCHASES"
	workflowModuleSettings  = "SETTINGS"
	workflowModuleSuppliers = "SUPPLIERS"
	workflowModuleReturns   = "RETURNS"

	workflowEntityPurchaseOrder    = "PURCHASE_ORDER"
	workflowEntityInventorySetting = "INVENTORY_SETTINGS"
	workflowEntitySupplier         = "SUPPLIER"
	workflowEntityPurchaseReturn   = "PURCHASE_RETURN"

	workflowActionApprovePurchaseOrder = "APPROVE_PURCHASE_ORDER"
	workflowActionUpdateInventory      = "UPDATE_INVENTORY_SETTINGS"
	workflowActionReviewSupplier       = "REVIEW_SUPPLIER_CHANGE"
	workflowActionReviewPurchaseReturn = "REVIEW_PURCHASE_RETURN"
)

type WorkflowService struct {
	db *sql.DB
}

type workflowCreateInput struct {
	LocationID     *int
	Module         string
	EntityType     string
	EntityID       *int
	ActionType     string
	Title          string
	Summary        *string
	RequestReason  *string
	Priority       string
	ApproverRoleID int
	Payload        models.JSONB
	ResultSnapshot models.JSONB
	DueAt          *time.Time
}

func NewWorkflowService() *WorkflowService {
	return &WorkflowService{db: database.GetDB()}
}

func normalizeWorkflowPriority(value string) string {
	switch strings.ToUpper(strings.TrimSpace(value)) {
	case workflowPriorityHigh:
		return workflowPriorityHigh
	default:
		return workflowPriorityNormal
	}
}

func workflowTrimStringPtr(value *string) *string {
	if value == nil {
		return nil
	}
	trimmed := strings.TrimSpace(*value)
	if trimmed == "" {
		return nil
	}
	return &trimmed
}

func overdueWorkflowLevel(dueAt *time.Time, now time.Time) (bool, int) {
	if dueAt == nil || dueAt.IsZero() {
		return false, 0
	}
	if !dueAt.Before(now) {
		return false, 0
	}
	overdueBy := now.Sub(*dueAt)
	switch {
	case overdueBy >= 72*time.Hour:
		return true, 3
	case overdueBy >= 24*time.Hour:
		return true, 2
	default:
		return true, 1
	}
}

func (s *WorkflowService) getUserRoleID(userID int) (int, error) {
	var roleID int
	if err := s.db.QueryRow(`SELECT COALESCE(role_id, 0) FROM users WHERE user_id = $1`, userID).Scan(&roleID); err != nil {
		if err == sql.ErrNoRows {
			return 0, fmt.Errorf("user not found")
		}
		return 0, fmt.Errorf("failed to get user role: %w", err)
	}
	return roleID, nil
}

func (s *WorkflowService) findApproverRoleTx(tx *sql.Tx, preferredNames ...string) (int, error) {
	for _, name := range preferredNames {
		var roleID int
		err := tx.QueryRow(`SELECT role_id FROM roles WHERE LOWER(name) = LOWER($1) LIMIT 1`, name).Scan(&roleID)
		if err == nil {
			return roleID, nil
		}
		if err != sql.ErrNoRows {
			return 0, fmt.Errorf("failed to resolve approver role: %w", err)
		}
	}
	return 0, fmt.Errorf("approver role not configured")
}

func (s *WorkflowService) loadRequestAccessQuery() string {
	return `
		SELECT wr.approval_id,
		       wr.company_id,
		       wr.location_id,
		       wr.module,
		       wr.entity_type,
		       wr.entity_id,
		       wr.action_type,
		       wr.title,
		       wr.summary,
		       wr.request_reason,
		       wr.status,
		       wr.priority,
		       wr.approver_role_id,
		       r.name AS approver_role_name,
		       COALESCE(wr.payload, '{}'::jsonb),
		       COALESCE(wr.result_snapshot, '{}'::jsonb),
		       wr.due_at,
		       wr.escalation_level,
		       wr.created_by,
		       COALESCE(TRIM(CONCAT(COALESCE(cu.first_name, ''), ' ', COALESCE(cu.last_name, ''))), cu.username, cu.email, '') AS created_by_name,
		       wr.updated_by,
		       wr.approved_by,
		       COALESCE(TRIM(CONCAT(COALESCE(au.first_name, ''), ' ', COALESCE(au.last_name, ''))), au.username, au.email, '') AS approved_by_name,
		       wr.approved_at,
		       wr.decision_reason,
		       wr.created_at,
		       wr.updated_at
		FROM workflow_requests wr
		LEFT JOIN roles r ON wr.approver_role_id = r.role_id
		LEFT JOIN users cu ON wr.created_by = cu.user_id
		LEFT JOIN users au ON wr.approved_by = au.user_id
	`
}

func (s *WorkflowService) scanWorkflowRequest(scanner interface {
	Scan(dest ...interface{}) error
}) (*models.WorkflowRequest, error) {
	var req models.WorkflowRequest
	var createdByName string
	var approvedByName sql.NullString
	if err := scanner.Scan(
		&req.ApprovalID,
		&req.CompanyID,
		&req.LocationID,
		&req.Module,
		&req.EntityType,
		&req.EntityID,
		&req.ActionType,
		&req.Title,
		&req.Summary,
		&req.RequestReason,
		&req.Status,
		&req.Priority,
		&req.ApproverRoleID,
		&req.ApproverRoleName,
		&req.Payload,
		&req.ResultSnapshot,
		&req.DueAt,
		&req.EscalationLevel,
		&req.CreatedBy,
		&createdByName,
		&req.UpdatedBy,
		&req.ApprovedBy,
		&approvedByName,
		&req.ApprovedAt,
		&req.DecisionReason,
		&req.CreatedAt,
		&req.UpdatedAt,
	); err != nil {
		return nil, err
	}

	if strings.TrimSpace(createdByName) != "" {
		req.CreatedByName = &createdByName
	}
	if approvedByName.Valid && strings.TrimSpace(approvedByName.String) != "" {
		value := approvedByName.String
		req.ApprovedByName = &value
	}
	req.IsOverdue, req.EscalationLevel = overdueWorkflowLevel(req.DueAt, time.Now())
	return &req, nil
}

func (s *WorkflowService) listEvents(approvalID int) ([]models.WorkflowRequestEvent, error) {
	rows, err := s.db.Query(`
		SELECT e.event_id,
		       e.approval_id,
		       e.event_type,
		       e.actor_id,
		       COALESCE(TRIM(CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, ''))), u.username, u.email, '') AS actor_name,
		       e.from_status,
		       e.to_status,
		       e.remarks,
		       e.payload,
		       e.created_at
		FROM workflow_request_events e
		LEFT JOIN users u ON e.actor_id = u.user_id
		WHERE e.approval_id = $1
		ORDER BY e.created_at ASC, e.event_id ASC
	`, approvalID)
	if err != nil {
		return nil, fmt.Errorf("failed to load workflow events: %w", err)
	}
	defer rows.Close()

	events := make([]models.WorkflowRequestEvent, 0)
	for rows.Next() {
		var event models.WorkflowRequestEvent
		var actorName sql.NullString
		if err := rows.Scan(
			&event.EventID,
			&event.ApprovalID,
			&event.EventType,
			&event.ActorID,
			&actorName,
			&event.FromStatus,
			&event.ToStatus,
			&event.Remarks,
			&event.Payload,
			&event.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan workflow event: %w", err)
		}
		if actorName.Valid && strings.TrimSpace(actorName.String) != "" {
			value := actorName.String
			event.ActorName = &value
		}
		events = append(events, event)
	}
	return events, nil
}

func (s *WorkflowService) createEventTx(tx *sql.Tx, approvalID int, eventType string, actorID *int, fromStatus, toStatus, remarks *string, payload models.JSONB) error {
	_, err := tx.Exec(`
		INSERT INTO workflow_request_events (approval_id, event_type, actor_id, from_status, to_status, remarks, payload)
		VALUES ($1, $2, $3, $4, $5, $6, NULLIF($7, '{}'::jsonb))
	`, approvalID, eventType, actorID, fromStatus, toStatus, remarks, models.JSONB(payload))
	if err != nil {
		return fmt.Errorf("failed to record workflow event: %w", err)
	}
	return nil
}

func (s *WorkflowService) createRequestTx(tx *sql.Tx, companyID, userID int, input workflowCreateInput) (*models.WorkflowRequest, error) {
	if strings.TrimSpace(input.Title) == "" {
		return nil, fmt.Errorf("workflow title is required")
	}
	if strings.TrimSpace(input.Module) == "" || strings.TrimSpace(input.EntityType) == "" || strings.TrimSpace(input.ActionType) == "" {
		return nil, fmt.Errorf("workflow module, entity type, and action type are required")
	}
	if input.ApproverRoleID == 0 {
		return nil, fmt.Errorf("approver role is required")
	}

	var approvalID int
	var createdAt time.Time
	err := tx.QueryRow(`
		INSERT INTO workflow_requests (
			company_id, location_id, module, entity_type, entity_id, action_type, title, summary,
			request_reason, status, priority, approver_role_id, payload, result_snapshot, due_at,
			escalation_level, created_by, updated_by
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NULLIF($13, '{}'::jsonb), NULLIF($14, '{}'::jsonb), $15, $16, $17, $17)
		RETURNING approval_id, created_at
	`,
		companyID,
		input.LocationID,
		strings.ToUpper(strings.TrimSpace(input.Module)),
		strings.ToUpper(strings.TrimSpace(input.EntityType)),
		input.EntityID,
		strings.ToUpper(strings.TrimSpace(input.ActionType)),
		strings.TrimSpace(input.Title),
		workflowTrimStringPtr(input.Summary),
		workflowTrimStringPtr(input.RequestReason),
		workflowStatusPending,
		normalizeWorkflowPriority(input.Priority),
		input.ApproverRoleID,
		models.JSONB(input.Payload),
		models.JSONB(input.ResultSnapshot),
		input.DueAt,
		0,
		userID,
	).Scan(&approvalID, &createdAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create workflow request: %w", err)
	}

	if err := s.createEventTx(tx, approvalID, "CREATED", &userID, nil, strPtr(workflowStatusPending), input.RequestReason, input.Payload); err != nil {
		return nil, err
	}

	req := &models.WorkflowRequest{
		ApprovalID:      approvalID,
		CompanyID:       companyID,
		LocationID:      input.LocationID,
		Module:          strings.ToUpper(strings.TrimSpace(input.Module)),
		EntityType:      strings.ToUpper(strings.TrimSpace(input.EntityType)),
		EntityID:        input.EntityID,
		ActionType:      strings.ToUpper(strings.TrimSpace(input.ActionType)),
		Title:           strings.TrimSpace(input.Title),
		Summary:         workflowTrimStringPtr(input.Summary),
		RequestReason:   workflowTrimStringPtr(input.RequestReason),
		Status:          workflowStatusPending,
		Priority:        normalizeWorkflowPriority(input.Priority),
		ApproverRoleID:  input.ApproverRoleID,
		Payload:         input.Payload,
		ResultSnapshot:  input.ResultSnapshot,
		DueAt:           input.DueAt,
		CreatedBy:       userID,
		UpdatedBy:       &userID,
		CreatedAt:       createdAt,
		UpdatedAt:       createdAt,
		IsOverdue:       false,
		EscalationLevel: 0,
	}
	return req, nil
}

func strPtr(value string) *string {
	v := value
	return &v
}

func (s *WorkflowService) CreateRequest(companyID, userID int, req *models.CreateWorkflowRequest) (*models.WorkflowRequest, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to begin workflow transaction: %w", err)
	}
	defer tx.Rollback()

	var dueAt *time.Time
	if req.DueAt != nil && strings.TrimSpace(*req.DueAt) != "" {
		parsed, err := time.Parse(time.RFC3339, strings.TrimSpace(*req.DueAt))
		if err != nil {
			return nil, fmt.Errorf("invalid due_at: %w", err)
		}
		dueAt = &parsed
	}

	created, err := s.createRequestTx(tx, companyID, userID, workflowCreateInput{
		LocationID:     req.LocationID,
		Module:         req.Module,
		EntityType:     req.EntityType,
		EntityID:       req.EntityID,
		ActionType:     req.ActionType,
		Title:          req.Title,
		Summary:        req.Summary,
		RequestReason:  req.RequestReason,
		Priority:       req.Priority,
		ApproverRoleID: req.ApproverRoleID,
		Payload:        req.Payload,
		ResultSnapshot: req.ResultSnapshot,
		DueAt:          dueAt,
	})
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit workflow request: %w", err)
	}

	return created, nil
}

func (s *WorkflowService) ListRequests(companyID, userID int, status string) ([]models.WorkflowRequest, error) {
	roleID, err := s.getUserRoleID(userID)
	if err != nil {
		return nil, err
	}

	query := s.loadRequestAccessQuery() + `
		WHERE wr.company_id = $1
		  AND (wr.created_by = $2 OR wr.approver_role_id = $3)
	`
	args := []interface{}{companyID, userID, roleID}
	if trimmed := strings.ToUpper(strings.TrimSpace(status)); trimmed != "" {
		query += ` AND wr.status = $4`
		args = append(args, trimmed)
	} else {
		query += ` AND wr.status = 'PENDING'`
	}
	query += ` ORDER BY COALESCE(wr.due_at, wr.created_at) ASC, wr.created_at DESC`

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to list workflow requests: %w", err)
	}
	defer rows.Close()

	requests := make([]models.WorkflowRequest, 0)
	for rows.Next() {
		req, err := s.scanWorkflowRequest(rows)
		if err != nil {
			return nil, fmt.Errorf("failed to scan workflow request: %w", err)
		}
		requests = append(requests, *req)
	}
	return requests, nil
}

func (s *WorkflowService) GetRequestByID(companyID, userID, approvalID int) (*models.WorkflowRequest, error) {
	roleID, err := s.getUserRoleID(userID)
	if err != nil {
		return nil, err
	}

	row := s.db.QueryRow(
		s.loadRequestAccessQuery()+`
		WHERE wr.company_id = $1
		  AND wr.approval_id = $2
		  AND (wr.created_by = $3 OR wr.approver_role_id = $4)
	`,
		companyID,
		approvalID,
		userID,
		roleID,
	)

	req, err := s.scanWorkflowRequest(row)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("workflow request not found")
		}
		return nil, fmt.Errorf("failed to load workflow request: %w", err)
	}
	events, err := s.listEvents(approvalID)
	if err != nil {
		return nil, err
	}
	req.Events = events
	return req, nil
}

func (s *WorkflowService) lockRequestTx(tx *sql.Tx, companyID, approvalID int) (*models.WorkflowRequest, error) {
	row := tx.QueryRow(
		s.loadRequestAccessQuery()+`
		WHERE wr.company_id = $1
		  AND wr.approval_id = $2
		FOR UPDATE
	`,
		companyID,
		approvalID,
	)
	req, err := s.scanWorkflowRequest(row)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("workflow request not found")
		}
		return nil, fmt.Errorf("failed to lock workflow request: %w", err)
	}
	return req, nil
}

func (s *WorkflowService) applyApprovedActionTx(tx *sql.Tx, req *models.WorkflowRequest, userID int) (models.JSONB, error) {
	switch req.ActionType {
	case workflowActionApprovePurchaseOrder:
		if req.EntityID == nil || *req.EntityID == 0 {
			return nil, fmt.Errorf("purchase order workflow is missing entity_id")
		}
		result, err := tx.Exec(`
			UPDATE purchases p
			SET status = 'APPROVED', updated_by = $1, updated_at = CURRENT_TIMESTAMP
			FROM suppliers s
			WHERE p.purchase_id = $2
			  AND p.supplier_id = s.supplier_id
			  AND s.company_id = $3
			  AND p.is_deleted = FALSE
		`, userID, *req.EntityID, req.CompanyID)
		if err != nil {
			return nil, fmt.Errorf("failed to approve purchase order: %w", err)
		}
		rows, err := result.RowsAffected()
		if err != nil {
			return nil, fmt.Errorf("failed to inspect purchase approval result: %w", err)
		}
		if rows == 0 {
			return nil, fmt.Errorf("purchase order not found")
		}
		return models.JSONB{
			"entity_type": "purchase_order",
			"entity_id":   *req.EntityID,
			"status":      "APPROVED",
			"applied":     true,
		}, nil
	case workflowActionUpdateInventory:
		if err := (&SettingsService{db: s.db}).applyInventorySettingsTx(tx, req.CompanyID, decodeInventorySettingsPayload(req.Payload)); err != nil {
			return nil, err
		}
		return models.JSONB{
			"entity_type": "inventory_settings",
			"applied":     true,
		}, nil
	default:
		return models.JSONB{
			"reviewed": true,
		}, nil
	}
}

func decodeInventorySettingsPayload(payload models.JSONB) models.UpdateInventorySettingsRequest {
	var req models.UpdateInventorySettingsRequest
	if value, ok := payload["negative_stock_policy"].(string); ok {
		req.NegativeStockPolicy = value
	}
	if value, ok := payload["negative_profit_policy"].(string); ok {
		req.NegativeProfitPolicy = value
	}
	if value, ok := payload["negative_stock_approval_password"].(string); ok && strings.TrimSpace(value) != "" {
		req.NegativeStockApprovalPassword = &value
	}
	return req
}

func (s *WorkflowService) ensureApproverRole(userID int, approverRoleID int) error {
	roleID, err := s.getUserRoleID(userID)
	if err != nil {
		return err
	}
	if roleID != approverRoleID {
		return fmt.Errorf("workflow request is assigned to a different approver role")
	}
	return nil
}

func (s *WorkflowService) decideRequest(companyID, approvalID, userID int, remarks *string, approve bool) error {
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin workflow decision transaction: %w", err)
	}
	defer tx.Rollback()

	req, err := s.lockRequestTx(tx, companyID, approvalID)
	if err != nil {
		return err
	}
	if err := s.ensureApproverRole(userID, req.ApproverRoleID); err != nil {
		return err
	}
	if req.Status != workflowStatusPending {
		return fmt.Errorf("workflow request is already %s", strings.ToLower(req.Status))
	}

	now := time.Now()
	_, escalationLevel := overdueWorkflowLevel(req.DueAt, now)
	newStatus := workflowStatusRejected
	resultSnapshot := req.ResultSnapshot
	if approve {
		newStatus = workflowStatusApproved
		resultSnapshot, err = s.applyApprovedActionTx(tx, req, userID)
		if err != nil {
			return err
		}
	}

	_, err = tx.Exec(`
		UPDATE workflow_requests
		SET status = $1,
		    escalation_level = $2,
		    result_snapshot = NULLIF($3, '{}'::jsonb),
		    updated_by = $4,
		    updated_at = $5,
		    approved_by = $4,
		    approved_at = $5,
		    decision_reason = $6
		WHERE approval_id = $7
		  AND company_id = $8
	`, newStatus, escalationLevel, models.JSONB(resultSnapshot), userID, now, workflowTrimStringPtr(remarks), approvalID, companyID)
	if err != nil {
		return fmt.Errorf("failed to update workflow request: %w", err)
	}

	if err := s.createEventTx(tx, approvalID, newStatus, &userID, strPtr(req.Status), strPtr(newStatus), workflowTrimStringPtr(remarks), resultSnapshot); err != nil {
		return err
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit workflow decision: %w", err)
	}
	return nil
}

func (s *WorkflowService) ApproveRequest(companyID, approvalID, userID int, remarks *string) error {
	return s.decideRequest(companyID, approvalID, userID, remarks, true)
}

func (s *WorkflowService) RejectRequest(companyID, approvalID, userID int, remarks *string) error {
	return s.decideRequest(companyID, approvalID, userID, remarks, false)
}

func (s *WorkflowService) CreatePurchaseApprovalRequestTx(tx *sql.Tx, companyID, locationID, userID, purchaseID int, purchaseNumber string, supplierName string, totalAmount float64) (*models.WorkflowRequest, error) {
	approverRoleID, err := s.findApproverRoleTx(tx, "Purchase Manager", "Manager", "Admin", "Super Admin")
	if err != nil {
		return nil, err
	}

	title := fmt.Sprintf("Approve purchase order %s", strings.TrimSpace(purchaseNumber))
	summary := fmt.Sprintf("Supplier %s • total %.2f", strings.TrimSpace(supplierName), totalAmount)
	dueAt := time.Now().Add(24 * time.Hour)
	return s.createRequestTx(tx, companyID, userID, workflowCreateInput{
		LocationID:     &locationID,
		Module:         workflowModulePurchases,
		EntityType:     workflowEntityPurchaseOrder,
		EntityID:       &purchaseID,
		ActionType:     workflowActionApprovePurchaseOrder,
		Title:          title,
		Summary:        &summary,
		RequestReason:  nil,
		Priority:       workflowPriorityHigh,
		ApproverRoleID: approverRoleID,
		Payload: models.JSONB{
			"purchase_id":     purchaseID,
			"purchase_number": purchaseNumber,
			"supplier_name":   supplierName,
			"total_amount":    totalAmount,
		},
		DueAt: &dueAt,
	})
}

func (s *WorkflowService) CreateInventorySettingsApproval(companyID, userID int, req models.UpdateInventorySettingsRequest) (*models.WorkflowRequest, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to begin settings workflow transaction: %w", err)
	}
	defer tx.Rollback()

	approverRoleID, err := s.findApproverRoleTx(tx, "Super Admin", "Admin", "Manager")
	if err != nil {
		return nil, err
	}

	dueAt := time.Now().Add(4 * time.Hour)
	title := "Approve inventory control changes"
	summary := fmt.Sprintf("Negative stock: %s • Negative profit: %s", req.NegativeStockPolicy, req.NegativeProfitPolicy)
	payload := models.JSONB{
		"negative_stock_policy":  strings.ToUpper(strings.TrimSpace(req.NegativeStockPolicy)),
		"negative_profit_policy": strings.ToUpper(strings.TrimSpace(req.NegativeProfitPolicy)),
	}
	if req.NegativeStockApprovalPassword != nil && strings.TrimSpace(*req.NegativeStockApprovalPassword) != "" {
		payload["negative_stock_approval_password"] = strings.TrimSpace(*req.NegativeStockApprovalPassword)
	}

	created, err := s.createRequestTx(tx, companyID, userID, workflowCreateInput{
		Module:         workflowModuleSettings,
		EntityType:     workflowEntityInventorySetting,
		ActionType:     workflowActionUpdateInventory,
		Title:          title,
		Summary:        &summary,
		Priority:       workflowPriorityHigh,
		ApproverRoleID: approverRoleID,
		Payload:        payload,
		DueAt:          &dueAt,
	})
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit settings workflow request: %w", err)
	}
	return created, nil
}

func (s *WorkflowService) CreateSupplierReviewRequest(companyID, userID, supplierID int, supplierName string, requestReason *string) (*models.WorkflowRequest, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to begin supplier workflow transaction: %w", err)
	}
	defer tx.Rollback()

	approverRoleID, err := s.findApproverRoleTx(tx, "Admin", "Manager", "Super Admin")
	if err != nil {
		return nil, err
	}

	dueAt := time.Now().Add(24 * time.Hour)
	title := fmt.Sprintf("Review supplier master-data change for %s", strings.TrimSpace(supplierName))
	summary := fmt.Sprintf("Supplier #%d master data was created or updated.", supplierID)
	created, err := s.createRequestTx(tx, companyID, userID, workflowCreateInput{
		Module:         workflowModuleSuppliers,
		EntityType:     workflowEntitySupplier,
		EntityID:       &supplierID,
		ActionType:     workflowActionReviewSupplier,
		Title:          title,
		Summary:        &summary,
		RequestReason:  requestReason,
		Priority:       workflowPriorityNormal,
		ApproverRoleID: approverRoleID,
		Payload: models.JSONB{
			"supplier_id":   supplierID,
			"supplier_name": supplierName,
		},
		DueAt: &dueAt,
	})
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit supplier workflow request: %w", err)
	}
	return created, nil
}

func (s *WorkflowService) CreateReviewRequestTx(tx *sql.Tx, companyID, userID int, input workflowCreateInput) (*models.WorkflowRequest, error) {
	return s.createRequestTx(tx, companyID, userID, input)
}

func (s *WorkflowService) ApproveByEntity(companyID, userID int, entityType string, entityID int, remarks *string) error {
	row := s.db.QueryRow(`
		SELECT approval_id
		FROM workflow_requests
		WHERE company_id = $1
		  AND entity_type = $2
		  AND entity_id = $3
		  AND status = 'PENDING'
		ORDER BY created_at DESC
		LIMIT 1
	`, companyID, strings.ToUpper(strings.TrimSpace(entityType)), entityID)
	var approvalID int
	if err := row.Scan(&approvalID); err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("workflow request not found")
		}
		return fmt.Errorf("failed to locate workflow request: %w", err)
	}
	return s.ApproveRequest(companyID, approvalID, userID, remarks)
}
