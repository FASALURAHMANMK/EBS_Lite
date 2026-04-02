package models

import "time"

type SupportIssue struct {
	IssueID          int        `json:"issue_id" db:"issue_id"`
	IssueNumber      string     `json:"issue_number" db:"issue_number"`
	CompanyID        int        `json:"company_id" db:"company_id"`
	LocationID       *int       `json:"location_id,omitempty" db:"location_id"`
	ReportedByUserID int        `json:"reported_by_user_id" db:"reported_by_user_id"`
	ReportedByName   *string    `json:"reported_by_name,omitempty"`
	Title            string     `json:"title" db:"title"`
	Severity         string     `json:"severity" db:"severity"`
	Details          string     `json:"details" db:"details"`
	Status           string     `json:"status" db:"status"`
	AppVersion       string     `json:"app_version" db:"app_version"`
	BuildNumber      string     `json:"build_number" db:"build_number"`
	ReleaseChannel   string     `json:"release_channel" db:"release_channel"`
	Platform         string     `json:"platform" db:"platform"`
	PlatformVersion  string     `json:"platform_version" db:"platform_version"`
	BackendReachable bool       `json:"backend_reachable" db:"backend_reachable"`
	QueuedSyncItems  int        `json:"queued_sync_items" db:"queued_sync_items"`
	LastSyncAt       *time.Time `json:"last_sync_at,omitempty" db:"last_sync_at"`
	CreatedAt        time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at" db:"updated_at"`
}

type CreateSupportIssueRequest struct {
	Title            string  `json:"title" validate:"required,min=3,max=160"`
	Severity         string  `json:"severity" validate:"required,oneof=LOW NORMAL HIGH CRITICAL"`
	Details          string  `json:"details" validate:"required,min=10,max=4000"`
	AppVersion       string  `json:"app_version,omitempty" validate:"max=64"`
	BuildNumber      string  `json:"build_number,omitempty" validate:"max=64"`
	ReleaseChannel   string  `json:"release_channel,omitempty" validate:"max=64"`
	Platform         string  `json:"platform,omitempty" validate:"max=64"`
	PlatformVersion  string  `json:"platform_version,omitempty" validate:"max=255"`
	BackendReachable bool    `json:"backend_reachable"`
	QueuedSyncItems  int     `json:"queued_sync_items" validate:"gte=0"`
	LastSyncAt       *string `json:"last_sync_at,omitempty"`
}

type SupportIssueListFilters struct {
	Status   string
	Severity string
	Limit    int
}
