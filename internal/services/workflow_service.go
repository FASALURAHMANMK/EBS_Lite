package services

import (
	"database/sql"
	"fmt"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

// WorkflowService manages workflow approval requests
type WorkflowService struct {
	db *sql.DB
}

func NewWorkflowService() *WorkflowService {
	return &WorkflowService{db: database.GetDB()}
}

// GetPendingRequests retrieves all workflow approvals with status PENDING
func (s *WorkflowService) GetPendingRequests() ([]models.WorkflowRequest, error) {
	rows, err := s.db.Query(`SELECT approval_id, state_id, approver_role_id, status, remarks, approved_at FROM workflow_approvals WHERE status = 'PENDING'`)
	if err != nil {
		return nil, fmt.Errorf("failed to get workflow requests: %w", err)
	}
	defer rows.Close()

	var requests []models.WorkflowRequest
	for rows.Next() {
		var r models.WorkflowRequest
		if err := rows.Scan(&r.ApprovalID, &r.StateID, &r.ApproverRoleID, &r.Status, &r.Remarks, &r.ApprovedAt); err != nil {
			return nil, fmt.Errorf("failed to scan workflow request: %w", err)
		}
		requests = append(requests, r)
	}
	return requests, nil
}

// CreateRequest inserts a new workflow approval request
func (s *WorkflowService) CreateRequest(req *models.CreateWorkflowRequest) (*models.WorkflowRequest, error) {
	var id int
	err := s.db.QueryRow(`INSERT INTO workflow_approvals (state_id, approver_role_id, status) VALUES ($1, $2, 'PENDING') RETURNING approval_id`, req.StateID, req.ApproverRoleID).Scan(&id)
	if err != nil {
		return nil, fmt.Errorf("failed to create workflow request: %w", err)
	}

	return &models.WorkflowRequest{
		ApprovalID:     id,
		StateID:        req.StateID,
		ApproverRoleID: req.ApproverRoleID,
		Status:         "PENDING",
	}, nil
}

// ApproveRequest marks a workflow request as approved
func (s *WorkflowService) ApproveRequest(id int, remarks *string) error {
	_, err := s.db.Exec(`UPDATE workflow_approvals SET status = 'APPROVED', remarks = $1, approved_at = NOW() WHERE approval_id = $2`, remarks, id)
	if err != nil {
		return fmt.Errorf("failed to approve workflow request: %w", err)
	}
	return nil
}

// RejectRequest marks a workflow request as rejected
func (s *WorkflowService) RejectRequest(id int, remarks *string) error {
	_, err := s.db.Exec(`UPDATE workflow_approvals SET status = 'REJECTED', remarks = $1, approved_at = NOW() WHERE approval_id = $2`, remarks, id)
	if err != nil {
		return fmt.Errorf("failed to reject workflow request: %w", err)
	}
	return nil
}
