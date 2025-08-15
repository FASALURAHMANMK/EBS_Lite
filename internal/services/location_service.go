package services

import (
	"database/sql"
	"fmt"
	"strings"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type LocationService struct {
	db *sql.DB
}

func NewLocationService() *LocationService {
	return &LocationService{
		db: database.GetDB(),
	}
}

func (s *LocationService) GetLocations(companyID *int) ([]models.Location, error) {
	query := `
		SELECT location_id, company_id, name, address, phone, is_active, 
			   created_at, updated_at
		FROM locations 
		WHERE is_active = TRUE
	`

	args := []interface{}{}
	if companyID != nil {
		query += " AND company_id = $1"
		args = append(args, *companyID)
	}

	query += " ORDER BY name"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get locations: %w", err)
	}
	defer rows.Close()

	var locations []models.Location
	for rows.Next() {
		var location models.Location
		err := rows.Scan(
			&location.LocationID, &location.CompanyID, &location.Name,
			&location.Address, &location.Phone, &location.IsActive,
			&location.CreatedAt, &location.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan location: %w", err)
		}
		locations = append(locations, location)
	}

	return locations, nil
}

func (s *LocationService) GetLocationByID(locationID int) (*models.Location, error) {
	query := `
		SELECT location_id, company_id, name, address, phone, is_active, 
			   created_at, updated_at
		FROM locations 
		WHERE location_id = $1 AND is_active = TRUE
	`

	var location models.Location
	err := s.db.QueryRow(query, locationID).Scan(
		&location.LocationID, &location.CompanyID, &location.Name,
		&location.Address, &location.Phone, &location.IsActive,
		&location.CreatedAt, &location.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("location not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get location: %w", err)
	}

	return &location, nil
}

func (s *LocationService) CreateLocation(req *models.CreateLocationRequest) (*models.Location, error) {
	// Verify company exists
	companyExists, err := s.checkCompanyExists(req.CompanyID)
	if err != nil {
		return nil, fmt.Errorf("failed to check company existence: %w", err)
	}
	if !companyExists {
		return nil, fmt.Errorf("company not found")
	}

	query := `
		INSERT INTO locations (company_id, name, address, phone)
		VALUES ($1, $2, $3, $4)
		RETURNING location_id, created_at
	`

	var location models.Location
	err = s.db.QueryRow(query,
		req.CompanyID, req.Name, req.Address, req.Phone,
	).Scan(&location.LocationID, &location.CreatedAt)

	if err != nil {
		return nil, fmt.Errorf("failed to create location: %w", err)
	}

	location.CompanyID = req.CompanyID
	location.Name = req.Name
	location.Address = req.Address
	location.Phone = req.Phone
	location.IsActive = true

	return &location, nil
}

func (s *LocationService) UpdateLocation(locationID int, req *models.UpdateLocationRequest) error {
	setParts := []string{}
	args := []interface{}{}
	argCount := 0

	if req.Name != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("name = $%d", argCount))
		args = append(args, *req.Name)
	}
	if req.Address != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("address = $%d", argCount))
		args = append(args, *req.Address)
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

	if len(setParts) == 0 {
		return fmt.Errorf("no fields to update")
	}

	setParts = append(setParts, "updated_at = CURRENT_TIMESTAMP")

	query := fmt.Sprintf("UPDATE locations SET %s WHERE location_id = $%d",
		strings.Join(setParts, ", "), argCount+1)
	args = append(args, locationID)

	result, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update location: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("location not found")
	}

	return nil
}

func (s *LocationService) DeleteLocation(locationID int) error {
	query := `UPDATE locations SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP WHERE location_id = $1`

	result, err := s.db.Exec(query, locationID)
	if err != nil {
		return fmt.Errorf("failed to delete location: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("location not found")
	}

	return nil
}

func (s *LocationService) checkCompanyExists(companyID int) (bool, error) {
	query := `SELECT COUNT(*) FROM companies WHERE company_id = $1 AND is_active = TRUE`

	var count int
	err := s.db.QueryRow(query, companyID).Scan(&count)
	if err != nil {
		return false, err
	}

	return count > 0, nil
}
