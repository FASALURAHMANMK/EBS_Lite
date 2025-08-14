package services

import (
	"database/sql"
	"fmt"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
	"erp-backend/internal/utils"
)

type UserService struct {
	db *sql.DB
}

func NewUserService() *UserService {
	return &UserService{
		db: database.GetDB(),
	}
}

func (s *UserService) GetUsers(companyID *int, locationID *int) ([]models.UserResponse, error) {
	query := `
		SELECT u.user_id, u.username, u.email, u.first_name, u.last_name, u.phone,
			   u.role_id, u.location_id, u.company_id, u.is_active, u.is_locked,
			   u.preferred_language, u.secondary_language, u.last_login
		FROM users u
		WHERE u.is_deleted = FALSE
	`

	args := []interface{}{}
	argCount := 0

	if companyID != nil {
		argCount++
		query += fmt.Sprintf(" AND u.company_id = $%d", argCount)
		args = append(args, *companyID)
	}

	if locationID != nil {
		argCount++
		query += fmt.Sprintf(" AND u.location_id = $%d", argCount)
		args = append(args, *locationID)
	}

	query += " ORDER BY u.username"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get users: %w", err)
	}
	defer rows.Close()

	var users []models.UserResponse
	for rows.Next() {
		var user models.UserResponse
		err := rows.Scan(
			&user.UserID, &user.Username, &user.Email, &user.FirstName,
			&user.LastName, &user.Phone, &user.RoleID, &user.LocationID,
			&user.CompanyID, &user.IsActive, &user.IsLocked,
			&user.PreferredLanguage, &user.SecondaryLanguage, &user.LastLogin,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan user: %w", err)
		}
		users = append(users, user)
	}

	return users, nil
}

func (s *UserService) CreateUser(req *models.CreateUserRequest) (*models.UserResponse, error) {
	// Check if username or email already exists
	exists, err := s.checkUserExists(req.Username, req.Email)
	if err != nil {
		return nil, fmt.Errorf("failed to check user existence: %w", err)
	}
	if exists {
		return nil, fmt.Errorf("username or email already exists")
	}

	// Hash password
	hashedPassword, err := utils.HashPassword(req.Password)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}

	// Insert user
	query := `
		INSERT INTO users (company_id, location_id, role_id, username, email, password_hash,
						  first_name, last_name, phone, preferred_language, secondary_language)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		RETURNING user_id, created_at
	`

	var userID int
	var createdAt string
	err = s.db.QueryRow(query,
		req.CompanyID, req.LocationID, req.RoleID, req.Username, req.Email,
		hashedPassword, req.FirstName, req.LastName, req.Phone,
		req.PreferredLanguage, req.SecondaryLanguage,
	).Scan(&userID, &createdAt)

	if err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	// Return created user
	return &models.UserResponse{
		UserID:            userID,
		Username:          req.Username,
		Email:             req.Email,
		FirstName:         req.FirstName,
		LastName:          req.LastName,
		Phone:             req.Phone,
		RoleID:            req.RoleID,
		LocationID:        req.LocationID,
		CompanyID:         &req.CompanyID,
		IsActive:          true,
		IsLocked:          false,
		PreferredLanguage: req.PreferredLanguage,
		SecondaryLanguage: req.SecondaryLanguage,
	}, nil
}

func (s *UserService) UpdateUser(userID int, req *models.UpdateUserRequest) error {
	setParts := []string{}
	args := []interface{}{}
	argCount := 0

	if req.FirstName != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("first_name = $%d", argCount))
		args = append(args, *req.FirstName)
	}
	if req.LastName != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("last_name = $%d", argCount))
		args = append(args, *req.LastName)
	}
	if req.Phone != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("phone = $%d", argCount))
		args = append(args, *req.Phone)
	}
	if req.IsActive != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("is_active = $%d", argCount))
		args = append(args, *req.IsActive)
	}
	if req.IsLocked != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("is_locked = $%d", argCount))
		args = append(args, *req.IsLocked)
	}
	if req.RoleID != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("role_id = $%d", argCount))
		args = append(args, *req.RoleID)
	}
	if req.LocationID != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("location_id = $%d", argCount))
		args = append(args, *req.LocationID)
	}
	if req.PreferredLanguage != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("preferred_language = $%d", argCount))
		args = append(args, *req.PreferredLanguage)
	}
	if req.SecondaryLanguage != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("secondary_language = $%d", argCount))
		args = append(args, *req.SecondaryLanguage)
	}

	if len(setParts) == 0 {
		return fmt.Errorf("no fields to update")
	}

	argCount++
	setParts = append(setParts, fmt.Sprintf("updated_at = CURRENT_TIMESTAMP"))

	query := fmt.Sprintf("UPDATE users SET %s WHERE user_id = $%d",
		fmt.Sprintf("%s", setParts), argCount)
	args = append(args, userID)

	result, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update user: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("user not found")
	}

	return nil
}

func (s *UserService) DeleteUser(userID int) error {
	query := `UPDATE users SET is_deleted = TRUE, updated_at = CURRENT_TIMESTAMP WHERE user_id = $1`

	result, err := s.db.Exec(query, userID)
	if err != nil {
		return fmt.Errorf("failed to delete user: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("user not found")
	}

	return nil
}

func (s *UserService) checkUserExists(username, email string) (bool, error) {
	query := `SELECT COUNT(*) FROM users WHERE (username = $1 OR email = $2) AND is_deleted = FALSE`

	var count int
	err := s.db.QueryRow(query, username, email).Scan(&count)
	if err != nil {
		return false, err
	}

	return count > 0, nil
}
