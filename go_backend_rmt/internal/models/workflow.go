package models

import "time"

type WorkflowRequestEvent struct {
	EventID    int       `json:"event_id" db:"event_id"`
	ApprovalID int       `json:"approval_id" db:"approval_id"`
	EventType  string    `json:"event_type" db:"event_type"`
	ActorID    *int      `json:"actor_id,omitempty" db:"actor_id"`
	ActorName  *string   `json:"actor_name,omitempty"`
	FromStatus *string   `json:"from_status,omitempty" db:"from_status"`
	ToStatus   *string   `json:"to_status,omitempty" db:"to_status"`
	Remarks    *string   `json:"remarks,omitempty" db:"remarks"`
	Payload    *JSONB    `json:"payload,omitempty" db:"payload"`
	CreatedAt  time.Time `json:"created_at" db:"created_at"`
}

// WorkflowRequest represents an actionable operational approval or supervisory review.
type WorkflowRequest struct {
	ApprovalID       int                    `json:"approval_id" db:"approval_id"`
	CompanyID        int                    `json:"company_id" db:"company_id"`
	LocationID       *int                   `json:"location_id,omitempty" db:"location_id"`
	Module           string                 `json:"module" db:"module"`
	EntityType       string                 `json:"entity_type" db:"entity_type"`
	EntityID         *int                   `json:"entity_id,omitempty" db:"entity_id"`
	ActionType       string                 `json:"action_type" db:"action_type"`
	Title            string                 `json:"title" db:"title"`
	Summary          *string                `json:"summary,omitempty" db:"summary"`
	RequestReason    *string                `json:"request_reason,omitempty" db:"request_reason"`
	Status           string                 `json:"status" db:"status"`
	Priority         string                 `json:"priority" db:"priority"`
	ApproverRoleID   int                    `json:"approver_role_id" db:"approver_role_id"`
	ApproverRoleName *string                `json:"approver_role_name,omitempty"`
	Payload          JSONB                  `json:"payload,omitempty" db:"payload"`
	ResultSnapshot   JSONB                  `json:"result_snapshot,omitempty" db:"result_snapshot"`
	DueAt            *time.Time             `json:"due_at,omitempty" db:"due_at"`
	IsOverdue        bool                   `json:"is_overdue"`
	EscalationLevel  int                    `json:"escalation_level" db:"escalation_level"`
	CreatedBy        int                    `json:"created_by" db:"created_by"`
	CreatedByName    *string                `json:"created_by_name,omitempty"`
	UpdatedBy        *int                   `json:"updated_by,omitempty" db:"updated_by"`
	ApprovedBy       *int                   `json:"approved_by,omitempty" db:"approved_by"`
	ApprovedByName   *string                `json:"approved_by_name,omitempty"`
	ApprovedAt       *time.Time             `json:"approved_at,omitempty" db:"approved_at"`
	DecisionReason   *string                `json:"decision_reason,omitempty" db:"decision_reason"`
	CreatedAt        time.Time              `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time              `json:"updated_at" db:"updated_at"`
	Events           []WorkflowRequestEvent `json:"events,omitempty"`
}

// CreateWorkflowRequest supports explicit workflow submission from shipped flows.
type CreateWorkflowRequest struct {
	LocationID     *int    `json:"location_id,omitempty"`
	Module         string  `json:"module" validate:"required"`
	EntityType     string  `json:"entity_type" validate:"required"`
	EntityID       *int    `json:"entity_id,omitempty"`
	ActionType     string  `json:"action_type" validate:"required"`
	Title          string  `json:"title" validate:"required"`
	Summary        *string `json:"summary,omitempty"`
	RequestReason  *string `json:"request_reason,omitempty"`
	Priority       string  `json:"priority,omitempty"`
	ApproverRoleID int     `json:"approver_role_id" validate:"required"`
	DueAt          *string `json:"due_at,omitempty"`
	Payload        JSONB   `json:"payload,omitempty"`
	ResultSnapshot JSONB   `json:"result_snapshot,omitempty"`
}

// DecisionRequest contains optional remarks when approving or rejecting.
type DecisionRequest struct {
	Remarks *string `json:"remarks,omitempty"`
}
