package services

import (
	"database/sql"
	"fmt"
	"strings"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type ProductAttributeService struct {
	db *sql.DB
}

func NewProductAttributeService() *ProductAttributeService {
	return &ProductAttributeService{db: database.GetDB()}
}

// GetAttributeDefinitions returns all attribute definitions for a company
func (s *ProductAttributeService) GetAttributeDefinitions(companyID int) ([]models.ProductAttributeDefinition, error) {
	rows, err := s.db.Query(`
        SELECT attribute_id, company_id, name, type, is_required, options, sync_status, created_at, updated_at, is_deleted
        FROM product_attributes WHERE company_id = $1 AND is_deleted = FALSE`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get product attribute definitions: %w", err)
	}
	defer rows.Close()

	var defs []models.ProductAttributeDefinition
	for rows.Next() {
		var d models.ProductAttributeDefinition
		if err := rows.Scan(&d.AttributeID, &d.CompanyID, &d.Name, &d.Type, &d.IsRequired, &d.Options, &d.SyncStatus, &d.CreatedAt, &d.UpdatedAt, &d.IsDeleted); err != nil {
			return nil, fmt.Errorf("failed to scan attribute definition: %w", err)
		}
		defs = append(defs, d)
	}
	return defs, nil
}

// CreateAttributeDefinition adds a new attribute definition
func (s *ProductAttributeService) CreateAttributeDefinition(companyID int, req *models.CreateProductAttributeDefinitionRequest) (*models.ProductAttributeDefinition, error) {
	var def models.ProductAttributeDefinition
	err := s.db.QueryRow(`
        INSERT INTO product_attributes (company_id, name, type, is_required, options)
        VALUES ($1,$2,$3,$4,$5)
        RETURNING attribute_id, created_at`, companyID, req.Name, req.Type, req.IsRequired, req.Options).Scan(&def.AttributeID, &def.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create attribute definition: %w", err)
	}
	def.CompanyID = companyID
	def.Name = req.Name
	def.Type = req.Type
	def.IsRequired = req.IsRequired
	def.Options = req.Options
	return &def, nil
}

// UpdateAttributeDefinition updates an existing attribute definition
func (s *ProductAttributeService) UpdateAttributeDefinition(id, companyID int, req *models.UpdateProductAttributeDefinitionRequest) error {
	query := "UPDATE product_attributes SET "
	params := []interface{}{}
	idx := 1

	if req.Name != nil {
		query += fmt.Sprintf("name = $%d,", idx)
		params = append(params, *req.Name)
		idx++
	}
	if req.Type != nil {
		query += fmt.Sprintf("type = $%d,", idx)
		params = append(params, *req.Type)
		idx++
	}
	if req.IsRequired != nil {
		query += fmt.Sprintf("is_required = $%d,", idx)
		params = append(params, *req.IsRequired)
		idx++
	}
	if req.Options != nil {
		query += fmt.Sprintf("options = $%d,", idx)
		params = append(params, *req.Options)
		idx++
	}
	if req.IsActive != nil {
		query += fmt.Sprintf("is_active = $%d,", idx)
		params = append(params, *req.IsActive)
		idx++
	}
	if len(params) == 0 {
		return nil
	}
	query = query[:len(query)-1]
	query += fmt.Sprintf(" WHERE attribute_id = $%d AND company_id = $%d", idx, idx+1)
	params = append(params, id, companyID)

	if _, err := s.db.Exec(query, params...); err != nil {
		return fmt.Errorf("failed to update attribute definition: %w", err)
	}
	return nil
}

// DeleteAttributeDefinition soft deletes an attribute definition
func (s *ProductAttributeService) DeleteAttributeDefinition(id, companyID int) error {
	_, err := s.db.Exec(`UPDATE product_attributes SET is_deleted = TRUE WHERE attribute_id = $1 AND company_id = $2`, id, companyID)
	if err != nil {
		return fmt.Errorf("failed to delete attribute definition: %w", err)
	}
	return nil
}

// GetDefinitionsByIDs returns definitions for given IDs
func (s *ProductAttributeService) GetDefinitionsByIDs(companyID int, ids []int) (map[int]models.ProductAttributeDefinition, error) {
	if len(ids) == 0 {
		return map[int]models.ProductAttributeDefinition{}, nil
	}
	placeholders := make([]string, len(ids))
	args := []interface{}{companyID}
	for i, id := range ids {
		placeholders[i] = fmt.Sprintf("$%d", i+2)
		args = append(args, id)
	}
	query := fmt.Sprintf(`SELECT attribute_id, company_id, name, type, is_required, options FROM product_attributes WHERE company_id = $1 AND attribute_id IN (%s) AND is_deleted = FALSE`, strings.Join(placeholders, ","))
	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make(map[int]models.ProductAttributeDefinition)
	for rows.Next() {
		var d models.ProductAttributeDefinition
		if err := rows.Scan(&d.AttributeID, &d.CompanyID, &d.Name, &d.Type, &d.IsRequired, &d.Options); err != nil {
			return nil, err
		}
		result[d.AttributeID] = d
	}
	return result, nil
}
