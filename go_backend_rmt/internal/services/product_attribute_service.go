package services

import (
	"database/sql"
	"fmt"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type ProductAttributeService struct {
	db *sql.DB
}

func NewProductAttributeService() *ProductAttributeService {
	return &ProductAttributeService{db: database.GetDB()}
}

// GetProductAttributes returns all attributes for a company
func (s *ProductAttributeService) GetProductAttributes(companyID int) ([]models.ProductAttribute, error) {
	rows, err := s.db.Query(`
        SELECT attribute_id, company_id, name, value, sync_status, created_at, updated_at, is_deleted
        FROM product_attributes WHERE company_id = $1 AND is_deleted = FALSE`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get product attributes: %w", err)
	}
	defer rows.Close()

	var attrs []models.ProductAttribute
	for rows.Next() {
		var a models.ProductAttribute
		if err := rows.Scan(&a.AttributeID, &a.CompanyID, &a.Name, &a.Value, &a.SyncStatus, &a.CreatedAt, &a.UpdatedAt, &a.IsDeleted); err != nil {
			return nil, fmt.Errorf("failed to scan attribute: %w", err)
		}
		attrs = append(attrs, a)
	}
	return attrs, nil
}

// CreateProductAttribute adds a new attribute
func (s *ProductAttributeService) CreateProductAttribute(companyID int, req *models.CreateProductAttributeRequest) (*models.ProductAttribute, error) {
	var attr models.ProductAttribute
	err := s.db.QueryRow(`
        INSERT INTO product_attributes (company_id, name, value) VALUES ($1,$2,$3)
        RETURNING attribute_id, created_at`, companyID, req.Name, req.Value).Scan(&attr.AttributeID, &attr.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create attribute: %w", err)
	}
	attr.CompanyID = companyID
	attr.Name = req.Name
	attr.Value = req.Value
	return &attr, nil
}

// UpdateProductAttribute updates an existing attribute
func (s *ProductAttributeService) UpdateProductAttribute(id, companyID int, req *models.UpdateProductAttributeRequest) error {
	query := "UPDATE product_attributes SET "
	params := []interface{}{}
	idx := 1

	if req.Name != nil {
		query += fmt.Sprintf("name = $%d,", idx)
		params = append(params, *req.Name)
		idx++
	}
	if req.Value != nil {
		query += fmt.Sprintf("value = $%d,", idx)
		params = append(params, *req.Value)
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

	_, err := s.db.Exec(query, params...)
	if err != nil {
		return fmt.Errorf("failed to update attribute: %w", err)
	}
	return nil
}

// DeleteProductAttribute soft deletes an attribute
func (s *ProductAttributeService) DeleteProductAttribute(id, companyID int) error {
	_, err := s.db.Exec(`UPDATE product_attributes SET is_deleted = TRUE WHERE attribute_id = $1 AND company_id = $2`, id, companyID)
	if err != nil {
		return fmt.Errorf("failed to delete attribute: %w", err)
	}
	return nil
}
