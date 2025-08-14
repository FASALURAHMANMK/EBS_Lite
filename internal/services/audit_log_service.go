package services

import (
	"database/sql"
	"fmt"
	"strings"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

// AuditLogService provides methods to query audit logs
type AuditLogService struct {
	db *sql.DB
}

func NewAuditLogService() *AuditLogService {
	return &AuditLogService{db: database.GetDB()}
}

// GetAuditLogs retrieves logs based on provided filters
func (s *AuditLogService) GetAuditLogs(filters map[string]string) ([]models.AuditLog, error) {
	query := `SELECT log_id, user_id, action, table_name, record_id, old_value, new_value, field_changes, ip_address, user_agent, timestamp FROM audit_log`
	args := []interface{}{}
	conditions := []string{}
	argCount := 1

	if v, ok := filters["user_id"]; ok && v != "" {
		conditions = append(conditions, fmt.Sprintf("user_id = $%d", argCount))
		args = append(args, v)
		argCount++
	}
	if v, ok := filters["action"]; ok && v != "" {
		conditions = append(conditions, fmt.Sprintf("action = $%d", argCount))
		args = append(args, v)
		argCount++
	}
	if v, ok := filters["from_date"]; ok && v != "" {
		conditions = append(conditions, fmt.Sprintf("timestamp >= $%d", argCount))
		args = append(args, v)
		argCount++
	}
	if v, ok := filters["to_date"]; ok && v != "" {
		conditions = append(conditions, fmt.Sprintf("timestamp <= $%d", argCount))
		args = append(args, v)
		argCount++
	}
	if len(conditions) > 0 {
		query += " WHERE " + strings.Join(conditions, " AND ")
	}
	query += " ORDER BY timestamp DESC"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get audit logs: %w", err)
	}
	defer rows.Close()

	var logs []models.AuditLog
	for rows.Next() {
		var log models.AuditLog
		if err := rows.Scan(&log.LogID, &log.UserID, &log.Action, &log.TableName, &log.RecordID, &log.OldValue, &log.NewValue, &log.FieldChanges, &log.IPAddress, &log.UserAgent, &log.Timestamp); err != nil {
			return nil, fmt.Errorf("failed to scan audit log: %w", err)
		}
		logs = append(logs, log)
	}
	return logs, nil
}
