package services

import (
	"database/sql"
	"fmt"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

// LanguageService provides language related database operations
type LanguageService struct {
	db *sql.DB
}

// NewLanguageService creates a new LanguageService
func NewLanguageService() *LanguageService {
	return &LanguageService{db: database.GetDB()}
}

// GetActiveLanguages returns all active languages
func (s *LanguageService) GetActiveLanguages() ([]models.Language, error) {
	rows, err := s.db.Query(`SELECT language_code, language_name, is_active, created_at FROM languages WHERE is_active = TRUE`)
	if err != nil {
		return nil, fmt.Errorf("failed to query languages: %w", err)
	}
	defer rows.Close()

	var languages []models.Language
	for rows.Next() {
		var lang models.Language
		if err := rows.Scan(&lang.LanguageCode, &lang.LanguageName, &lang.IsActive, &lang.CreatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan language: %w", err)
		}
		languages = append(languages, lang)
	}
	return languages, nil
}

// UpdateLanguageStatus updates the active status of a language
func (s *LanguageService) UpdateLanguageStatus(code string, active bool) error {
	res, err := s.db.Exec(`UPDATE languages SET is_active = $1 WHERE language_code = $2`, active, code)
	if err != nil {
		return fmt.Errorf("failed to update language: %w", err)
	}
	affected, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if affected == 0 {
		return fmt.Errorf("language not found")
	}
	return nil
}
