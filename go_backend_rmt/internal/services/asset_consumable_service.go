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

type AssetConsumableService struct {
	db *sql.DB
}

func NewAssetConsumableService() *AssetConsumableService {
	return &AssetConsumableService{db: database.GetDB()}
}

func normalizeProductItemType(value string) string {
	switch strings.ToUpper(strings.TrimSpace(value)) {
	case "ASSET":
		return "ASSET"
	case "CONSUMABLE":
		return "CONSUMABLE"
	default:
		return "PRODUCT"
	}
}

func parseReportOrTxnDate(raw string) (time.Time, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return time.Time{}, fmt.Errorf("date is required")
	}
	layouts := []string{time.RFC3339, "2006-01-02", "2006-01-02 15:04:05"}
	for _, layout := range layouts {
		if parsed, err := time.Parse(layout, raw); err == nil {
			return parsed, nil
		}
	}
	return time.Time{}, fmt.Errorf("invalid date format")
}

func (s *AssetConsumableService) validateLedgerAccountTx(tx *sql.Tx, companyID int, accountID *int) error {
	if accountID == nil || *accountID <= 0 {
		return nil
	}
	var exists bool
	if err := tx.QueryRow(`
		SELECT EXISTS (
			SELECT 1
			FROM chart_of_accounts
			WHERE company_id = $1 AND account_id = $2 AND is_active = TRUE
		)
	`, companyID, *accountID).Scan(&exists); err != nil {
		return fmt.Errorf("failed to validate ledger account: %w", err)
	}
	if !exists {
		return fmt.Errorf("ledger account not found")
	}
	return nil
}

func (s *AssetConsumableService) validateNonMercantileSupplierTx(tx *sql.Tx, companyID int, supplierID *int) (string, error) {
	if supplierID == nil || *supplierID <= 0 {
		return "", fmt.Errorf("supplier_id is required")
	}

	var supplierName string
	err := tx.QueryRow(`
		SELECT name
		FROM suppliers
		WHERE company_id = $1
		  AND supplier_id = $2
		  AND is_active = TRUE
		  AND is_non_mercantile = TRUE
	`, companyID, *supplierID).Scan(&supplierName)
	if err == sql.ErrNoRows {
		return "", fmt.Errorf("supplier must be an active non-mercantile supplier")
	}
	if err != nil {
		return "", fmt.Errorf("failed to validate supplier: %w", err)
	}

	return supplierName, nil
}

func (s *AssetConsumableService) defaultNonMercantileSupplierForProductTx(tx *sql.Tx, companyID, productID int) (int, string, error) {
	var supplierID int
	var supplierName string
	err := tx.QueryRow(`
		SELECT sup.supplier_id, sup.name
		FROM products p
		JOIN suppliers sup ON sup.supplier_id = p.default_supplier_id
		WHERE p.company_id = $1
		  AND p.product_id = $2
		  AND p.is_deleted = FALSE
		  AND sup.company_id = $1
		  AND sup.is_active = TRUE
		  AND sup.is_non_mercantile = TRUE
	`, companyID, productID).Scan(&supplierID, &supplierName)
	if err == sql.ErrNoRows {
		return 0, "", fmt.Errorf("stock item must have an active non-mercantile default supplier")
	}
	if err != nil {
		return 0, "", fmt.Errorf("failed to validate stock item supplier: %w", err)
	}
	return supplierID, supplierName, nil
}

func (s *AssetConsumableService) ensureDefaultAccountIDTx(tx *sql.Tx, companyID int, code string) (int, error) {
	var id int
	if err := tx.QueryRow(`
		SELECT account_id
		FROM chart_of_accounts
		WHERE company_id = $1 AND account_code = $2 AND is_active = TRUE
		ORDER BY account_id
		LIMIT 1
	`, companyID, code).Scan(&id); err == nil {
		return id, nil
	} else if err != sql.ErrNoRows {
		return 0, fmt.Errorf("failed to lookup chart of account (%s): %w", code, err)
	}
	if err := seedMinimalChartOfAccountsTx(tx, companyID); err != nil {
		return 0, err
	}
	if err := tx.QueryRow(`
		SELECT account_id
		FROM chart_of_accounts
		WHERE company_id = $1 AND account_code = $2 AND is_active = TRUE
		ORDER BY account_id
		LIMIT 1
	`, companyID, code).Scan(&id); err != nil {
		return 0, fmt.Errorf("failed to lookup seeded chart of account (%s): %w", code, err)
	}
	return id, nil
}

func (s *AssetConsumableService) insertLedgerEntryIfMissingTx(tx *sql.Tx, companyID int, reference string, accountID int, date time.Time, debit, credit float64, transactionType string, transactionID int, description *string, userID int) error {
	_, err := tx.Exec(`
		INSERT INTO ledger_entries (
			company_id, account_id, date, debit, credit, balance,
			transaction_type, transaction_id, description, reference,
			created_by, updated_by
		)
		SELECT $1,$2,$3,$4,$5,0,$6,$7,$8,$9,$10,$10
		WHERE NOT EXISTS (
			SELECT 1 FROM ledger_entries
			WHERE company_id = $1 AND reference = $9
		)
	`, companyID, accountID, date, debit, credit, transactionType, transactionID, description, reference, userID)
	if err != nil {
		return fmt.Errorf("failed to insert ledger entry (%s): %w", reference, err)
	}
	return nil
}

func (s *AssetConsumableService) ensureProductItemTypeTx(tx *sql.Tx, companyID, productID int, itemType string) (string, error) {
	var name string
	var currentType string
	err := tx.QueryRow(`
		SELECT name, COALESCE(item_type, 'PRODUCT')
		FROM products
		WHERE company_id = $1 AND product_id = $2 AND is_deleted = FALSE
	`, companyID, productID).Scan(&name, &currentType)
	if err == sql.ErrNoRows {
		return "", fmt.Errorf("product not found")
	}
	if err != nil {
		return "", fmt.Errorf("failed to load product: %w", err)
	}
	itemType = normalizeProductItemType(itemType)
	if normalizeProductItemType(currentType) != itemType {
		if _, err := tx.Exec(`
			UPDATE products
			SET item_type = $1, updated_at = CURRENT_TIMESTAMP
			WHERE company_id = $2 AND product_id = $3
		`, itemType, companyID, productID); err != nil {
			return "", fmt.Errorf("failed to update product item type: %w", err)
		}
	}
	return name, nil
}

func (s *AssetConsumableService) assetCategoryAccountTx(tx *sql.Tx, companyID int, categoryID *int) (int, error) {
	if categoryID != nil && *categoryID > 0 {
		var accountID sql.NullInt64
		err := tx.QueryRow(`
			SELECT ledger_account_id
			FROM asset_categories
			WHERE company_id = $1 AND category_id = $2 AND is_active = TRUE
		`, companyID, *categoryID).Scan(&accountID)
		if err == sql.ErrNoRows {
			return 0, fmt.Errorf("asset category not found")
		}
		if err != nil {
			return 0, fmt.Errorf("failed to load asset category: %w", err)
		}
		if accountID.Valid && accountID.Int64 > 0 {
			return int(accountID.Int64), nil
		}
	}
	return s.ensureDefaultAccountIDTx(tx, companyID, accountCodeFixedAssets)
}

func (s *AssetConsumableService) consumableCategoryAccountTx(tx *sql.Tx, companyID int, categoryID *int) (int, error) {
	if categoryID != nil && *categoryID > 0 {
		var accountID sql.NullInt64
		err := tx.QueryRow(`
			SELECT ledger_account_id
			FROM consumable_categories
			WHERE company_id = $1 AND category_id = $2 AND is_active = TRUE
		`, companyID, *categoryID).Scan(&accountID)
		if err == sql.ErrNoRows {
			return 0, fmt.Errorf("consumable category not found")
		}
		if err != nil {
			return 0, fmt.Errorf("failed to load consumable category: %w", err)
		}
		if accountID.Valid && accountID.Int64 > 0 {
			return int(accountID.Int64), nil
		}
	}
	return s.ensureDefaultAccountIDTx(tx, companyID, accountCodeConsumables)
}

func generatedReference(prefix string) string {
	return fmt.Sprintf("%s-%d", prefix, time.Now().UTC().UnixNano())
}

func decodeBatchAllocationsOrNil(raw []byte) []models.InventoryBatchSelectionInput {
	items := decodeBatchAllocations(raw)
	if len(items) == 0 {
		return nil
	}
	return items
}

func valueOrDefault(value *string, fallback string) string {
	if value == nil {
		return fallback
	}
	trimmed := strings.TrimSpace(*value)
	if trimmed == "" {
		return fallback
	}
	return trimmed
}

func valueOrNil(value *string) string {
	if value == nil {
		return ""
	}
	return strings.TrimSpace(*value)
}

func (s *AssetConsumableService) GetAssetCategories(companyID int) ([]models.AssetCategory, error) {
	rows, err := s.db.Query(`
		SELECT
			ac.category_id, ac.company_id, ac.name, ac.description, ac.ledger_account_id,
			coa.account_code, coa.name, ac.is_active, ac.created_by, ac.updated_by, ac.created_at, ac.updated_at
		FROM asset_categories ac
		LEFT JOIN chart_of_accounts coa ON coa.account_id = ac.ledger_account_id
		WHERE ac.company_id = $1 AND ac.is_active = TRUE
		ORDER BY ac.name
	`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get asset categories: %w", err)
	}
	defer rows.Close()

	items := make([]models.AssetCategory, 0)
	for rows.Next() {
		var item models.AssetCategory
		if err := rows.Scan(
			&item.CategoryID, &item.CompanyID, &item.Name, &item.Description, &item.LedgerAccountID,
			&item.LedgerCode, &item.LedgerName, &item.IsActive, &item.CreatedBy, &item.UpdatedBy,
			&item.CreatedAt, &item.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan asset category: %w", err)
		}
		items = append(items, item)
	}
	return items, nil
}

func (s *AssetConsumableService) CreateAssetCategory(companyID, userID int, req *models.CreateAssetCategoryRequest) (*models.AssetCategory, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	if err := s.validateLedgerAccountTx(tx, companyID, req.LedgerAccountID); err != nil {
		return nil, err
	}

	var item models.AssetCategory
	err = tx.QueryRow(`
		INSERT INTO asset_categories (company_id, name, description, ledger_account_id, created_by, updated_by)
		VALUES ($1, $2, $3, $4, $5, $5)
		RETURNING category_id, company_id, name, description, ledger_account_id, is_active, created_by, updated_by, created_at, updated_at
	`, companyID, strings.TrimSpace(req.Name), req.Description, req.LedgerAccountID, userID).Scan(
		&item.CategoryID, &item.CompanyID, &item.Name, &item.Description, &item.LedgerAccountID,
		&item.IsActive, &item.CreatedBy, &item.UpdatedBy, &item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create asset category: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit asset category: %w", err)
	}
	return &item, nil
}

func (s *AssetConsumableService) UpdateAssetCategory(companyID, categoryID, userID int, req *models.UpdateAssetCategoryRequest) (*models.AssetCategory, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	if err := s.validateLedgerAccountTx(tx, companyID, req.LedgerAccountID); err != nil {
		return nil, err
	}

	setParts := make([]string, 0)
	args := make([]interface{}, 0)
	arg := 1
	if req.Name != nil {
		setParts = append(setParts, fmt.Sprintf("name = $%d", arg))
		args = append(args, strings.TrimSpace(*req.Name))
		arg++
	}
	if req.Description != nil {
		setParts = append(setParts, fmt.Sprintf("description = $%d", arg))
		args = append(args, req.Description)
		arg++
	}
	if req.LedgerAccountID != nil {
		setParts = append(setParts, fmt.Sprintf("ledger_account_id = $%d", arg))
		args = append(args, req.LedgerAccountID)
		arg++
	}
	if req.IsActive != nil {
		setParts = append(setParts, fmt.Sprintf("is_active = $%d", arg))
		args = append(args, *req.IsActive)
		arg++
	}
	if len(setParts) == 0 {
		return nil, fmt.Errorf("no fields to update")
	}
	setParts = append(setParts, fmt.Sprintf("updated_by = $%d", arg))
	args = append(args, userID)
	arg++

	query := fmt.Sprintf(`
		UPDATE asset_categories
		SET %s, updated_at = CURRENT_TIMESTAMP
		WHERE company_id = $%d AND category_id = $%d
		RETURNING category_id, company_id, name, description, ledger_account_id, is_active, created_by, updated_by, created_at, updated_at
	`, strings.Join(setParts, ", "), arg, arg+1)
	args = append(args, companyID, categoryID)

	var item models.AssetCategory
	if err := tx.QueryRow(query, args...).Scan(
		&item.CategoryID, &item.CompanyID, &item.Name, &item.Description, &item.LedgerAccountID,
		&item.IsActive, &item.CreatedBy, &item.UpdatedBy, &item.CreatedAt, &item.UpdatedAt,
	); err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("asset category not found")
		}
		return nil, fmt.Errorf("failed to update asset category: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit asset category update: %w", err)
	}
	return &item, nil
}

func (s *AssetConsumableService) DeleteAssetCategory(companyID, categoryID, userID int) error {
	res, err := s.db.Exec(`
		UPDATE asset_categories
		SET is_active = FALSE, updated_by = $3, updated_at = CURRENT_TIMESTAMP
		WHERE company_id = $1 AND category_id = $2 AND is_active = TRUE
	`, companyID, categoryID, userID)
	if err != nil {
		return fmt.Errorf("failed to delete asset category: %w", err)
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to read asset category result: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("asset category not found")
	}
	return nil
}

func (s *AssetConsumableService) GetConsumableCategories(companyID int) ([]models.ConsumableCategory, error) {
	rows, err := s.db.Query(`
		SELECT
			cc.category_id, cc.company_id, cc.name, cc.description, cc.ledger_account_id,
			coa.account_code, coa.name, cc.is_active, cc.created_by, cc.updated_by, cc.created_at, cc.updated_at
		FROM consumable_categories cc
		LEFT JOIN chart_of_accounts coa ON coa.account_id = cc.ledger_account_id
		WHERE cc.company_id = $1 AND cc.is_active = TRUE
		ORDER BY cc.name
	`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get consumable categories: %w", err)
	}
	defer rows.Close()

	items := make([]models.ConsumableCategory, 0)
	for rows.Next() {
		var item models.ConsumableCategory
		if err := rows.Scan(
			&item.CategoryID, &item.CompanyID, &item.Name, &item.Description, &item.LedgerAccountID,
			&item.LedgerCode, &item.LedgerName, &item.IsActive, &item.CreatedBy, &item.UpdatedBy,
			&item.CreatedAt, &item.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan consumable category: %w", err)
		}
		items = append(items, item)
	}
	return items, nil
}

func (s *AssetConsumableService) CreateConsumableCategory(companyID, userID int, req *models.CreateConsumableCategoryRequest) (*models.ConsumableCategory, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	if err := s.validateLedgerAccountTx(tx, companyID, req.LedgerAccountID); err != nil {
		return nil, err
	}

	var item models.ConsumableCategory
	err = tx.QueryRow(`
		INSERT INTO consumable_categories (company_id, name, description, ledger_account_id, created_by, updated_by)
		VALUES ($1, $2, $3, $4, $5, $5)
		RETURNING category_id, company_id, name, description, ledger_account_id, is_active, created_by, updated_by, created_at, updated_at
	`, companyID, strings.TrimSpace(req.Name), req.Description, req.LedgerAccountID, userID).Scan(
		&item.CategoryID, &item.CompanyID, &item.Name, &item.Description, &item.LedgerAccountID,
		&item.IsActive, &item.CreatedBy, &item.UpdatedBy, &item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create consumable category: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit consumable category: %w", err)
	}
	return &item, nil
}

func (s *AssetConsumableService) UpdateConsumableCategory(companyID, categoryID, userID int, req *models.UpdateConsumableCategoryRequest) (*models.ConsumableCategory, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	if err := s.validateLedgerAccountTx(tx, companyID, req.LedgerAccountID); err != nil {
		return nil, err
	}

	setParts := make([]string, 0)
	args := make([]interface{}, 0)
	arg := 1
	if req.Name != nil {
		setParts = append(setParts, fmt.Sprintf("name = $%d", arg))
		args = append(args, strings.TrimSpace(*req.Name))
		arg++
	}
	if req.Description != nil {
		setParts = append(setParts, fmt.Sprintf("description = $%d", arg))
		args = append(args, req.Description)
		arg++
	}
	if req.LedgerAccountID != nil {
		setParts = append(setParts, fmt.Sprintf("ledger_account_id = $%d", arg))
		args = append(args, req.LedgerAccountID)
		arg++
	}
	if req.IsActive != nil {
		setParts = append(setParts, fmt.Sprintf("is_active = $%d", arg))
		args = append(args, *req.IsActive)
		arg++
	}
	if len(setParts) == 0 {
		return nil, fmt.Errorf("no fields to update")
	}
	setParts = append(setParts, fmt.Sprintf("updated_by = $%d", arg))
	args = append(args, userID)
	arg++

	query := fmt.Sprintf(`
		UPDATE consumable_categories
		SET %s, updated_at = CURRENT_TIMESTAMP
		WHERE company_id = $%d AND category_id = $%d
		RETURNING category_id, company_id, name, description, ledger_account_id, is_active, created_by, updated_by, created_at, updated_at
	`, strings.Join(setParts, ", "), arg, arg+1)
	args = append(args, companyID, categoryID)

	var item models.ConsumableCategory
	if err := tx.QueryRow(query, args...).Scan(
		&item.CategoryID, &item.CompanyID, &item.Name, &item.Description, &item.LedgerAccountID,
		&item.IsActive, &item.CreatedBy, &item.UpdatedBy, &item.CreatedAt, &item.UpdatedAt,
	); err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("consumable category not found")
		}
		return nil, fmt.Errorf("failed to update consumable category: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit consumable category update: %w", err)
	}
	return &item, nil
}

func (s *AssetConsumableService) DeleteConsumableCategory(companyID, categoryID, userID int) error {
	res, err := s.db.Exec(`
		UPDATE consumable_categories
		SET is_active = FALSE, updated_by = $3, updated_at = CURRENT_TIMESTAMP
		WHERE company_id = $1 AND category_id = $2 AND is_active = TRUE
	`, companyID, categoryID, userID)
	if err != nil {
		return fmt.Errorf("failed to delete consumable category: %w", err)
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to read consumable category result: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("consumable category not found")
	}
	return nil
}

func (s *AssetConsumableService) CreateAssetRegisterEntry(companyID, locationID, userID int, req *models.CreateAssetRegisterEntryRequest) (*models.AssetRegisterEntry, error) {
	acquisitionDate, err := parseReportOrTxnDate(req.AcquisitionDate)
	if err != nil {
		return nil, err
	}

	var inServiceDate *time.Time
	if req.InServiceDate != nil && strings.TrimSpace(*req.InServiceDate) != "" {
		parsed, err := parseReportOrTxnDate(*req.InServiceDate)
		if err != nil {
			return nil, fmt.Errorf("invalid in_service_date: %w", err)
		}
		inServiceDate = &parsed
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	trackingSvc := newInventoryTrackingService(s.db)
	assetAccountID, err := s.assetCategoryAccountTx(tx, companyID, req.CategoryID)
	if err != nil {
		return nil, err
	}
	assetTag := strings.TrimSpace(valueOrDefault(req.AssetTag, generatedReference("AST")))

	itemName := ""
	var unitCost float64
	totalValue := 0.0
	var offsetAccountID *int
	var supplierID *int
	var supplierName *string

	switch req.SourceMode {
	case "STOCK":
		if req.ProductID == nil || *req.ProductID <= 0 {
			return nil, fmt.Errorf("product_id is required for stock asset entries")
		}
		defaultSupplierID, resolvedSupplierName, err := s.defaultNonMercantileSupplierForProductTx(tx, companyID, *req.ProductID)
		if err != nil {
			return nil, err
		}
		itemName, err = s.ensureProductItemTypeTx(tx, companyID, *req.ProductID, "ASSET")
		if err != nil {
			return nil, err
		}
		supplierID = &defaultSupplierID
		supplierName = &resolvedSupplierName
		issue, err := trackingSvc.IssueStockTx(tx, companyID, locationID, userID, "ADJUSTMENT_OUT", "asset_register_entry", nil, &assetTag, inventorySelection{
			ProductID:        *req.ProductID,
			BarcodeID:        req.BarcodeID,
			Quantity:         req.Quantity,
			SerialNumbers:    req.SerialNumbers,
			BatchAllocations: req.BatchAllocations,
			Notes:            req.Notes,
		})
		if err != nil {
			return nil, err
		}
		unitCost = issue.UnitCost
		totalValue = issue.TotalCost
	default:
		if req.ItemName == nil || strings.TrimSpace(*req.ItemName) == "" {
			return nil, fmt.Errorf("item_name is required for direct asset entries")
		}
		if req.UnitCost == nil || *req.UnitCost < 0 {
			return nil, fmt.Errorf("unit_cost is required for direct asset entries")
		}
		if req.OffsetAccountID == nil || *req.OffsetAccountID <= 0 {
			return nil, fmt.Errorf("offset_account_id is required for direct asset entries")
		}
		resolvedSupplierName, err := s.validateNonMercantileSupplierTx(tx, companyID, req.SupplierID)
		if err != nil {
			return nil, err
		}
		if err := s.validateLedgerAccountTx(tx, companyID, req.OffsetAccountID); err != nil {
			return nil, err
		}
		itemName = strings.TrimSpace(*req.ItemName)
		unitCost = *req.UnitCost
		totalValue = req.Quantity * unitCost
		supplierID = req.SupplierID
		supplierName = &resolvedSupplierName
		offsetAccountID = req.OffsetAccountID
	}

	if req.SourceMode == "STOCK" {
		inventoryAccountID, err := s.ensureDefaultAccountIDTx(tx, companyID, accountCodeInventory)
		if err != nil {
			return nil, err
		}
		offsetAccountID = &inventoryAccountID
	}
	if offsetAccountID == nil || *offsetAccountID <= 0 {
		return nil, fmt.Errorf("offset account is required")
	}

	status := strings.ToUpper(strings.TrimSpace(valueOrDefault(req.Status, "ACTIVE")))
	if status == "" {
		status = "ACTIVE"
	}
	if status != "ACTIVE" && status != "INACTIVE" && status != "DISPOSED" {
		return nil, fmt.Errorf("invalid asset status")
	}

	var entry models.AssetRegisterEntry
	var batchRaw []byte
	err = tx.QueryRow(`
		INSERT INTO asset_register_entries (
			company_id, location_id, asset_tag, product_id, barcode_id, category_id, item_name, source_mode,
			quantity, unit_cost, total_value, acquisition_date, in_service_date, status, supplier_id, offset_account_id,
			notes, serial_numbers, batch_allocations, created_by, updated_by
		)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$20)
		RETURNING asset_entry_id, company_id, location_id, asset_tag, product_id, barcode_id, category_id,
		          supplier_id, item_name, source_mode, quantity::float8, unit_cost::float8, total_value::float8,
		          acquisition_date, in_service_date, status, offset_account_id, notes, serial_numbers,
		          batch_allocations, created_by, created_at
	`, companyID, locationID, assetTag, req.ProductID, req.BarcodeID, req.CategoryID, itemName, req.SourceMode,
		req.Quantity, unitCost, totalValue, acquisitionDate, inServiceDate, status, supplierID, offsetAccountID,
		req.Notes, pq.Array(req.SerialNumbers), encodeBatchAllocations(req.BatchAllocations), userID).Scan(
		&entry.AssetEntryID, &entry.CompanyID, &entry.LocationID, &entry.AssetTag, &entry.ProductID, &entry.BarcodeID,
		&entry.CategoryID, &entry.SupplierID, &entry.ItemName, &entry.SourceMode, &entry.Quantity, &entry.UnitCost, &entry.TotalValue,
		&entry.AcquisitionDate, &entry.InServiceDate, &entry.Status, &entry.OffsetAccountID, &entry.Notes,
		pq.Array(&entry.SerialNumbers), &batchRaw, &entry.CreatedBy, &entry.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create asset register entry: %w", err)
	}
	entry.BatchAllocations = decodeBatchAllocationsOrNil(batchRaw)
	entry.SupplierName = supplierName

	desc := fmt.Sprintf("Asset capitalization %s - %s", entry.AssetTag, entry.ItemName)
	if err := s.insertLedgerEntryIfMissingTx(tx, companyID, fmt.Sprintf("asset:%d:debit:%d", entry.AssetEntryID, assetAccountID), assetAccountID, acquisitionDate, entry.TotalValue, 0, "asset", entry.AssetEntryID, &desc, userID); err != nil {
		return nil, err
	}
	if err := s.insertLedgerEntryIfMissingTx(tx, companyID, fmt.Sprintf("asset:%d:credit:%d", entry.AssetEntryID, *offsetAccountID), *offsetAccountID, acquisitionDate, 0, entry.TotalValue, "asset", entry.AssetEntryID, &desc, userID); err != nil {
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit asset entry: %w", err)
	}
	return &entry, nil
}

func (s *AssetConsumableService) GetAssetRegister(companyID int, locationID *int, search string) ([]models.AssetRegisterEntry, error) {
	query := `
		SELECT
			ae.asset_entry_id, ae.company_id, ae.location_id, ae.asset_tag, ae.product_id, ae.barcode_id,
			ae.category_id, ae.supplier_id, ae.item_name, ae.source_mode, ae.quantity::float8, ae.unit_cost::float8,
			ae.total_value::float8, ae.acquisition_date, ae.in_service_date, ae.status, ae.offset_account_id,
			coa.account_code, coa.name, ae.notes, ae.serial_numbers, ae.batch_allocations, ac.name, p.name, sup.name,
			ae.created_by, ae.created_at
		FROM asset_register_entries ae
		LEFT JOIN asset_categories ac ON ac.category_id = ae.category_id
		LEFT JOIN products p ON p.product_id = ae.product_id
		LEFT JOIN suppliers sup ON sup.supplier_id = ae.supplier_id
		LEFT JOIN chart_of_accounts coa ON coa.account_id = ae.offset_account_id
		WHERE ae.company_id = $1
	`
	args := []interface{}{companyID}
	arg := 2
	if locationID != nil && *locationID > 0 {
		query += fmt.Sprintf(" AND ae.location_id = $%d", arg)
		args = append(args, *locationID)
		arg++
	}
	if trimmed := strings.TrimSpace(search); trimmed != "" {
		query += fmt.Sprintf(" AND (ae.asset_tag ILIKE $%d OR ae.item_name ILIKE $%d OR COALESCE(p.name, '') ILIKE $%d OR COALESCE(sup.name, '') ILIKE $%d)", arg, arg, arg, arg)
		args = append(args, "%"+trimmed+"%")
		arg++
	}
	query += " ORDER BY ae.acquisition_date DESC, ae.asset_entry_id DESC"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get asset register: %w", err)
	}
	defer rows.Close()

	items := make([]models.AssetRegisterEntry, 0)
	for rows.Next() {
		var item models.AssetRegisterEntry
		var batchRaw []byte
		if err := rows.Scan(
			&item.AssetEntryID, &item.CompanyID, &item.LocationID, &item.AssetTag, &item.ProductID, &item.BarcodeID,
			&item.CategoryID, &item.SupplierID, &item.ItemName, &item.SourceMode, &item.Quantity, &item.UnitCost,
			&item.TotalValue, &item.AcquisitionDate, &item.InServiceDate, &item.Status, &item.OffsetAccountID,
			&item.OffsetAccountCode, &item.OffsetAccountName, &item.Notes, pq.Array(&item.SerialNumbers),
			&batchRaw, &item.CategoryName, &item.ProductName, &item.SupplierName, &item.CreatedBy, &item.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan asset register entry: %w", err)
		}
		item.BatchAllocations = decodeBatchAllocationsOrNil(batchRaw)
		items = append(items, item)
	}
	return items, nil
}

func (s *AssetConsumableService) GetAssetRegisterSummary(companyID int, locationID *int) (*models.AssetRegisterSummary, error) {
	query := `
		SELECT
			COUNT(*)::int,
			COALESCE(SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END), 0)::int,
			COALESCE(SUM(total_value), 0)::float8,
			COALESCE(AVG(unit_cost), 0)::float8
		FROM asset_register_entries
		WHERE company_id = $1
	`
	args := []interface{}{companyID}
	if locationID != nil && *locationID > 0 {
		query += " AND location_id = $2"
		args = append(args, *locationID)
	}
	var summary models.AssetRegisterSummary
	if err := s.db.QueryRow(query, args...).Scan(
		&summary.TotalItems, &summary.ActiveItems, &summary.TotalValue, &summary.AverageItemCost,
	); err != nil {
		return nil, fmt.Errorf("failed to get asset summary: %w", err)
	}
	return &summary, nil
}

func (s *AssetConsumableService) CreateConsumableEntry(companyID, locationID, userID int, req *models.CreateConsumableEntryRequest) (*models.ConsumableEntry, error) {
	consumedAt, err := parseReportOrTxnDate(req.ConsumedAt)
	if err != nil {
		return nil, err
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	trackingSvc := newInventoryTrackingService(s.db)
	expenseAccountID, err := s.consumableCategoryAccountTx(tx, companyID, req.CategoryID)
	if err != nil {
		return nil, err
	}
	entryNumber := generatedReference("CON")

	itemName := ""
	var unitCost float64
	totalCost := 0.0
	var offsetAccountID *int
	var supplierID *int
	var supplierName *string

	switch req.SourceMode {
	case "STOCK":
		if req.ProductID == nil || *req.ProductID <= 0 {
			return nil, fmt.Errorf("product_id is required for stock consumable entries")
		}
		defaultSupplierID, resolvedSupplierName, err := s.defaultNonMercantileSupplierForProductTx(tx, companyID, *req.ProductID)
		if err != nil {
			return nil, err
		}
		itemName, err = s.ensureProductItemTypeTx(tx, companyID, *req.ProductID, "CONSUMABLE")
		if err != nil {
			return nil, err
		}
		supplierID = &defaultSupplierID
		supplierName = &resolvedSupplierName
		issue, err := trackingSvc.IssueStockTx(tx, companyID, locationID, userID, "ADJUSTMENT_OUT", "consumable_entry", nil, &entryNumber, inventorySelection{
			ProductID:        *req.ProductID,
			BarcodeID:        req.BarcodeID,
			Quantity:         req.Quantity,
			SerialNumbers:    req.SerialNumbers,
			BatchAllocations: req.BatchAllocations,
			Notes:            req.Notes,
		})
		if err != nil {
			return nil, err
		}
		unitCost = issue.UnitCost
		totalCost = issue.TotalCost
	default:
		if req.ItemName == nil || strings.TrimSpace(*req.ItemName) == "" {
			return nil, fmt.Errorf("item_name is required for direct consumable entries")
		}
		if req.UnitCost == nil || *req.UnitCost < 0 {
			return nil, fmt.Errorf("unit_cost is required for direct consumable entries")
		}
		if req.OffsetAccountID == nil || *req.OffsetAccountID <= 0 {
			return nil, fmt.Errorf("offset_account_id is required for direct consumable entries")
		}
		resolvedSupplierName, err := s.validateNonMercantileSupplierTx(tx, companyID, req.SupplierID)
		if err != nil {
			return nil, err
		}
		if err := s.validateLedgerAccountTx(tx, companyID, req.OffsetAccountID); err != nil {
			return nil, err
		}
		itemName = strings.TrimSpace(*req.ItemName)
		unitCost = *req.UnitCost
		totalCost = req.Quantity * unitCost
		supplierID = req.SupplierID
		supplierName = &resolvedSupplierName
		offsetAccountID = req.OffsetAccountID
	}

	if req.SourceMode == "STOCK" {
		inventoryAccountID, err := s.ensureDefaultAccountIDTx(tx, companyID, accountCodeInventory)
		if err != nil {
			return nil, err
		}
		offsetAccountID = &inventoryAccountID
	}
	if offsetAccountID == nil || *offsetAccountID <= 0 {
		return nil, fmt.Errorf("offset account is required")
	}

	var entry models.ConsumableEntry
	var batchRaw []byte
	err = tx.QueryRow(`
		INSERT INTO consumable_entries (
			company_id, location_id, entry_number, category_id, product_id, barcode_id, item_name, source_mode,
			quantity, unit_cost, total_cost, consumed_at, supplier_id, offset_account_id, notes, serial_numbers, batch_allocations,
			created_by, updated_by
		)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$18)
		RETURNING consumption_id, company_id, location_id, entry_number, category_id, product_id, barcode_id,
		          supplier_id, item_name, source_mode, quantity::float8, unit_cost::float8, total_cost::float8, consumed_at,
		          offset_account_id, notes, serial_numbers, batch_allocations, created_by, created_at
	`, companyID, locationID, entryNumber, req.CategoryID, req.ProductID, req.BarcodeID, itemName, req.SourceMode,
		req.Quantity, unitCost, totalCost, consumedAt, supplierID, offsetAccountID, req.Notes,
		pq.Array(req.SerialNumbers), encodeBatchAllocations(req.BatchAllocations), userID).Scan(
		&entry.ConsumptionID, &entry.CompanyID, &entry.LocationID, &entry.EntryNumber, &entry.CategoryID, &entry.ProductID,
		&entry.BarcodeID, &entry.SupplierID, &entry.ItemName, &entry.SourceMode, &entry.Quantity, &entry.UnitCost, &entry.TotalCost,
		&entry.ConsumedAt, &entry.OffsetAccountID, &entry.Notes, pq.Array(&entry.SerialNumbers), &batchRaw,
		&entry.CreatedBy, &entry.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create consumable entry: %w", err)
	}
	entry.BatchAllocations = decodeBatchAllocationsOrNil(batchRaw)
	entry.SupplierName = supplierName

	desc := fmt.Sprintf("Consumable usage %s - %s", entry.EntryNumber, entry.ItemName)
	if err := s.insertLedgerEntryIfMissingTx(tx, companyID, fmt.Sprintf("consumable:%d:debit:%d", entry.ConsumptionID, expenseAccountID), expenseAccountID, consumedAt, entry.TotalCost, 0, "consumable", entry.ConsumptionID, &desc, userID); err != nil {
		return nil, err
	}
	if err := s.insertLedgerEntryIfMissingTx(tx, companyID, fmt.Sprintf("consumable:%d:credit:%d", entry.ConsumptionID, *offsetAccountID), *offsetAccountID, consumedAt, 0, entry.TotalCost, "consumable", entry.ConsumptionID, &desc, userID); err != nil {
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit consumable entry: %w", err)
	}
	return &entry, nil
}

func (s *AssetConsumableService) GetConsumableEntries(companyID int, locationID *int, search string) ([]models.ConsumableEntry, error) {
	query := `
		SELECT
			ce.consumption_id, ce.company_id, ce.location_id, ce.entry_number, ce.category_id, ce.product_id,
			ce.barcode_id, ce.supplier_id, ce.item_name, ce.source_mode, ce.quantity::float8, ce.unit_cost::float8,
			ce.total_cost::float8, ce.consumed_at, ce.offset_account_id, coa.account_code, coa.name,
			ce.notes, ce.serial_numbers, ce.batch_allocations, cc.name, p.name, sup.name, ce.created_by, ce.created_at
		FROM consumable_entries ce
		LEFT JOIN consumable_categories cc ON cc.category_id = ce.category_id
		LEFT JOIN products p ON p.product_id = ce.product_id
		LEFT JOIN suppliers sup ON sup.supplier_id = ce.supplier_id
		LEFT JOIN chart_of_accounts coa ON coa.account_id = ce.offset_account_id
		WHERE ce.company_id = $1
	`
	args := []interface{}{companyID}
	arg := 2
	if locationID != nil && *locationID > 0 {
		query += fmt.Sprintf(" AND ce.location_id = $%d", arg)
		args = append(args, *locationID)
		arg++
	}
	if trimmed := strings.TrimSpace(search); trimmed != "" {
		query += fmt.Sprintf(" AND (ce.entry_number ILIKE $%d OR ce.item_name ILIKE $%d OR COALESCE(p.name, '') ILIKE $%d OR COALESCE(sup.name, '') ILIKE $%d)", arg, arg, arg, arg)
		args = append(args, "%"+trimmed+"%")
		arg++
	}
	query += " ORDER BY ce.consumed_at DESC, ce.consumption_id DESC"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get consumable entries: %w", err)
	}
	defer rows.Close()

	items := make([]models.ConsumableEntry, 0)
	for rows.Next() {
		var item models.ConsumableEntry
		var batchRaw []byte
		if err := rows.Scan(
			&item.ConsumptionID, &item.CompanyID, &item.LocationID, &item.EntryNumber, &item.CategoryID, &item.ProductID,
			&item.BarcodeID, &item.SupplierID, &item.ItemName, &item.SourceMode, &item.Quantity, &item.UnitCost, &item.TotalCost,
			&item.ConsumedAt, &item.OffsetAccountID, &item.OffsetAccountCode, &item.OffsetAccountName, &item.Notes,
			pq.Array(&item.SerialNumbers), &batchRaw, &item.CategoryName, &item.ProductName, &item.SupplierName, &item.CreatedBy, &item.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan consumable entry: %w", err)
		}
		item.BatchAllocations = decodeBatchAllocationsOrNil(batchRaw)
		items = append(items, item)
	}
	return items, nil
}

func (s *AssetConsumableService) GetConsumableSummary(companyID int, locationID *int) (*models.ConsumableSummary, error) {
	query := `
		SELECT
			COUNT(*)::int,
			COALESCE(SUM(quantity), 0)::float8,
			COALESCE(SUM(total_cost), 0)::float8,
			COALESCE(AVG(unit_cost), 0)::float8
		FROM consumable_entries
		WHERE company_id = $1
	`
	args := []interface{}{companyID}
	if locationID != nil && *locationID > 0 {
		query += " AND location_id = $2"
		args = append(args, *locationID)
	}
	var summary models.ConsumableSummary
	if err := s.db.QueryRow(query, args...).Scan(
		&summary.TotalEntries, &summary.TotalQuantity, &summary.TotalCost, &summary.AverageUnitCost,
	); err != nil {
		return nil, fmt.Errorf("failed to get consumable summary: %w", err)
	}
	return &summary, nil
}
