package services

import (
	"database/sql"
	"fmt"
	"strings"

	"erp-backend/internal/utils"
)

type salesActionPasswordQueryer interface {
	QueryRow(query string, args ...any) *sql.Row
}

func requireSalesActionPassword(
	q salesActionPasswordQueryer,
	companyID int,
	userID int,
	password *string,
) error {
	var storedHash sql.NullString
	err := q.QueryRow(`
		SELECT u.sales_action_password_hash
		FROM users u
		WHERE u.user_id = $1
		  AND u.company_id = $2
		  AND u.is_deleted = FALSE
	`, userID, companyID).Scan(&storedHash)
	if err == sql.ErrNoRows {
		return fmt.Errorf("user not found")
	}
	if err != nil {
		return fmt.Errorf("failed to load sales action password: %w", err)
	}

	if !storedHash.Valid || strings.TrimSpace(storedHash.String) == "" {
		return fmt.Errorf("sales action password is not configured for this user")
	}
	if password == nil || strings.TrimSpace(*password) == "" {
		return fmt.Errorf("sales action password is required")
	}

	valid, err := utils.VerifyPassword(strings.TrimSpace(*password), storedHash.String)
	if err != nil {
		return fmt.Errorf("failed to verify sales action password: %w", err)
	}
	if !valid {
		return fmt.Errorf("invalid sales action password")
	}

	return nil
}
