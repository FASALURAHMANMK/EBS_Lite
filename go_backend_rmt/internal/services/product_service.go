package services

import (
	"database/sql"
	"fmt"
	"strings"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type ProductService struct {
	db *sql.DB
}

func NewProductService() *ProductService {
	return &ProductService{
		db: database.GetDB(),
	}
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
		product.Barcodes, _ = s.getProductBarcodes(product.ProductID)
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

	product.Barcodes, _ = s.getProductBarcodes(product.ProductID)

	return &product, nil
}

func (s *ProductService) CreateProduct(companyID, userID int, req *models.CreateProductRequest) (*models.Product, error) {
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

	return &product, nil
}

func (s *ProductService) UpdateProduct(productID, companyID, userID int, req *models.UpdateProductRequest) error {
	if req.SKU != nil {
		exists, err := s.checkProductExists(companyID, req.SKU, nil, productID)
		if err != nil {
			return fmt.Errorf("failed to check product existence: %w", err)
		}
		if exists {
			return fmt.Errorf("product with this SKU or barcode already exists")
		}
	}
	if req.Barcodes != nil {
		for _, bc := range req.Barcodes {
			b := bc.Barcode
			exists, err := s.checkProductExists(companyID, nil, &b, productID)
			if err != nil {
				return fmt.Errorf("failed to check product existence: %w", err)
			}
			if exists {
				return fmt.Errorf("product with this SKU or barcode already exists")
			}
		}
	}

	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
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
		return fmt.Errorf("no fields to update")
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
		return fmt.Errorf("failed to update product: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("product not found")
	}

	if req.Barcodes != nil {
		if _, err := tx.Exec("DELETE FROM product_barcodes WHERE product_id = $1", productID); err != nil {
			return fmt.Errorf("failed to clear product barcodes: %w", err)
		}
		for _, bc := range req.Barcodes {
			if _, err := tx.Exec(`INSERT INTO product_barcodes (product_id, barcode, pack_size, cost_price, selling_price, is_primary) VALUES ($1,$2,$3,$4,$5,$6)`,
				productID, bc.Barcode, bc.PackSize, bc.CostPrice, bc.SellingPrice, bc.IsPrimary); err != nil {
				return fmt.Errorf("failed to insert product barcode: %w", err)
			}
		}
	}

	if len(changes) > 0 {
		recordID := productID
		actorID := userID
		if err := LogAudit(tx, "UPDATE", "products", &recordID, &actorID, nil, nil, &changes, nil, nil); err != nil {
			return fmt.Errorf("failed to log audit: %w", err)
		}
	}

	return tx.Commit()
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
