package services

import (
	"database/sql"

	"erp-backend/internal/database"
)

type UserPreferencesService struct {
	db *sql.DB
}

func NewUserPreferencesService() *UserPreferencesService {
	return &UserPreferencesService{db: database.GetDB()}
}

func (s *UserPreferencesService) GetPreferences(userID int) (map[string]string, error) {
	query := `SELECT key, value FROM user_preferences WHERE user_id=$1`
	rows, err := s.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	prefs := make(map[string]string)
	for rows.Next() {
		var key, value string
		if err := rows.Scan(&key, &value); err != nil {
			return nil, err
		}
		prefs[key] = value
	}
	return prefs, nil
}

func (s *UserPreferencesService) UpsertPreference(userID int, key, value string) error {
	query := `INSERT INTO user_preferences (user_id, key, value) VALUES ($1,$2,$3)
              ON CONFLICT (user_id, key) DO UPDATE SET value=EXCLUDED.value`
	_, err := s.db.Exec(query, userID, key, value)
	return err
}

func (s *UserPreferencesService) DeletePreference(userID int, key string) error {
	_, err := s.db.Exec(`DELETE FROM user_preferences WHERE user_id=$1 AND key=$2`, userID, key)
	return err
}
