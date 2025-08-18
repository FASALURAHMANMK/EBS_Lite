package models

import "time"

// Translation represents a localized string
// It corresponds to the translations table.
type Translation struct {
	TranslationID int       `json:"translation_id" db:"translation_id"`
	Key           string    `json:"key" db:"key"`
	LanguageCode  string    `json:"language_code" db:"language_code"`
	Value         string    `json:"value" db:"value"`
	Context       *string   `json:"context,omitempty" db:"context"`
	CreatedAt     time.Time `json:"created_at" db:"created_at"`
}

// UpdateTranslationsRequest is used to update translation strings for a language
// Lang represents the language code and Strings is a map of key-value pairs.
type UpdateTranslationsRequest struct {
	Lang    string            `json:"lang" validate:"required"`
	Strings map[string]string `json:"strings" validate:"required"`
}
