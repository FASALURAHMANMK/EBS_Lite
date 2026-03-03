package models

import "time"

type NotificationItem struct {
	Key       string    `json:"key"`
	Type      string    `json:"type"`
	Title     string    `json:"title"`
	Body      string    `json:"body"`
	CreatedAt time.Time `json:"created_at"`
	IsRead    bool      `json:"is_read"`
}

type MarkNotificationsReadRequest struct {
	Keys []string `json:"keys" validate:"required,min=1"`
}
