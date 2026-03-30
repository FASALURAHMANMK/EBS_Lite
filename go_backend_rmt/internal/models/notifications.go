package models

import "time"

type NotificationItem struct {
	Key         string     `json:"key"`
	Type        string     `json:"type"`
	Title       string     `json:"title"`
	Body        string     `json:"body"`
	Status      string     `json:"status"`
	Severity    string     `json:"severity"`
	CreatedAt   time.Time  `json:"created_at"`
	IsRead      bool       `json:"is_read"`
	IsOverdue   bool       `json:"is_overdue"`
	ApprovalID  *int       `json:"approval_id,omitempty"`
	EntityType  *string    `json:"entity_type,omitempty"`
	EntityID    *int       `json:"entity_id,omitempty"`
	LocationID  *int       `json:"location_id,omitempty"`
	ProductID   *int       `json:"product_id,omitempty"`
	ActionLabel *string    `json:"action_label,omitempty"`
	BadgeLabel  *string    `json:"badge_label,omitempty"`
	DueAt       *time.Time `json:"due_at,omitempty"`
}

type MarkNotificationsReadRequest struct {
	Keys []string `json:"keys" validate:"required,min=1"`
}
