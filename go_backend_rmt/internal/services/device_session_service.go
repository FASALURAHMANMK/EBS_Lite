package services

import (
	"database/sql"
	"fmt"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type DeviceSessionService struct {
	db *sql.DB
}

func NewDeviceSessionService() *DeviceSessionService {
	return &DeviceSessionService{
		db: database.GetDB(),
	}
}

func (s *DeviceSessionService) GetActiveSessions(userID, companyID int) ([]models.DeviceSession, error) {
	query := `
        SELECT ds.session_id, ds.user_id, ds.device_id, ds.device_name, ds.ip_address,
               ds.user_agent, ds.last_seen, ds.last_sync_time, ds.is_active, ds.is_stale,
               ds.created_at
        FROM device_sessions ds
        JOIN users u ON ds.user_id = u.user_id
        WHERE ds.user_id = $1 AND u.company_id = $2 AND ds.is_active = TRUE
        ORDER BY ds.created_at DESC`

	rows, err := s.db.Query(query, userID, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to query device sessions: %w", err)
	}
	defer rows.Close()

	sessions := []models.DeviceSession{}
	for rows.Next() {
		var session models.DeviceSession
		err := rows.Scan(
			&session.SessionID, &session.UserID, &session.DeviceID, &session.DeviceName,
			&session.IPAddress, &session.UserAgent, &session.LastSeen, &session.LastSyncTime,
			&session.IsActive, &session.IsStale, &session.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan device session: %w", err)
		}
		sessions = append(sessions, session)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to iterate device sessions: %w", err)
	}

	return sessions, nil
}

func (s *DeviceSessionService) RevokeSession(sessionID string, userID, companyID int) error {
	query := `
        UPDATE device_sessions ds
        SET is_active = FALSE
        WHERE ds.session_id = $1 AND ds.user_id = $2
        AND EXISTS (SELECT 1 FROM users u WHERE u.user_id = ds.user_id AND u.company_id = $3)`

	res, err := s.db.Exec(query, sessionID, userID, companyID)
	if err != nil {
		return fmt.Errorf("failed to revoke session: %w", err)
	}

	rowsAffected, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return sql.ErrNoRows
	}

	return nil
}
