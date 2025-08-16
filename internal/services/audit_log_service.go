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

// LogAudit inserts an entry into the audit_log table within the provided transaction.
// It captures the action performed, the table affected, and optionally the record ID,
// acting user, and JSON representations of values or field changes along with client
// metadata such as IP address and user agent. The operation runs inside the given
// transaction to ensure atomicity with the calling service's changes.
func LogAudit(tx *sql.Tx, action, table string, recordID, userID *int,
	oldValue, newValue, fieldChanges *models.JSONB, ip, ua *string) error {
	if tx == nil {
		return fmt.Errorf("transaction is nil")
	}

	query := `INSERT INTO audit_log
                (user_id, action, table_name, record_id, old_value, new_value,
                 field_changes, ip_address, user_agent)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`

	if _, err := tx.Exec(query, userID, action, table, recordID, oldValue, newValue, fieldChanges, ip, ua); err != nil {
		return fmt.Errorf("failed to insert audit log: %w", err)
	}
	return nil
}
