package database

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/pressly/goose/v3"
)

// ApplyMigrations applies SQL migrations using pressly/goose.
// The migrationsDir is resolved relative to the current working directory.
func ApplyMigrations(db *sql.DB, migrationsDir string) error {
	if db == nil {
		db = DB
	}
	if db == nil {
		return fmt.Errorf("database connection is nil")
	}

	if migrationsDir == "" {
		migrationsDir = "migrations"
	}
	migrationsDir = filepath.Clean(migrationsDir)

	if _, err := os.Stat(migrationsDir); err != nil {
		return fmt.Errorf("migrations dir not found: %s: %w", migrationsDir, err)
	}

	if err := goose.SetDialect("postgres"); err != nil {
		return fmt.Errorf("failed to set goose dialect: %w", err)
	}

	log.Printf("Applying migrations from %s", migrationsDir)
	if err := goose.Up(db, migrationsDir); err != nil {
		return fmt.Errorf("failed to apply migrations: %w", err)
	}
	return nil
}
