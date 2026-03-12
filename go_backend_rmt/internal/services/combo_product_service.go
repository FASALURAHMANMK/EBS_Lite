package services

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"

	"github.com/lib/pq"
)

type ComboProductService struct {
	db *sql.DB
}

type comboProductMeta struct {
	ComboProductID int
	Name           string
	Barcode        string
	TaxID          *int
	SellingPrice   float64
	Components     []models.ComboProductComponent
}

func NewComboProductService() *ComboProductService {
	return &ComboProductService{db: database.GetDB()}
}

func normalizeOptionalString(value *string) *string {
	if value == nil {
		return nil
	}
	trimmed := strings.TrimSpace(*value)
	if trimmed == "" {
		return nil
	}
	return &trimmed
}

func (s *ComboProductService) ListComboProducts(companyID int, locationID *int, search string) ([]models.ComboProduct, error) {
	args := []interface{}{companyID}
	query := `
		SELECT cp.combo_product_id, cp.company_id, cp.name, cp.sku, cp.barcode,
		       cp.selling_price::float8, cp.tax_id, cp.notes, cp.is_active,
		       cp.created_by, cp.updated_by, cp.sync_status, cp.created_at, cp.updated_at
		FROM combo_products cp
		WHERE cp.company_id = $1 AND cp.is_deleted = FALSE
	`
	if trimmed := strings.TrimSpace(search); trimmed != "" {
		pattern := "%" + trimmed + "%"
		args = append(args, pattern, trimmed)
		query += fmt.Sprintf(`
			AND (
				cp.name ILIKE $%d OR
				COALESCE(cp.sku, '') ILIKE $%d OR
				cp.barcode = $%d OR
				cp.barcode ILIKE $%d
			)
		`, len(args)-1, len(args)-1, len(args), len(args)-1)
	}
	query += " ORDER BY cp.name, cp.combo_product_id"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to list combo products: %w", err)
	}
	defer rows.Close()

	items := make([]models.ComboProduct, 0)
	ids := make([]int, 0)
	for rows.Next() {
		var item models.ComboProduct
		if err := rows.Scan(
			&item.ComboProductID, &item.CompanyID, &item.Name, &item.SKU, &item.Barcode,
			&item.SellingPrice, &item.TaxID, &item.Notes, &item.IsActive,
			&item.CreatedBy, &item.UpdatedBy, &item.SyncStatus, &item.CreatedAt, &item.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan combo product: %w", err)
		}
		items = append(items, item)
		ids = append(ids, item.ComboProductID)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read combo products: %w", err)
	}
	if len(items) == 0 {
		return items, nil
	}

	componentsByCombo, err := s.loadComboComponents(ids, locationID)
	if err != nil {
		return nil, err
	}
	availabilityByCombo, err := s.loadComboAvailability(ids, locationID)
	if err != nil {
		return nil, err
	}

	for i := range items {
		items[i].Components = componentsByCombo[items[i].ComboProductID]
		if availability, ok := availabilityByCombo[items[i].ComboProductID]; ok {
			items[i].AvailableStock = &availability
		}
	}
	return items, nil
}

func (s *ComboProductService) GetComboProductByID(comboProductID, companyID int, locationID *int) (*models.ComboProduct, error) {
	var item models.ComboProduct
	err := s.db.QueryRow(`
		SELECT cp.combo_product_id, cp.company_id, cp.name, cp.sku, cp.barcode,
		       cp.selling_price::float8, cp.tax_id, cp.notes, cp.is_active,
		       cp.created_by, cp.updated_by, cp.sync_status, cp.created_at, cp.updated_at
		FROM combo_products cp
		WHERE cp.combo_product_id = $1 AND cp.company_id = $2 AND cp.is_deleted = FALSE
	`, comboProductID, companyID).Scan(
		&item.ComboProductID, &item.CompanyID, &item.Name, &item.SKU, &item.Barcode,
		&item.SellingPrice, &item.TaxID, &item.Notes, &item.IsActive,
		&item.CreatedBy, &item.UpdatedBy, &item.SyncStatus, &item.CreatedAt, &item.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("combo product not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get combo product: %w", err)
	}

	componentsByCombo, err := s.loadComboComponents([]int{comboProductID}, locationID)
	if err != nil {
		return nil, err
	}
	item.Components = componentsByCombo[comboProductID]
	availabilityByCombo, err := s.loadComboAvailability([]int{comboProductID}, locationID)
	if err != nil {
		return nil, err
	}
	if availability, ok := availabilityByCombo[comboProductID]; ok {
		item.AvailableStock = &availability
	}
	return &item, nil
}

func (s *ComboProductService) CreateComboProduct(companyID, userID int, req *models.CreateComboProductRequest) (*models.ComboProduct, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	if err := s.validateComboRequestTx(tx, companyID, 0, req.Name, req.SKU, req.Barcode, req.TaxID, req.Components); err != nil {
		return nil, err
	}

	var comboProductID int
	isActive := true
	if req.IsActive != nil {
		isActive = *req.IsActive
	}
	err = tx.QueryRow(`
		INSERT INTO combo_products (
			company_id, name, sku, barcode, selling_price, tax_id, notes, is_active,
			created_by, updated_by
		) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$9)
		RETURNING combo_product_id
	`, companyID, strings.TrimSpace(req.Name), normalizeOptionalString(req.SKU), strings.TrimSpace(req.Barcode),
		req.SellingPrice, req.TaxID, normalizeOptionalString(req.Notes), isActive, userID,
	).Scan(&comboProductID)
	if err != nil {
		return nil, fmt.Errorf("failed to create combo product: %w", err)
	}

	if err := s.replaceComboComponentsTx(tx, comboProductID, req.Components); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit combo product: %w", err)
	}
	return s.GetComboProductByID(comboProductID, companyID, nil)
}

func (s *ComboProductService) UpdateComboProduct(comboProductID, companyID, userID int, req *models.UpdateComboProductRequest) (*models.ComboProduct, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	current, currentComponents, err := s.getComboProductForUpdateTx(tx, comboProductID, companyID)
	if err != nil {
		return nil, err
	}

	name := current.Name
	if req.Name != nil {
		name = strings.TrimSpace(*req.Name)
	}
	sku := current.SKU
	if req.SKU != nil {
		sku = normalizeOptionalString(req.SKU)
	}
	barcode := current.Barcode
	if req.Barcode != nil {
		barcode = strings.TrimSpace(*req.Barcode)
	}
	taxID := current.TaxID
	if req.TaxID != nil {
		taxID = *req.TaxID
	}
	components := currentComponents
	if req.Components != nil {
		components = req.Components
	}

	if err := s.validateComboRequestTx(tx, companyID, comboProductID, name, sku, barcode, taxID, components); err != nil {
		return nil, err
	}

	sellingPrice := current.SellingPrice
	if req.SellingPrice != nil {
		sellingPrice = *req.SellingPrice
	}
	notes := current.Notes
	if req.Notes != nil {
		notes = normalizeOptionalString(req.Notes)
	}
	isActive := current.IsActive
	if req.IsActive != nil {
		isActive = *req.IsActive
	}

	if _, err := tx.Exec(`
		UPDATE combo_products
		SET name = $1,
		    sku = $2,
		    barcode = $3,
		    selling_price = $4,
		    tax_id = $5,
		    notes = $6,
		    is_active = $7,
		    updated_by = $8,
		    updated_at = CURRENT_TIMESTAMP
		WHERE combo_product_id = $9 AND company_id = $10 AND is_deleted = FALSE
	`, name, sku, barcode, sellingPrice, taxID, notes, isActive, userID, comboProductID, companyID); err != nil {
		return nil, fmt.Errorf("failed to update combo product: %w", err)
	}

	if req.Components != nil {
		if err := s.replaceComboComponentsTx(tx, comboProductID, req.Components); err != nil {
			return nil, err
		}
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit combo product update: %w", err)
	}
	return s.GetComboProductByID(comboProductID, companyID, nil)
}

func (s *ComboProductService) DeleteComboProduct(comboProductID, companyID, userID int) error {
	result, err := s.db.Exec(`
		UPDATE combo_products
		SET is_deleted = TRUE,
		    is_active = FALSE,
		    updated_by = $1,
		    updated_at = CURRENT_TIMESTAMP
		WHERE combo_product_id = $2 AND company_id = $3 AND is_deleted = FALSE
	`, userID, comboProductID, companyID)
	if err != nil {
		return fmt.Errorf("failed to delete combo product: %w", err)
	}
	rows, err := result.RowsAffected()
	if err == nil && rows == 0 {
		return fmt.Errorf("combo product not found")
	}
	return nil
}

func (s *ComboProductService) getComboProductForUpdateTx(tx *sql.Tx, comboProductID, companyID int) (*models.ComboProduct, []models.CreateComboComponentInput, error) {
	var item models.ComboProduct
	err := tx.QueryRow(`
		SELECT combo_product_id, company_id, name, sku, barcode, selling_price::float8,
		       tax_id, notes, is_active, created_by, updated_by, sync_status, created_at, updated_at
		FROM combo_products
		WHERE combo_product_id = $1 AND company_id = $2 AND is_deleted = FALSE
	`, comboProductID, companyID).Scan(
		&item.ComboProductID, &item.CompanyID, &item.Name, &item.SKU, &item.Barcode,
		&item.SellingPrice, &item.TaxID, &item.Notes, &item.IsActive,
		&item.CreatedBy, &item.UpdatedBy, &item.SyncStatus, &item.CreatedAt, &item.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil, fmt.Errorf("combo product not found")
	}
	if err != nil {
		return nil, nil, fmt.Errorf("failed to load combo product: %w", err)
	}
	rows, err := tx.Query(`
		SELECT product_id, barcode_id, quantity::float8, sort_order
		FROM combo_product_items
		WHERE combo_product_id = $1
		ORDER BY sort_order, combo_product_item_id
	`, comboProductID)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to load combo components: %w", err)
	}
	defer rows.Close()

	components := make([]models.CreateComboComponentInput, 0)
	for rows.Next() {
		var component models.CreateComboComponentInput
		if err := rows.Scan(&component.ProductID, &component.BarcodeID, &component.Quantity, &component.SortOrder); err != nil {
			return nil, nil, fmt.Errorf("failed to scan combo component: %w", err)
		}
		components = append(components, component)
	}
	return &item, components, nil
}

func (s *ComboProductService) validateComboRequestTx(tx *sql.Tx, companyID, comboProductID int, name string, sku *string, barcode string, taxID int, components []models.CreateComboComponentInput) error {
	if strings.TrimSpace(name) == "" {
		return fmt.Errorf("combo name is required")
	}
	barcode = strings.TrimSpace(barcode)
	if barcode == "" {
		return fmt.Errorf("combo barcode is required")
	}
	if len(components) == 0 {
		return fmt.Errorf("at least one combo component is required")
	}
	var taxExists bool
	if err := tx.QueryRow(`SELECT EXISTS(SELECT 1 FROM taxes WHERE tax_id = $1 AND company_id = $2 AND is_active = TRUE)`, taxID, companyID).Scan(&taxExists); err != nil {
		return fmt.Errorf("failed to validate combo tax: %w", err)
	}
	if !taxExists {
		return fmt.Errorf("tax not found")
	}

	var barcodeConflict bool
	if err := tx.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM product_barcodes pb
			JOIN products p ON p.product_id = pb.product_id
			WHERE pb.barcode = $1 AND p.company_id = $2 AND p.is_deleted = FALSE
			UNION ALL
			SELECT 1 FROM combo_products cp
			WHERE cp.barcode = $1 AND cp.company_id = $2 AND cp.is_deleted = FALSE AND cp.combo_product_id <> $3
		)
	`, barcode, companyID, comboProductID).Scan(&barcodeConflict); err != nil {
		return fmt.Errorf("failed to validate combo barcode: %w", err)
	}
	if barcodeConflict {
		return fmt.Errorf("combo barcode already exists")
	}

	if sku != nil && strings.TrimSpace(*sku) != "" {
		var skuConflict bool
		if err := tx.QueryRow(`
			SELECT EXISTS(
				SELECT 1 FROM combo_products
				WHERE company_id = $1 AND sku = $2 AND is_deleted = FALSE AND combo_product_id <> $3
			)
		`, companyID, strings.TrimSpace(*sku), comboProductID).Scan(&skuConflict); err != nil {
			return fmt.Errorf("failed to validate combo SKU: %w", err)
		}
		if skuConflict {
			return fmt.Errorf("combo SKU already exists")
		}
	}

	componentBarcodeIDs := make([]int, 0, len(components))
	seenBarcode := make(map[int]struct{}, len(components))
	for _, component := range components {
		if component.ProductID <= 0 || component.BarcodeID <= 0 {
			return fmt.Errorf("combo components require product_id and barcode_id")
		}
		if component.Quantity <= 0 {
			return fmt.Errorf("combo component quantity must be greater than zero")
		}
		if _, ok := seenBarcode[component.BarcodeID]; ok {
			return fmt.Errorf("duplicate combo component barcode %d", component.BarcodeID)
		}
		seenBarcode[component.BarcodeID] = struct{}{}
		componentBarcodeIDs = append(componentBarcodeIDs, component.BarcodeID)
	}

	rows, err := tx.Query(`
		SELECT p.product_id, pb.barcode_id,
		       CASE WHEN COALESCE(p.tracking_type, 'VARIANT') = 'BATCH' THEN 'BATCH' ELSE 'VARIANT' END AS tracking_type,
		       CASE WHEN COALESCE(p.is_serialized, FALSE) OR COALESCE(p.tracking_type, '') = 'SERIAL' THEN TRUE ELSE FALSE END AS is_serialized
		FROM products p
		JOIN product_barcodes pb ON pb.product_id = p.product_id
		WHERE p.company_id = $1
		  AND p.is_deleted = FALSE
		  AND COALESCE(pb.is_active, TRUE) = TRUE
		  AND pb.barcode_id = ANY($2)
	`, companyID, pq.Array(componentBarcodeIDs))
	if err != nil {
		return fmt.Errorf("failed to validate combo components: %w", err)
	}
	defer rows.Close()

	type componentMeta struct {
		ProductID    int
		TrackingType string
		IsSerialized bool
	}
	metaByBarcode := make(map[int]componentMeta, len(componentBarcodeIDs))
	for rows.Next() {
		var barcodeID int
		var meta componentMeta
		if err := rows.Scan(&meta.ProductID, &barcodeID, &meta.TrackingType, &meta.IsSerialized); err != nil {
			return fmt.Errorf("failed to scan combo component validation row: %w", err)
		}
		metaByBarcode[barcodeID] = meta
	}
	for _, component := range components {
		meta, ok := metaByBarcode[component.BarcodeID]
		if !ok {
			return fmt.Errorf("combo component variation not found")
		}
		if meta.ProductID != component.ProductID {
			return fmt.Errorf("combo component barcode does not belong to product")
		}
	}
	return nil
}

func (s *ComboProductService) replaceComboComponentsTx(tx *sql.Tx, comboProductID int, components []models.CreateComboComponentInput) error {
	if _, err := tx.Exec(`DELETE FROM combo_product_items WHERE combo_product_id = $1`, comboProductID); err != nil {
		return fmt.Errorf("failed to clear combo components: %w", err)
	}
	for index, component := range components {
		sortOrder := component.SortOrder
		if sortOrder == 0 {
			sortOrder = index + 1
		}
		if _, err := tx.Exec(`
			INSERT INTO combo_product_items (combo_product_id, product_id, barcode_id, quantity, sort_order)
			VALUES ($1,$2,$3,$4,$5)
		`, comboProductID, component.ProductID, component.BarcodeID, component.Quantity, sortOrder); err != nil {
			return fmt.Errorf("failed to save combo component: %w", err)
		}
	}
	return nil
}

func (s *ComboProductService) loadComboComponents(comboProductIDs []int, locationID *int) (map[int][]models.ComboProductComponent, error) {
	result := make(map[int][]models.ComboProductComponent)
	if len(comboProductIDs) == 0 {
		return result, nil
	}
	args := []interface{}{pq.Array(comboProductIDs)}
	locationJoin := ""
	locationSelect := "NULL::float8"
	if locationID != nil && *locationID > 0 {
		args = append(args, *locationID)
		locationJoin = fmt.Sprintf("LEFT JOIN stock_variants sv ON sv.barcode_id = cpi.barcode_id AND sv.location_id = $%d", len(args))
		locationSelect = "COALESCE(sv.quantity, 0)::float8"
	}
	rows, err := s.db.Query(fmt.Sprintf(`
		SELECT cpi.combo_product_id, cpi.combo_product_item_id, cpi.product_id, cpi.barcode_id,
		       cpi.quantity::float8, cpi.sort_order, p.name, p.sku, pb.barcode, pb.variant_name,
		       CASE WHEN COALESCE(p.tracking_type, 'VARIANT') = 'BATCH' THEN 'BATCH' ELSE 'VARIANT' END AS tracking_type,
		       CASE WHEN COALESCE(p.is_serialized, FALSE) OR COALESCE(p.tracking_type, '') = 'SERIAL' THEN TRUE ELSE FALSE END AS is_serialized,
		       u.symbol, COALESCE(pb.selling_price, p.selling_price, 0)::float8 AS selling_price, %s AS available_stock
		FROM combo_product_items cpi
		JOIN products p ON p.product_id = cpi.product_id
		JOIN product_barcodes pb ON pb.barcode_id = cpi.barcode_id
		LEFT JOIN units u ON u.unit_id = p.unit_id
		%s
		WHERE cpi.combo_product_id = ANY($1)
		ORDER BY cpi.combo_product_id, cpi.sort_order, cpi.combo_product_item_id
	`, locationSelect, locationJoin), args...)
	if err != nil {
		return nil, fmt.Errorf("failed to load combo components: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var item models.ComboProductComponent
		var sellingPrice sql.NullFloat64
		var available sql.NullFloat64
		if err := rows.Scan(
			&item.ComboProductID, &item.ComboProductItemID, &item.ProductID, &item.BarcodeID,
			&item.Quantity, &item.SortOrder, &item.ProductName, &item.ProductSKU, &item.Barcode,
			&item.VariantName, &item.TrackingType, &item.IsSerialized, &item.UnitSymbol, &sellingPrice, &available,
		); err != nil {
			return nil, fmt.Errorf("failed to scan combo component: %w", err)
		}
		if sellingPrice.Valid {
			value := sellingPrice.Float64
			item.SellingPrice = &value
		}
		if available.Valid {
			value := available.Float64
			item.AvailableStock = &value
		}
		result[item.ComboProductID] = append(result[item.ComboProductID], item)
	}
	return result, nil
}

func (s *ComboProductService) loadComboAvailability(comboProductIDs []int, locationID *int) (map[int]float64, error) {
	result := make(map[int]float64)
	if len(comboProductIDs) == 0 || locationID == nil || *locationID <= 0 {
		return result, nil
	}
	rows, err := s.db.Query(`
		SELECT cpi.combo_product_id,
		       CASE
		         WHEN COUNT(*) = 0 THEN 0::float8
		         ELSE MIN(COALESCE(sv.quantity, 0)::float8 / NULLIF(cpi.quantity::float8, 0))
		       END AS available_stock
		FROM combo_product_items cpi
		LEFT JOIN stock_variants sv ON sv.location_id = $2 AND sv.barcode_id = cpi.barcode_id
		WHERE cpi.combo_product_id = ANY($1)
		GROUP BY cpi.combo_product_id
	`, pq.Array(comboProductIDs), *locationID)
	if err != nil {
		return nil, fmt.Errorf("failed to load combo availability: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var comboProductID int
		var available float64
		if err := rows.Scan(&comboProductID, &available); err != nil {
			return nil, fmt.Errorf("failed to scan combo availability: %w", err)
		}
		result[comboProductID] = available
	}
	return result, nil
}

func fetchComboProductMeta(q sqlQueryer, companyID int, comboProductIDs []int, locationID *int) (map[int]comboProductMeta, error) {
	ids := uniqueInts(comboProductIDs)
	if len(ids) == 0 {
		return map[int]comboProductMeta{}, nil
	}
	rows, err := q.Query(`
		SELECT combo_product_id, name, barcode, tax_id, selling_price::float8
		FROM combo_products
		WHERE company_id = $1 AND is_deleted = FALSE AND is_active = TRUE AND combo_product_id = ANY($2)
	`, companyID, pq.Array(ids))
	if err != nil {
		return nil, fmt.Errorf("failed to fetch combo products: %w", err)
	}
	defer rows.Close()

	result := make(map[int]comboProductMeta, len(ids))
	for rows.Next() {
		var item comboProductMeta
		var taxID sql.NullInt64
		if err := rows.Scan(&item.ComboProductID, &item.Name, &item.Barcode, &taxID, &item.SellingPrice); err != nil {
			return nil, fmt.Errorf("failed to scan combo product: %w", err)
		}
		if taxID.Valid && taxID.Int64 > 0 {
			value := int(taxID.Int64)
			item.TaxID = &value
		}
		result[item.ComboProductID] = item
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read combo products: %w", err)
	}
	if len(result) != len(ids) {
		return nil, fmt.Errorf("combo product not found")
	}

	service := NewComboProductService()
	componentsByCombo, err := service.loadComboComponents(ids, locationID)
	if err != nil {
		return nil, err
	}
	for comboProductID, item := range result {
		item.Components = componentsByCombo[comboProductID]
		if len(item.Components) == 0 {
			return nil, fmt.Errorf("combo product is missing components")
		}
		result[comboProductID] = item
	}
	return result, nil
}

func consumeComboComponentsTx(tx *sql.Tx, companyID, locationID, userID int, saleDetailID int, combo comboProductMeta, saleQuantity float64, overridePassword *string) (float64, error) {
	trackingSvc := newInventoryTrackingService(database.GetDB())
	totalCost := 0.0
	for _, component := range combo.Components {
		requiredQty := component.Quantity * saleQuantity
		if requiredQty <= 0 {
			continue
		}
		note := strings.TrimSpace(fmt.Sprintf("Combo %s (%s)", combo.Name, combo.Barcode))
		issue, err := trackingSvc.IssueStockTx(tx, companyID, locationID, userID, "SALE", "sale_detail_combo_component", &saleDetailID, nil, inventorySelection{
			ProductID:        component.ProductID,
			BarcodeID:        intPtr(component.BarcodeID),
			Quantity:         requiredQty,
			Notes:            &note,
			OverridePassword: overridePassword,
		})
		if err != nil {
			return 0, err
		}
		componentCost := issue.TotalCost
		totalCost += componentCost
		if _, err := tx.Exec(`
			INSERT INTO sale_detail_combo_components (
				sale_detail_id, combo_product_id, product_id, barcode_id, quantity, unit_cost, total_cost, created_at
			) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		`, saleDetailID, combo.ComboProductID, component.ProductID, component.BarcodeID, requiredQty, issue.UnitCost, componentCost, time.Now().UTC()); err != nil {
			return 0, fmt.Errorf("failed to record combo component consumption: %w", err)
		}
	}
	return totalCost, nil
}

func intPtr(value int) *int {
	return &value
}
