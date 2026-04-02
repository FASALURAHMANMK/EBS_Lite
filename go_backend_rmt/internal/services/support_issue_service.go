package services

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type SupportIssueService struct {
	db *sql.DB
}

func NewSupportIssueService() *SupportIssueService {
	return &SupportIssueService{db: database.GetDB()}
}

func (s *SupportIssueService) CreateIssue(companyID, userID int, locationID *int, req *models.CreateSupportIssueRequest) (*models.SupportIssue, error) {
	if companyID == 0 || userID == 0 {
		return nil, fmt.Errorf("company and user access required")
	}
	if req == nil {
		return nil, fmt.Errorf("request is required")
	}

	lastSyncAt, err := parseOptionalRFC3339(req.LastSyncAt)
	if err != nil {
		return nil, err
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	var issueID int
	err = tx.QueryRow(`
        INSERT INTO support_issues (
            company_id,
            location_id,
            reported_by_user_id,
            title,
            severity,
            details,
            status,
            app_version,
            build_number,
            release_channel,
            platform,
            platform_version,
            backend_reachable,
            queued_sync_items,
            last_sync_at
        ) VALUES (
            $1,$2,$3,$4,$5,$6,'OPEN',$7,$8,$9,$10,$11,$12,$13,$14
        )
        RETURNING issue_id
    `,
		companyID,
		locationID,
		userID,
		strings.TrimSpace(req.Title),
		strings.ToUpper(strings.TrimSpace(req.Severity)),
		strings.TrimSpace(req.Details),
		strings.TrimSpace(req.AppVersion),
		strings.TrimSpace(req.BuildNumber),
		strings.TrimSpace(req.ReleaseChannel),
		strings.TrimSpace(req.Platform),
		strings.TrimSpace(req.PlatformVersion),
		req.BackendReachable,
		req.QueuedSyncItems,
		lastSyncAt,
	).Scan(&issueID)
	if err != nil {
		return nil, fmt.Errorf("failed to create support issue: %w", err)
	}

	issueNumber := fmt.Sprintf("SUP-%06d", issueID)
	if _, err := tx.Exec(`UPDATE support_issues SET issue_number = $1 WHERE issue_id = $2`, issueNumber, issueID); err != nil {
		return nil, fmt.Errorf("failed to assign issue number: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit support issue: %w", err)
	}

	return s.GetIssueByID(companyID, issueID)
}

func (s *SupportIssueService) ListIssues(companyID int, filters models.SupportIssueListFilters) ([]models.SupportIssue, error) {
	if companyID == 0 {
		return nil, fmt.Errorf("company access required")
	}

	limit := filters.Limit
	if limit <= 0 || limit > 200 {
		limit = 50
	}

	query := `
        SELECT
            si.issue_id,
            COALESCE(si.issue_number, ''),
            si.company_id,
            si.location_id,
            si.reported_by_user_id,
            NULLIF(COALESCE(u.username, ''), ''),
            si.title,
            si.severity,
            si.details,
            si.status,
            COALESCE(si.app_version, ''),
            COALESCE(si.build_number, ''),
            COALESCE(si.release_channel, ''),
            COALESCE(si.platform, ''),
            COALESCE(si.platform_version, ''),
            si.backend_reachable,
            si.queued_sync_items,
            si.last_sync_at,
            si.created_at,
            si.updated_at
        FROM support_issues si
        LEFT JOIN users u ON u.user_id = si.reported_by_user_id
        WHERE si.company_id = $1
    `

	args := []interface{}{companyID}
	argPos := 2

	if status := strings.ToUpper(strings.TrimSpace(filters.Status)); status != "" {
		query += fmt.Sprintf(" AND si.status = $%d", argPos)
		args = append(args, status)
		argPos++
	}
	if severity := strings.ToUpper(strings.TrimSpace(filters.Severity)); severity != "" {
		query += fmt.Sprintf(" AND si.severity = $%d", argPos)
		args = append(args, severity)
		argPos++
	}

	query += fmt.Sprintf(" ORDER BY si.created_at DESC LIMIT $%d", argPos)
	args = append(args, limit)

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to list support issues: %w", err)
	}
	defer rows.Close()

	var issues []models.SupportIssue
	for rows.Next() {
		issue, err := scanSupportIssue(rows)
		if err != nil {
			return nil, err
		}
		issues = append(issues, *issue)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to iterate support issues: %w", err)
	}

	return issues, nil
}

func (s *SupportIssueService) GetIssueByID(companyID, issueID int) (*models.SupportIssue, error) {
	if companyID == 0 {
		return nil, fmt.Errorf("company access required")
	}

	row := s.db.QueryRow(`
        SELECT
            si.issue_id,
            COALESCE(si.issue_number, ''),
            si.company_id,
            si.location_id,
            si.reported_by_user_id,
            NULLIF(COALESCE(u.username, ''), ''),
            si.title,
            si.severity,
            si.details,
            si.status,
            COALESCE(si.app_version, ''),
            COALESCE(si.build_number, ''),
            COALESCE(si.release_channel, ''),
            COALESCE(si.platform, ''),
            COALESCE(si.platform_version, ''),
            si.backend_reachable,
            si.queued_sync_items,
            si.last_sync_at,
            si.created_at,
            si.updated_at
        FROM support_issues si
        LEFT JOIN users u ON u.user_id = si.reported_by_user_id
        WHERE si.company_id = $1 AND si.issue_id = $2
    `, companyID, issueID)

	issue, err := scanSupportIssue(row)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("support issue not found")
		}
		return nil, err
	}
	return issue, nil
}

type supportIssueScanner interface {
	Scan(dest ...interface{}) error
}

func scanSupportIssue(scanner supportIssueScanner) (*models.SupportIssue, error) {
	var issue models.SupportIssue
	var locationID sql.NullInt64
	var reportedByName sql.NullString
	var lastSyncAt sql.NullTime

	err := scanner.Scan(
		&issue.IssueID,
		&issue.IssueNumber,
		&issue.CompanyID,
		&locationID,
		&issue.ReportedByUserID,
		&reportedByName,
		&issue.Title,
		&issue.Severity,
		&issue.Details,
		&issue.Status,
		&issue.AppVersion,
		&issue.BuildNumber,
		&issue.ReleaseChannel,
		&issue.Platform,
		&issue.PlatformVersion,
		&issue.BackendReachable,
		&issue.QueuedSyncItems,
		&lastSyncAt,
		&issue.CreatedAt,
		&issue.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to scan support issue: %w", err)
	}

	if locationID.Valid {
		value := int(locationID.Int64)
		issue.LocationID = &value
	}
	if reportedByName.Valid {
		value := reportedByName.String
		issue.ReportedByName = &value
	}
	if lastSyncAt.Valid {
		value := lastSyncAt.Time
		issue.LastSyncAt = &value
	}

	return &issue, nil
}

func parseOptionalRFC3339(value *string) (*time.Time, error) {
	if value == nil {
		return nil, nil
	}
	trimmed := strings.TrimSpace(*value)
	if trimmed == "" {
		return nil, nil
	}

	layouts := []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02T15:04:05.999999999",
		"2006-01-02T15:04:05.999999",
		"2006-01-02T15:04:05.999",
		"2006-01-02T15:04:05",
		"2006-01-02 15:04:05.999999999",
		"2006-01-02 15:04:05",
	}
	for _, layout := range layouts {
		if parsed, err := time.Parse(layout, trimmed); err == nil {
			return &parsed, nil
		}
	}
	return nil, fmt.Errorf("last_sync_at must be an ISO timestamp")
}
