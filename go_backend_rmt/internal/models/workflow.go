package models

import "time"

// WorkflowRequest represents a workflow approval request
// It corresponds to the workflow_approvals table.
type WorkflowRequest struct {
	ApprovalID     int        `json:"approval_id" db:"approval_id"`
	StateID        int        `json:"state_id" db:"state_id"`
	ApproverRoleID int        `json:"approver_role_id" db:"approver_role_id"`
	Status         string     `json:"status" db:"status"`
	Remarks        *string    `json:"remarks,omitempty" db:"remarks"`
	ApprovedAt     *time.Time `json:"approved_at,omitempty" db:"approved_at"`
	CreatedBy      int        `json:"created_by" db:"created_by"`
	UpdatedBy      *int       `json:"updated_by,omitempty" db:"updated_by"`
}

// CreateWorkflowRequest is used to submit a new workflow approval request
type CreateWorkflowRequest struct {
	StateID        int `json:"state_id" validate:"required"`
	ApproverRoleID int `json:"approver_role_id" validate:"required"`
}

// DecisionRequest contains optional remarks when approving or rejecting
type DecisionRequest struct {
	Remarks *string `json:"remarks,omitempty"`
}
