package services

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type AttributeDefinitionProvider interface {
	GetAttributeDefinitions(companyID int) ([]models.ProductAttributeDefinition, error)
}

type ProductService struct {
	db               *sql.DB
	attributeService AttributeDefinitionProvider
}

func NewProductService() *ProductService {
	return &ProductService{
		db:               database.GetDB(),
		attributeService: NewProductAttributeService(),
	}
}

// validateSinglePrimaryBarcode ensures exactly one barcode is marked as primary.
func validateSinglePrimaryBarcode(barcodes []models.ProductBarcode) error {
	count := 0
	for _, bc := range barcodes {
		if bc.IsPrimary {
			count++
		}
	}
	if count != 1 {
		return fmt.Errorf("exactly one primary barcode is required")
	}
	return nil
}

func (s *ProductService) GetProducts(companyID int, filters map[string]string) ([]models.Product, error) {
	query := `
                SELECT product_id, company_id, category_id, brand_id, unit_id, name, sku,
                           description, cost_price, selling_price, reorder_level, weight, dimensions,
                           is_serialized, is_active, created_by, updated_by, sync_status, created_at, updated_at, is_deleted
                FROM products
                WHERE company_id = $1 AND is_deleted = FALSE
        `

	args := []interface{}{companyID}
	argCount := 1

	// Add filters
	if categoryID := filters["category_id"]; categoryID != "" {
		argCount++
		query += fmt.Sprintf(" AND category_id = $%d", argCount)
		args = append(args, categoryID)
	}

	if brandID := filters["brand_id"]; brandID != "" {
		argCount++
		query += fmt.Sprintf(" AND brand_id = $%d", argCount)
		args = append(args, brandID)
	}

	if isActive := filters["is_active"]; isActive != "" {
		argCount++
		query += fmt.Sprintf(" AND is_active = $%d", argCount)
		args = append(args, isActive == "true")
	}

	query += " ORDER BY name"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get products: %w", err)
	}
	defer rows.Close()

	var products []models.Product
	for rows.Next() {
		var product models.Product
		err := rows.Scan(
			&product.ProductID, &product.CompanyID, &product.CategoryID, &product.BrandID,
			&product.UnitID, &product.Name, &product.SKU, &product.Description,
			&product.CostPrice, &product.SellingPrice, &product.ReorderLevel, &product.Weight,
			&product.Dimensions, &product.IsSerialized, &product.IsActive, &product.CreatedBy, &product.UpdatedBy,
			&product.SyncStatus, &product.CreatedAt, &product.UpdatedAt, &product.IsDeleted,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan product: %w", err)
		}

		product.Barcodes, err = s.getProductBarcodes(product.ProductID)
		if err != nil {
			return nil, fmt.Errorf("failed to get product barcodes: %w", err)
		}

		product.Attributes, err = s.getProductAttributes(product.ProductID)
		if err != nil {
			return nil, fmt.Errorf("failed to get product attributes: %w", err)
		}

		products = append(products, product)
	}

	return products, nil
}

func (s *ProductService) GetProductByID(productID, companyID int) (*models.Product, error) {
	query := `
                SELECT product_id, company_id, category_id, brand_id, unit_id, name, sku,
                           description, cost_price, selling_price, reorder_level, weight, dimensions,
                           is_serialized, is_active, created_by, updated_by, sync_status, created_at, updated_at, is_deleted
                FROM products
                WHERE product_id = $1 AND company_id = $2 AND is_deleted = FALSE
        `

	var product models.Product
	err := s.db.QueryRow(query, productID, companyID).Scan(
		&product.ProductID, &product.CompanyID, &product.CategoryID, &product.BrandID,
		&product.UnitID, &product.Name, &product.SKU, &product.Description,
		&product.CostPrice, &product.SellingPrice, &product.ReorderLevel, &product.Weight,
		&product.Dimensions, &product.IsSerialized, &product.IsActive, &product.CreatedBy, &product.UpdatedBy,
		&product.SyncStatus, &product.CreatedAt, &product.UpdatedAt, &product.IsDeleted,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("product not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get product: %w", err)
	}

	product.Barcodes, err = s.getProductBarcodes(product.ProductID)
	if err != nil {
		return nil, fmt.Errorf("failed to get product barcodes: %w", err)
	}

	product.Attributes, err = s.getProductAttributes(product.ProductID)
	if err != nil {
		return nil, fmt.Errorf("failed to get product attributes: %w", err)
	}

	return &product, nil
}

func (s *ProductService) CreateProduct(companyID, userID int, req *models.CreateProductRequest) (*models.Product, error) {
	if err := validateSinglePrimaryBarcode(req.Barcodes); err != nil {
		return nil, err
	}
	if req.SKU != nil {
		exists, err := s.checkProductExists(companyID, req.SKU, nil, 0)
		if err != nil {
			return nil, fmt.Errorf("failed to check product existence: %w", err)
		}
		if exists {
			return nil, fmt.Errorf("product with this SKU or barcode already exists")
		}
	}
	for _, bc := range req.Barcodes {
		b := bc.Barcode
		exists, err := s.checkProductExists(companyID, nil, &b, 0)
		if err != nil {
			return nil, fmt.Errorf("failed to check product existence: %w", err)
		}
		if exists {
			return nil, fmt.Errorf("product with this SKU or barcode already exists")
		}
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	query := `
                INSERT INTO products (
                        company_id, category_id, brand_id, unit_id, name, sku, description,
                        cost_price, selling_price, reorder_level, weight, dimensions, is_serialized,
                        created_by, updated_by
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
                RETURNING product_id, created_at
        `

	var product models.Product
	err = tx.QueryRow(query,
		companyID, req.CategoryID, req.BrandID, req.UnitID, req.Name, req.SKU,
		req.Description, req.CostPrice, req.SellingPrice, req.ReorderLevel, req.Weight,
		req.Dimensions, req.IsSerialized, userID, userID,
	).Scan(&product.ProductID, &product.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create product: %w", err)
	}

	// insert barcodes
	for _, bc := range req.Barcodes {
		_, err = tx.Exec(`INSERT INTO product_barcodes (product_id, barcode, pack_size, cost_price, selling_price, is_primary) VALUES ($1,$2,$3,$4,$5,$6)`,
			product.ProductID, bc.Barcode, bc.PackSize, bc.CostPrice, bc.SellingPrice, bc.IsPrimary)
		if err != nil {
			return nil, fmt.Errorf("failed to insert product barcode: %w", err)
		}
	}

	if err := s.validateAndSaveAttributes(tx, companyID, product.ProductID, req.Attributes); err != nil {
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Set the response fields
	product.CompanyID = companyID
	product.CategoryID = req.CategoryID
	product.BrandID = req.BrandID
	product.UnitID = req.UnitID
	product.Name = req.Name
	product.SKU = req.SKU
	product.Barcodes = req.Barcodes
	product.Description = req.Description
	product.CostPrice = req.CostPrice
	product.SellingPrice = req.SellingPrice
	product.ReorderLevel = req.ReorderLevel
	product.Weight = req.Weight
	product.Dimensions = req.Dimensions
	product.IsSerialized = req.IsSerialized
	product.IsActive = true
	product.CreatedBy = userID
	product.UpdatedBy = &userID
	product.Attributes, _ = s.getProductAttributes(product.ProductID)

	return &product, nil
}

func (s *ProductService) UpdateProduct(productID, companyID, userID int, req *models.UpdateProductRequest) (*models.Product, error) {
	if req.Barcodes != nil {
		if err := validateSinglePrimaryBarcode(req.Barcodes); err != nil {
			return nil, err
		}
	}
	if req.SKU != nil {
		exists, err := s.checkProductExists(companyID, req.SKU, nil, productID)
		if err != nil {
			return nil, fmt.Errorf("failed to check product existence: %w", err)
		}
		if exists {
			return nil, fmt.Errorf("product with this SKU or barcode already exists")
		}
	}
	if req.Barcodes != nil {
		for _, bc := range req.Barcodes {
			b := bc.Barcode
			exists, err := s.checkProductExists(companyID, nil, &b, productID)
			if err != nil {
				return nil, fmt.Errorf("failed to check product existence: %w", err)
			}
			if exists {
				return nil, fmt.Errorf("product with this SKU or barcode already exists")
			}
		}
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	setParts := []string{}
	args := []interface{}{}
	argCount := 0
	changes := models.JSONB{}

	if req.CategoryID != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("category_id = $%d", argCount))
		args = append(args, *req.CategoryID)
		changes["category_id"] = *req.CategoryID
	}
	if req.BrandID != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("brand_id = $%d", argCount))
		args = append(args, *req.BrandID)
		changes["brand_id"] = *req.BrandID
	}
	if req.UnitID != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("unit_id = $%d", argCount))
		args = append(args, *req.UnitID)
		changes["unit_id"] = *req.UnitID
	}
	if req.Name != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("name = $%d", argCount))
		args = append(args, *req.Name)
		changes["name"] = *req.Name
	}
	if req.SKU != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("sku = $%d", argCount))
		args = append(args, *req.SKU)
		changes["sku"] = *req.SKU
	}
	if req.Description != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("description = $%d", argCount))
		args = append(args, *req.Description)
		changes["description"] = *req.Description
	}
	if req.CostPrice != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("cost_price = $%d", argCount))
		args = append(args, *req.CostPrice)
		changes["cost_price"] = *req.CostPrice
	}
	if req.SellingPrice != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("selling_price = $%d", argCount))
		args = append(args, *req.SellingPrice)
		changes["selling_price"] = *req.SellingPrice
	}
	if req.ReorderLevel != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("reorder_level = $%d", argCount))
		args = append(args, *req.ReorderLevel)
		changes["reorder_level"] = *req.ReorderLevel
	}
	if req.Weight != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("weight = $%d", argCount))
		args = append(args, *req.Weight)
		changes["weight"] = *req.Weight
	}
	if req.Dimensions != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("dimensions = $%d", argCount))
		args = append(args, *req.Dimensions)
		changes["dimensions"] = *req.Dimensions
	}
	if req.IsSerialized != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("is_serialized = $%d", argCount))
		args = append(args, *req.IsSerialized)
		changes["is_serialized"] = *req.IsSerialized
	}
	if req.IsActive != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("is_active = $%d", argCount))
		args = append(args, *req.IsActive)
		changes["is_active"] = *req.IsActive
	}
	if req.Barcodes != nil {
		changes["barcodes"] = req.Barcodes
	}

	if len(setParts) == 0 {
		return nil, fmt.Errorf("no fields to update")
	}

	argCount++
	setParts = append(setParts, fmt.Sprintf("updated_by = $%d", argCount))
	args = append(args, userID)
	setParts = append(setParts, "updated_at = CURRENT_TIMESTAMP")

	query := fmt.Sprintf("UPDATE products SET %s WHERE product_id = $%d AND company_id = $%d",
		strings.Join(setParts, ", "), argCount+1, argCount+2)
	args = append(args, productID, companyID)

	result, err := tx.Exec(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to update product: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return nil, fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return nil, fmt.Errorf("product not found")
	}

	if req.Barcodes != nil {
		if _, err := tx.Exec("DELETE FROM product_barcodes WHERE product_id = $1", productID); err != nil {
			return nil, fmt.Errorf("failed to clear product barcodes: %w", err)
		}
		for _, bc := range req.Barcodes {
			if _, err := tx.Exec(`INSERT INTO product_barcodes (product_id, barcode, pack_size, cost_price, selling_price, is_primary) VALUES ($1,$2,$3,$4,$5,$6)`,
				productID, bc.Barcode, bc.PackSize, bc.CostPrice, bc.SellingPrice, bc.IsPrimary); err != nil {
				return nil, fmt.Errorf("failed to insert product barcode: %w", err)
			}
		}
	}

	if req.Attributes != nil {
		if err := s.validateAndSaveAttributes(tx, companyID, productID, req.Attributes); err != nil {
			return nil, err
		}
	}

	if len(changes) > 0 {
		recordID := productID
		actorID := userID
		if err := LogAudit(tx, "UPDATE", "products", &recordID, &actorID, nil, nil, &changes, nil, nil); err != nil {
			return nil, fmt.Errorf("failed to log audit: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}

	product, err := s.GetProductByID(productID, companyID)
	if err != nil {
		return nil, err
	}

	return product, nil
}

func (s *ProductService) DeleteProduct(productID, companyID, userID int) error {
	query := `UPDATE products SET is_deleted = TRUE, updated_at = CURRENT_TIMESTAMP, updated_by = $3
                          WHERE product_id = $1 AND company_id = $2`

	result, err := s.db.Exec(query, productID, companyID, userID)
	if err != nil {
		return fmt.Errorf("failed to delete product: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("product not found")
	}

	return nil
}

// Categories
func (s *ProductService) GetCategories(companyID int) ([]models.Category, error) {
	query := `
                SELECT category_id, company_id, name, description, parent_id, is_active, created_by, updated_by, created_at, updated_at
                FROM categories
                WHERE company_id = $1 AND is_active = TRUE
                ORDER BY name
        `

	rows, err := s.db.Query(query, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get categories: %w", err)
	}
	defer rows.Close()

	var categories []models.Category
	for rows.Next() {
		var category models.Category
		err := rows.Scan(
			&category.CategoryID, &category.CompanyID, &category.Name, &category.Description,
			&category.ParentID, &category.IsActive, &category.CreatedBy, &category.UpdatedBy, &category.CreatedAt, &category.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan category: %w", err)
		}
		categories = append(categories, category)
	}

	return categories, nil
}

func (s *ProductService) CreateCategory(companyID, userID int, req *models.CreateCategoryRequest) (*models.Category, error) {
	query := `
                INSERT INTO categories (company_id, name, description, parent_id, created_by, updated_by)
                VALUES ($1, $2, $3, $4, $5, $5)
                RETURNING category_id, created_at
        `

	var category models.Category
	err := s.db.QueryRow(query, companyID, req.Name, req.Description, req.ParentID, userID).Scan(
		&category.CategoryID, &category.CreatedAt)

	if err != nil {
		return nil, fmt.Errorf("failed to create category: %w", err)
	}

	category.CompanyID = companyID
	category.Name = req.Name
	category.Description = req.Description
	category.ParentID = req.ParentID
	category.IsActive = true
	category.CreatedBy = userID
	category.UpdatedBy = &userID

	return &category, nil
}

func (s *ProductService) UpdateCategory(companyID, categoryID, userID int, req *models.UpdateCategoryRequest) (*models.Category, error) {
	setParts := []string{}
	args := []interface{}{}
	argCount := 1

	if req.Name != nil {
		setParts = append(setParts, fmt.Sprintf("name = $%d", argCount))
		args = append(args, *req.Name)
		argCount++
	}
	if req.Description != nil {
		setParts = append(setParts, fmt.Sprintf("description = $%d", argCount))
		args = append(args, *req.Description)
		argCount++
	}
	if req.ParentID != nil {
		setParts = append(setParts, fmt.Sprintf("parent_id = $%d", argCount))
		args = append(args, *req.ParentID)
		argCount++
	}
	if req.IsActive != nil {
		setParts = append(setParts, fmt.Sprintf("is_active = $%d", argCount))
		args = append(args, *req.IsActive)
		argCount++
	}

	if len(setParts) == 0 {
		return nil, fmt.Errorf("no fields to update")
	}

	setParts = append(setParts, fmt.Sprintf("updated_by = $%d", argCount))
	args = append(args, userID)
	argCount++

	query := fmt.Sprintf(`UPDATE categories SET %s, updated_at = CURRENT_TIMESTAMP WHERE category_id = $%d AND company_id = $%d RETURNING category_id, company_id, name, description, parent_id, is_active, created_by, updated_by, created_at, updated_at`, strings.Join(setParts, ", "), argCount, argCount+1)
	args = append(args, categoryID, companyID)

	var category models.Category
	err := s.db.QueryRow(query, args...).Scan(
		&category.CategoryID, &category.CompanyID, &category.Name, &category.Description,
		&category.ParentID, &category.IsActive, &category.CreatedBy, &category.UpdatedBy,
		&category.CreatedAt, &category.UpdatedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("category not found")
		}
		return nil, fmt.Errorf("failed to update category: %w", err)
	}

	return &category, nil
}

func (s *ProductService) DeleteCategory(companyID, categoryID, userID int) error {
	query := `UPDATE categories SET is_active = FALSE, updated_by = $3, updated_at = CURRENT_TIMESTAMP WHERE category_id = $1 AND company_id = $2 AND is_active = TRUE`

	res, err := s.db.Exec(query, categoryID, companyID, userID)
	if err != nil {
		return fmt.Errorf("failed to delete category: %w", err)
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("category not found")
	}
	return nil
}

// Brands
func (s *ProductService) GetBrands(companyID int) ([]models.Brand, error) {
	query := `
                SELECT brand_id, company_id, name, description, is_active, created_by, updated_by, created_at, updated_at
                FROM brands
                WHERE company_id = $1 AND is_active = TRUE
                ORDER BY name
        `

	rows, err := s.db.Query(query, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get brands: %w", err)
	}
	defer rows.Close()

	var brands []models.Brand
	for rows.Next() {
		var brand models.Brand
		err := rows.Scan(
			&brand.BrandID, &brand.CompanyID, &brand.Name, &brand.Description,
			&brand.IsActive, &brand.CreatedBy, &brand.UpdatedBy, &brand.CreatedAt, &brand.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan brand: %w", err)
		}
		brands = append(brands, brand)
	}

	return brands, nil
}

func (s *ProductService) CreateBrand(companyID, userID int, req *models.CreateBrandRequest) (*models.Brand, error) {
	query := `
                INSERT INTO brands (company_id, name, description, created_by, updated_by)
                VALUES ($1, $2, $3, $4, $4)
                RETURNING brand_id, created_at
        `

	var brand models.Brand
	err := s.db.QueryRow(query, companyID, req.Name, req.Description, userID).Scan(
		&brand.BrandID, &brand.CreatedAt)

	if err != nil {
		return nil, fmt.Errorf("failed to create brand: %w", err)
	}

	brand.CompanyID = companyID
	brand.Name = req.Name
	brand.Description = req.Description
	brand.IsActive = true
	brand.CreatedBy = userID
	brand.UpdatedBy = &userID

	return &brand, nil
}

func (s *ProductService) UpdateBrand(companyID, brandID, userID int, req *models.UpdateBrandRequest) (*models.Brand, error) {
    setParts := []string{}
    args := []interface{}{}
    argCount := 1

    if req.Name != nil {
        setParts = append(setParts, fmt.Sprintf("name = $%d", argCount))
        args = append(args, *req.Name)
        argCount++
    }
    if req.Description != nil {
        setParts = append(setParts, fmt.Sprintf("description = $%d", argCount))
        args = append(args, *req.Description)
        argCount++
    }
    if req.IsActive != nil {
        setParts = append(setParts, fmt.Sprintf("is_active = $%d", argCount))
        args = append(args, *req.IsActive)
        argCount++
    }

    if len(setParts) == 0 {
        return nil, fmt.Errorf("no fields to update")
    }

    setParts = append(setParts, fmt.Sprintf("updated_by = $%d", argCount))
    args = append(args, userID)
    argCount++

    query := fmt.Sprintf(`UPDATE brands SET %s, updated_at = CURRENT_TIMESTAMP WHERE brand_id = $%d AND company_id = $%d RETURNING brand_id, company_id, name, description, is_active, created_by, updated_by, created_at, updated_at`, strings.Join(setParts, ", "), argCount, argCount+1)
    args = append(args, brandID, companyID)

    var brand models.Brand
    err := s.db.QueryRow(query, args...).Scan(
        &brand.BrandID, &brand.CompanyID, &brand.Name, &brand.Description,
        &brand.IsActive, &brand.CreatedBy, &brand.UpdatedBy, &brand.CreatedAt, &brand.UpdatedAt,
    )
    if err != nil {
        if err == sql.ErrNoRows {
            return nil, fmt.Errorf("brand not found")
        }
        return nil, fmt.Errorf("failed to update brand: %w", err)
    }

    return &brand, nil
}

func (s *ProductService) DeleteBrand(companyID, brandID, userID int) error {
    query := `UPDATE brands SET is_active = FALSE, updated_by = $3, updated_at = CURRENT_TIMESTAMP WHERE brand_id = $1 AND company_id = $2 AND is_active = TRUE`
    res, err := s.db.Exec(query, brandID, companyID, userID)
    if err != nil {
        return fmt.Errorf("failed to delete brand: %w", err)
    }
    rows, err := res.RowsAffected()
    if err != nil {
        return fmt.Errorf("failed to get rows affected: %w", err)
    }
    if rows == 0 {
        return fmt.Errorf("brand not found")
    }
    return nil
}

// Units
func (s *ProductService) GetUnits() ([]models.Unit, error) {
	query := `
		SELECT unit_id, name, symbol, base_unit_id, conversion_factor
		FROM units 
		ORDER BY name
	`

	rows, err := s.db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("failed to get units: %w", err)
	}
	defer rows.Close()

	var units []models.Unit
	for rows.Next() {
		var unit models.Unit
		err := rows.Scan(
			&unit.UnitID, &unit.Name, &unit.Symbol, &unit.BaseUnitID, &unit.ConversionFactor,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan unit: %w", err)
		}
		units = append(units, unit)
	}

	return units, nil
}

func (s *ProductService) CreateUnit(req *models.CreateUnitRequest) (*models.Unit, error) {
	query := `
		INSERT INTO units (name, symbol, base_unit_id, conversion_factor)
		VALUES ($1, $2, $3, $4)
		RETURNING unit_id
	`

	var unit models.Unit
	err := s.db.QueryRow(query, req.Name, req.Symbol, req.BaseUnitID, req.ConversionFactor).Scan(&unit.UnitID)

	if err != nil {
		return nil, fmt.Errorf("failed to create unit: %w", err)
	}

	unit.Name = req.Name
	unit.Symbol = req.Symbol
	unit.BaseUnitID = req.BaseUnitID
	unit.ConversionFactor = req.ConversionFactor

	return &unit, nil
}

// Helper methods
func (s *ProductService) checkProductExists(companyID int, sku, barcode *string, excludeProductID int) (bool, error) {
	if sku != nil && *sku != "" {
		query := "SELECT COUNT(*) FROM products WHERE company_id = $1 AND is_deleted = FALSE AND sku = $2"
		args := []interface{}{companyID, *sku}
		if excludeProductID > 0 {
			query += " AND product_id <> $3"
			args = append(args, excludeProductID)
		}
		var count int
		if err := s.db.QueryRow(query, args...).Scan(&count); err != nil {
			return false, err
		}
		if count > 0 {
			return true, nil
		}
	}

	if barcode != nil && *barcode != "" {
		query := `SELECT COUNT(*) FROM products p JOIN product_barcodes pb ON p.product_id = pb.product_id WHERE p.company_id = $1 AND p.is_deleted = FALSE AND pb.barcode = $2`
		args := []interface{}{companyID, *barcode}
		if excludeProductID > 0 {
			query += " AND p.product_id <> $3"
			args = append(args, excludeProductID)
		}
		var count int
		if err := s.db.QueryRow(query, args...).Scan(&count); err != nil {
			return false, err
		}
		if count > 0 {
			return true, nil
		}
	}

	return false, nil
}

func (s *ProductService) getProductBarcodes(productID int) ([]models.ProductBarcode, error) {
	rows, err := s.db.Query(`SELECT barcode_id, product_id, barcode, pack_size, cost_price, selling_price, is_primary FROM product_barcodes WHERE product_id = $1`, productID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var barcodes []models.ProductBarcode
	for rows.Next() {
		var bc models.ProductBarcode
		if err := rows.Scan(&bc.BarcodeID, &bc.ProductID, &bc.Barcode, &bc.PackSize, &bc.CostPrice, &bc.SellingPrice, &bc.IsPrimary); err != nil {
			return nil, err
		}
		barcodes = append(barcodes, bc)
	}
	return barcodes, nil
}

func (s *ProductService) getProductAttributes(productID int) ([]models.ProductAttributeValue, error) {
	rows, err := s.db.Query(`SELECT pav.attribute_id, pav.product_id, pav.value, pa.company_id, pa.name, pa.type, pa.is_required, pa.options FROM product_attribute_values pav JOIN product_attributes pa ON pav.attribute_id = pa.attribute_id WHERE pav.product_id = $1`, productID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var attrs []models.ProductAttributeValue
	for rows.Next() {
		var val models.ProductAttributeValue
		if err := rows.Scan(&val.AttributeID, &val.ProductID, &val.Value, &val.Definition.CompanyID, &val.Definition.Name, &val.Definition.Type, &val.Definition.IsRequired, &val.Definition.Options); err != nil {
			return nil, err
		}
		val.Definition.AttributeID = val.AttributeID
		attrs = append(attrs, val)
	}
	return attrs, nil
}

type sqlExecutor interface {
	Exec(query string, args ...interface{}) (sql.Result, error)
}

func (s *ProductService) validateAndSaveAttributes(exec sqlExecutor, companyID, productID int, attrs map[int]string) error {
	defsList, err := s.attributeService.GetAttributeDefinitions(companyID)
	if err != nil {
		return fmt.Errorf("failed to fetch attribute definitions: %w", err)
	}
	defs := make(map[int]models.ProductAttributeDefinition)
	for _, d := range defsList {
		defs[d.AttributeID] = d
		if d.IsRequired {
			if _, ok := attrs[d.AttributeID]; !ok {
				return fmt.Errorf("missing required attribute %s", d.Name)
			}
		}
	}

	if _, err := exec.Exec("DELETE FROM product_attribute_values WHERE product_id = $1", productID); err != nil {
		return fmt.Errorf("failed to clear attribute values: %w", err)
	}
	for id, val := range attrs {
		def, ok := defs[id]
		if !ok {
			return fmt.Errorf("invalid attribute id %d", id)
		}
		if err := validateAttributeValue(def, val); err != nil {
			return err
		}
		if _, err := exec.Exec(`INSERT INTO product_attribute_values (product_id, attribute_id, value) VALUES ($1,$2,$3)`, productID, id, val); err != nil {
			return fmt.Errorf("failed to insert attribute value: %w", err)
		}
	}
	return nil
}

func validateAttributeValue(def models.ProductAttributeDefinition, value string) error {
	switch def.Type {
	case "NUMBER":
		if _, err := strconv.ParseFloat(value, 64); err != nil {
			return fmt.Errorf("attribute %s expects NUMBER", def.Name)
		}
	case "BOOLEAN":
		if _, err := strconv.ParseBool(value); err != nil {
			return fmt.Errorf("attribute %s expects BOOLEAN", def.Name)
		}
	case "DATE":
		if _, err := time.Parse("2006-01-02", value); err != nil {
			return fmt.Errorf("attribute %s expects DATE", def.Name)
		}
	case "SELECT":
		if def.Options == nil {
			return fmt.Errorf("attribute %s has no options", def.Name)
		}
		var opts []string
		if err := json.Unmarshal([]byte(*def.Options), &opts); err != nil {
			return fmt.Errorf("invalid options for attribute %s", def.Name)
		}
		valid := false
		for _, opt := range opts {
			if opt == value {
				valid = true
				break
			}
		}
		if !valid {
			return fmt.Errorf("value for attribute %s must be one of %v", def.Name, opts)
		}
	}
	return nil
}
