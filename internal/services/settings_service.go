package services

import (
	"database/sql"
	"fmt"

	"erp-backend/internal/database"
)

// SettingsService provides methods to manage system settings
// It works with the settings table
// Settings are stored as key-value pairs per company

type SettingsService struct {
	db *sql.DB
}

// NewSettingsService creates a new SettingsService
func NewSettingsService() *SettingsService {
	return &SettingsService{db: database.GetDB()}
}

// GetSettings retrieves all settings for a company
func (s *SettingsService) GetSettings(companyID int) (map[string]string, error) {
	query := `SELECT key, value FROM settings WHERE company_id = $1`
	rows, err := s.db.Query(query, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get settings: %w", err)
	}
	defer rows.Close()

	settings := make(map[string]string)
	for rows.Next() {
		var key, value string
		if err := rows.Scan(&key, &value); err != nil {
			return nil, fmt.Errorf("failed to scan setting: %w", err)
		}
		settings[key] = value
	}

	return settings, nil
}

// UpdateSettings updates or inserts multiple settings for a company
func (s *SettingsService) UpdateSettings(companyID int, settings map[string]string) error {
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare(`INSERT INTO settings (company_id, key, value) VALUES ($1, $2, $3)
            ON CONFLICT (company_id, key) DO UPDATE SET value = EXCLUDED.value, updated_at = CURRENT_TIMESTAMP`)
	if err != nil {
		return fmt.Errorf("failed to prepare statement: %w", err)
	}
	defer stmt.Close()

	for k, v := range settings {
		if _, err := stmt.Exec(companyID, k, v); err != nil {
			return fmt.Errorf("failed to upsert setting %s: %w", k, err)
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit settings: %w", err)
	}
	return nil
}
