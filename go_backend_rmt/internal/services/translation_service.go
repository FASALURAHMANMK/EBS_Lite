package services

import (
	"database/sql"
	"fmt"

	"erp-backend/internal/database"
)

// TranslationService handles translation retrieval and updates
type TranslationService struct {
	db *sql.DB
}

func NewTranslationService() *TranslationService {
	return &TranslationService{db: database.GetDB()}
}

// GetTranslations returns a map of translation key/value pairs for a language
func (s *TranslationService) GetTranslations(lang string) (map[string]string, error) {
	rows, err := s.db.Query(`SELECT key, value FROM translations WHERE language_code = $1`, lang)
	if err != nil {
		return nil, fmt.Errorf("failed to get translations: %w", err)
	}
	defer rows.Close()

	translations := make(map[string]string)
	for rows.Next() {
		var key, value string
		if err := rows.Scan(&key, &value); err != nil {
			return nil, fmt.Errorf("failed to scan translation: %w", err)
		}
		translations[key] = value
	}
	return translations, nil
}

// UpdateTranslations upserts translation strings for a language
func (s *TranslationService) UpdateTranslations(lang string, data map[string]string) error {
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare(`INSERT INTO translations (key, language_code, value)
        VALUES ($1, $2, $3)
        ON CONFLICT (key, language_code, context) DO UPDATE SET value = EXCLUDED.value`)
	if err != nil {
		return fmt.Errorf("failed to prepare statement: %w", err)
	}
	defer stmt.Close()

	for k, v := range data {
		if _, err := stmt.Exec(k, lang, v); err != nil {
			return fmt.Errorf("failed to upsert translation %s: %w", k, err)
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit translations: %w", err)
	}
	return nil
}
