package services

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"

	"erp-backend/internal/models"

	"github.com/lib/pq"
	"golang.org/x/crypto/bcrypt"
)

const (
	trackingTypeVariant = "VARIANT"
	trackingTypeSerial  = "SERIAL"
	trackingTypeBatch   = "BATCH"

	costingMethodFIFO           = "FIFO"
	costingMethodWAC            = "WAC"
	negativeStockPolicyAllow    = "ALLOW"
	negativeStockPolicyDisallow = "DONT_ALLOW"
	negativeStockPolicyApproval = "ALLOW_WITH_APPROVAL"
)

type inventorySelection struct {
	ProductID        int
	BarcodeID        *int
	Quantity         float64
	SerialNumbers    []string
	BatchAllocations []models.InventoryBatchSelectionInput
	BatchNumber      *string
	ExpiryDate       *time.Time
	UnitCost         float64
	Notes            *string
	OverridePassword *string
}

type companyInventoryPolicy struct {
	CostingMethod                     string `json:"inventory_costing_method,omitempty"`
	NegativeStockPolicy               string `json:"negative_stock_policy,omitempty"`
	NegativeStockApprovalPasswordHash string `json:"negative_stock_approval_password_hash,omitempty"`
}

type NegativeStockApprovalRequiredError struct {
	Message string
}

func (e *NegativeStockApprovalRequiredError) Error() string {
	if e == nil || strings.TrimSpace(e.Message) == "" {
		return "negative stock approval password required"
	}
	return e.Message
}

type resolvedVariant struct {
	ProductID         int
	BarcodeID         int
	Barcode           string
	VariantName       *string
	VariantAttributes models.JSONB
	TrackingType      string
	DefaultCostPrice  float64
	DefaultSellPrice  float64
}

type issueResult struct {
	BarcodeID int
	UnitCost  float64
	TotalCost float64
}

type inventoryTrackingService struct {
	db *sql.DB
}

func newInventoryTrackingService(db *sql.DB) *inventoryTrackingService {
	return &inventoryTrackingService{db: db}
}

func normalizeTrackingType(value string) string {
	switch strings.ToUpper(strings.TrimSpace(value)) {
	case trackingTypeSerial:
		return trackingTypeSerial
	case trackingTypeBatch:
		return trackingTypeBatch
	default:
		return trackingTypeVariant
	}
}

func normalizeCostingMethod(value string) string {
	switch strings.ToUpper(strings.TrimSpace(value)) {
	case costingMethodWAC:
		return costingMethodWAC
	default:
		return costingMethodFIFO
	}
}

func normalizeNegativeStockPolicy(value string) string {
	switch strings.ToUpper(strings.TrimSpace(value)) {
	case negativeStockPolicyAllow:
		return negativeStockPolicyAllow
	case negativeStockPolicyApproval:
		return negativeStockPolicyApproval
	default:
		return negativeStockPolicyDisallow
	}
}

func firstNonNilInt(values ...*int) *int {
	for _, value := range values {
		if value != nil && *value > 0 {
			return value
		}
	}
	return nil
}

func (s *inventoryTrackingService) getCompanyCostingMethodTx(tx *sql.Tx, companyID int) (string, error) {
	policy, err := s.getCompanyInventoryPolicyTx(tx, companyID)
	if err != nil {
		return "", err
	}
	return policy.CostingMethod, nil
}

func (s *inventoryTrackingService) getCompanyInventoryPolicyTx(tx *sql.Tx, companyID int) (*companyInventoryPolicy, error) {
	var raw models.JSONB
	err := tx.QueryRow(`SELECT value FROM settings WHERE company_id = $1 AND key = 'inventory'`, companyID).Scan(&raw)
	if err != nil && err != sql.ErrNoRows {
		return nil, fmt.Errorf("failed to get inventory settings: %w", err)
	}
	policy := &companyInventoryPolicy{
		CostingMethod:       costingMethodFIFO,
		NegativeStockPolicy: negativeStockPolicyDisallow,
	}
	if err == nil {
		if value, ok := raw["inventory_costing_method"].(string); ok {
			policy.CostingMethod = normalizeCostingMethod(value)
		}
		if value, ok := raw["negative_stock_policy"].(string); ok {
			policy.NegativeStockPolicy = normalizeNegativeStockPolicy(value)
		}
		if value, ok := raw["negative_stock_approval_password_hash"].(string); ok {
			policy.NegativeStockApprovalPasswordHash = strings.TrimSpace(value)
		}
	}

	var legacy models.JSONB
	if err := tx.QueryRow(`SELECT value FROM settings WHERE company_id = $1 AND key = 'company'`, companyID).Scan(&legacy); err != nil && err != sql.ErrNoRows {
		return nil, fmt.Errorf("failed to get company settings: %w", err)
	} else if err == nil && policy.CostingMethod == costingMethodFIFO {
		if value, ok := legacy["inventory_costing_method"].(string); ok {
			policy.CostingMethod = normalizeCostingMethod(value)
		}
	}
	return policy, nil
}

func (s *inventoryTrackingService) validateNegativeStockPolicyTx(tx *sql.Tx, companyID int, overridePassword *string) error {
	policy, err := s.getCompanyInventoryPolicyTx(tx, companyID)
	if err != nil {
		return err
	}
	switch policy.NegativeStockPolicy {
	case negativeStockPolicyAllow:
		return nil
	case negativeStockPolicyApproval:
		password := ""
		if overridePassword != nil {
			password = strings.TrimSpace(*overridePassword)
		}
		if password == "" {
			return &NegativeStockApprovalRequiredError{Message: "negative stock approval password required"}
		}
		if strings.TrimSpace(policy.NegativeStockApprovalPasswordHash) == "" {
			return fmt.Errorf("negative stock approval password is not configured")
		}
		if err := bcrypt.CompareHashAndPassword([]byte(policy.NegativeStockApprovalPasswordHash), []byte(password)); err != nil {
			return fmt.Errorf("invalid negative stock approval password")
		}
		return nil
	default:
		return fmt.Errorf("insufficient stock")
	}
}

func (s *inventoryTrackingService) resolveVariantTx(tx *sql.Tx, companyID, productID int, barcodeID *int) (*resolvedVariant, error) {
	args := []interface{}{companyID, productID}
	query := `
		SELECT
			p.product_id,
			pb.barcode_id,
			pb.barcode,
			pb.variant_name,
			COALESCE(pb.variant_attributes, '{}'::jsonb),
			COALESCE(p.tracking_type, CASE WHEN COALESCE(p.is_serialized, FALSE) THEN 'SERIAL' ELSE 'VARIANT' END),
			COALESCE(pb.cost_price, p.cost_price, 0)::float8,
			COALESCE(pb.selling_price, p.selling_price, 0)::float8
		FROM products p
		JOIN product_barcodes pb ON pb.product_id = p.product_id
		WHERE p.company_id = $1
		  AND p.product_id = $2
		  AND p.is_deleted = FALSE
		  AND COALESCE(pb.is_active, TRUE) = TRUE
	`
	if barcodeID != nil {
		query += " AND pb.barcode_id = $3"
		args = append(args, *barcodeID)
	} else {
		query += " ORDER BY pb.is_primary DESC, pb.barcode_id LIMIT 1"
	}

	var result resolvedVariant
	if err := tx.QueryRow(query, args...).Scan(
		&result.ProductID,
		&result.BarcodeID,
		&result.Barcode,
		&result.VariantName,
		&result.VariantAttributes,
		&result.TrackingType,
		&result.DefaultCostPrice,
		&result.DefaultSellPrice,
	); err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("product variation not found")
		}
		return nil, fmt.Errorf("failed to resolve product variation: %w", err)
	}
	result.TrackingType = normalizeTrackingType(result.TrackingType)
	return &result, nil
}

func (s *inventoryTrackingService) ensureVariantBalanceTx(tx *sql.Tx, locationID int, variant *resolvedVariant) error {
	_, err := tx.Exec(`
		INSERT INTO stock_variants (location_id, product_id, barcode_id, quantity, reserved_quantity, average_cost, last_updated)
		VALUES ($1, $2, $3, 0, 0, $4, CURRENT_TIMESTAMP)
		ON CONFLICT (location_id, barcode_id) DO NOTHING
	`, locationID, variant.ProductID, variant.BarcodeID, variant.DefaultCostPrice)
	return err
}

func (s *inventoryTrackingService) adjustVariantBalanceTx(tx *sql.Tx, companyID, locationID int, variant *resolvedVariant, quantityDelta, inboundUnitCost float64, overridePassword *string) (float64, float64, error) {
	if err := s.ensureVariantBalanceTx(tx, locationID, variant); err != nil {
		return 0, 0, fmt.Errorf("failed to initialize stock balance: %w", err)
	}

	var currentQty float64
	var currentAvg float64
	err := tx.QueryRow(`
		SELECT quantity::float8, average_cost::float8
		FROM stock_variants
		WHERE location_id = $1 AND barcode_id = $2
		FOR UPDATE
	`, locationID, variant.BarcodeID).Scan(&currentQty, &currentAvg)
	if err != nil {
		return 0, 0, fmt.Errorf("failed to lock stock balance: %w", err)
	}

	newQty := currentQty + quantityDelta
	if newQty < -1e-9 {
		if err := s.validateNegativeStockPolicyTx(tx, companyID, overridePassword); err != nil {
			if _, ok := err.(*NegativeStockApprovalRequiredError); ok {
				return 0, 0, err
			}
			if err.Error() == "insufficient stock" {
				return 0, 0, fmt.Errorf("insufficient stock for variation %d", variant.BarcodeID)
			}
			return 0, 0, err
		}
	}
	if newQty < 0 {
		if newQty > -1e-9 {
			newQty = 0
		}
	}

	newAvg := currentAvg
	if quantityDelta > 0 {
		totalCost := (currentQty * currentAvg) + (quantityDelta * inboundUnitCost)
		if newQty > 0 {
			newAvg = totalCost / newQty
		} else {
			newAvg = inboundUnitCost
		}
	}

	if _, err := tx.Exec(`
		UPDATE stock_variants
		SET quantity = $1,
		    average_cost = $2,
		    last_updated = CURRENT_TIMESTAMP
		WHERE location_id = $3 AND barcode_id = $4
	`, newQty, newAvg, locationID, variant.BarcodeID); err != nil {
		return 0, 0, fmt.Errorf("failed to update stock balance: %w", err)
	}

	if _, err := tx.Exec(`
		INSERT INTO stock (location_id, product_id, quantity, last_updated)
		SELECT $1, $2, COALESCE(SUM(quantity), 0), CURRENT_TIMESTAMP
		FROM stock_variants
		WHERE location_id = $1 AND product_id = $2
		ON CONFLICT (location_id, product_id)
		DO UPDATE SET quantity = EXCLUDED.quantity, last_updated = CURRENT_TIMESTAMP
	`, locationID, variant.ProductID); err != nil {
		return 0, 0, fmt.Errorf("failed to sync aggregate stock: %w", err)
	}

	return newQty, newAvg, nil
}

func (s *inventoryTrackingService) updateProductCostSnapshotTx(tx *sql.Tx, companyID, productID int) error {
	_, err := tx.Exec(`
		WITH variant_cost AS (
			SELECT
				sv.product_id,
				CASE
					WHEN SUM(sv.quantity) > 0 THEN SUM(sv.quantity * sv.average_cost) / SUM(sv.quantity)
					ELSE 0
				END AS avg_cost
			FROM stock_variants sv
			JOIN locations l ON l.location_id = sv.location_id
			WHERE l.company_id = $1
			  AND sv.product_id = $2
			GROUP BY sv.product_id
		)
		UPDATE products p
		SET cost_price = vc.avg_cost,
		    updated_at = CURRENT_TIMESTAMP
		FROM variant_cost vc
		WHERE p.product_id = vc.product_id
		  AND p.company_id = $1
	`, companyID, productID)
	return err
}

func (s *inventoryTrackingService) createLotTx(tx *sql.Tx, companyID, locationID int, variant *resolvedVariant, selection inventorySelection) (int, error) {
	receivedDate := time.Now().UTC().Format("2006-01-02")
	var lotID int
	err := tx.QueryRow(`
		INSERT INTO stock_lots (
			product_id, location_id, supplier_id, purchase_id, goods_receipt_id,
			quantity, remaining_quantity, cost_price, received_date,
			expiry_date, batch_number, serial_numbers, company_id, barcode_id
		)
		VALUES ($1, $2, NULL, NULL, NULL, $3, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING lot_id
	`, variant.ProductID, locationID, selection.Quantity, selection.UnitCost, receivedDate, selection.ExpiryDate,
		selection.BatchNumber, pq.Array(selection.SerialNumbers), companyID, variant.BarcodeID,
	).Scan(&lotID)
	if err != nil {
		return 0, fmt.Errorf("failed to create stock lot: %w", err)
	}
	return lotID, nil
}

func (s *inventoryTrackingService) createSerialsTx(tx *sql.Tx, companyID, locationID int, variant *resolvedVariant, lotID int, serialNumbers []string, unitCost float64) (map[string]int, error) {
	result := make(map[string]int, len(serialNumbers))
	for _, serial := range serialNumbers {
		serial = strings.TrimSpace(serial)
		if serial == "" {
			return nil, fmt.Errorf("serial numbers cannot be empty")
		}
		var productSerialID int
		err := tx.QueryRow(`
			INSERT INTO product_serials (
				company_id, product_id, barcode_id, stock_lot_id, serial_number, location_id, status, cost_price, received_at, last_movement_at
			)
			VALUES ($1, $2, $3, $4, $5, $6, 'IN_STOCK', $7, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
			RETURNING product_serial_id
		`, companyID, variant.ProductID, variant.BarcodeID, lotID, serial, locationID, unitCost).Scan(&productSerialID)
		if err != nil {
			return nil, fmt.Errorf("failed to create serial '%s': %w", serial, err)
		}
		result[serial] = productSerialID
	}
	return result, nil
}

func (s *inventoryTrackingService) createMovementTx(tx *sql.Tx, companyID, locationID int, variant *resolvedVariant, movementType, sourceType string, sourceLineID *int, sourceRef *string, lotID, serialID *int, quantity, unitCost float64, userID int, notes *string) error {
	totalCost := quantity * unitCost
	_, err := tx.Exec(`
		INSERT INTO inventory_movements (
			company_id, location_id, product_id, barcode_id, stock_lot_id, product_serial_id,
			movement_type, source_type, source_line_id, source_ref, quantity, unit_cost, total_cost, notes, created_by, occurred_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, CURRENT_TIMESTAMP)
	`, companyID, locationID, variant.ProductID, variant.BarcodeID, lotID, serialID, movementType, sourceType, sourceLineID, sourceRef, quantity, unitCost, totalCost, notes, userID)
	if err != nil {
		return fmt.Errorf("failed to create inventory movement: %w", err)
	}
	return nil
}

func (s *inventoryTrackingService) ReceiveStockTx(tx *sql.Tx, companyID, locationID, userID int, movementType, sourceType string, sourceLineID *int, sourceRef *string, selection inventorySelection) (*resolvedVariant, error) {
	variant, err := s.resolveVariantTx(tx, companyID, selection.ProductID, selection.BarcodeID)
	if err != nil {
		return nil, err
	}

	if selection.Quantity <= 0 {
		return nil, fmt.Errorf("quantity must be greater than zero")
	}

	if variant.TrackingType == trackingTypeSerial {
		if selection.Quantity != float64(int(selection.Quantity)) {
			return nil, fmt.Errorf("serialized quantities must be whole numbers")
		}
		if len(selection.SerialNumbers) != int(selection.Quantity) {
			return nil, fmt.Errorf("serial numbers count must equal quantity")
		}
	}

	if variant.TrackingType == trackingTypeBatch && (selection.BatchNumber == nil || strings.TrimSpace(*selection.BatchNumber) == "") {
		autoBatch := fmt.Sprintf("%s-%d", time.Now().UTC().Format("20060102"), variant.BarcodeID)
		selection.BatchNumber = &autoBatch
	}

	if _, _, err := s.adjustVariantBalanceTx(tx, companyID, locationID, variant, selection.Quantity, selection.UnitCost, nil); err != nil {
		return nil, err
	}

	lotID, err := s.createLotTx(tx, companyID, locationID, variant, selection)
	if err != nil {
		return nil, err
	}

	serialIDs := map[string]int{}
	if len(selection.SerialNumbers) > 0 {
		serialIDs, err = s.createSerialsTx(tx, companyID, locationID, variant, lotID, selection.SerialNumbers, selection.UnitCost)
		if err != nil {
			return nil, err
		}
	}

	if len(selection.SerialNumbers) > 0 {
		for _, serial := range selection.SerialNumbers {
			serialID := serialIDs[serial]
			if err := s.createMovementTx(tx, companyID, locationID, variant, movementType, sourceType, sourceLineID, sourceRef, &lotID, &serialID, 1, selection.UnitCost, userID, selection.Notes); err != nil {
				return nil, err
			}
		}
	} else {
		if err := s.createMovementTx(tx, companyID, locationID, variant, movementType, sourceType, sourceLineID, sourceRef, &lotID, nil, selection.Quantity, selection.UnitCost, userID, selection.Notes); err != nil {
			return nil, err
		}
	}

	if err := s.updateProductCostSnapshotTx(tx, companyID, variant.ProductID); err != nil {
		return nil, fmt.Errorf("failed to update product cost snapshot: %w", err)
	}
	return variant, nil
}

type availableLot struct {
	LotID             int
	RemainingQuantity float64
	CostPrice         float64
	ReceivedDate      time.Time
}

func (s *inventoryTrackingService) loadAvailableLotsTx(tx *sql.Tx, companyID, locationID int, variant *resolvedVariant) ([]availableLot, error) {
	rows, err := tx.Query(`
		SELECT lot_id, remaining_quantity::float8, cost_price::float8, received_date
		FROM stock_lots
		WHERE company_id = $1
		  AND location_id = $2
		  AND product_id = $3
		  AND barcode_id = $4
		  AND remaining_quantity > 0
		ORDER BY received_date, expiry_date NULLS LAST, lot_id
	`, companyID, locationID, variant.ProductID, variant.BarcodeID)
	if err != nil {
		return nil, fmt.Errorf("failed to load stock lots: %w", err)
	}
	defer rows.Close()

	lots := make([]availableLot, 0)
	for rows.Next() {
		var lot availableLot
		if err := rows.Scan(&lot.LotID, &lot.RemainingQuantity, &lot.CostPrice, &lot.ReceivedDate); err != nil {
			return nil, fmt.Errorf("failed to scan stock lot: %w", err)
		}
		lots = append(lots, lot)
	}
	return lots, nil
}

func (s *inventoryTrackingService) consumeLotTx(tx *sql.Tx, lotID int, quantity float64) error {
	res, err := tx.Exec(`
		UPDATE stock_lots
		SET remaining_quantity = remaining_quantity - $1
		WHERE lot_id = $2
		  AND remaining_quantity >= $1
	`, quantity, lotID)
	if err != nil {
		return fmt.Errorf("failed to consume stock lot: %w", err)
	}
	rows, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to read stock lot result: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("insufficient quantity in selected batch")
	}
	return nil
}

type serialRecord struct {
	ProductSerialID int
	StockLotID      *int
	CostPrice       float64
	SerialNumber    string
}

func (s *inventoryTrackingService) loadSerialsForIssueTx(tx *sql.Tx, companyID, locationID int, variant *resolvedVariant, serialNumbers []string) ([]serialRecord, error) {
	rows, err := tx.Query(`
		SELECT product_serial_id, stock_lot_id, cost_price::float8, serial_number
		FROM product_serials
		WHERE company_id = $1
		  AND location_id = $2
		  AND product_id = $3
		  AND barcode_id = $4
		  AND status = 'IN_STOCK'
		  AND serial_number = ANY($5)
		FOR UPDATE
	`, companyID, locationID, variant.ProductID, variant.BarcodeID, pq.Array(serialNumbers))
	if err != nil {
		return nil, fmt.Errorf("failed to load serial numbers: %w", err)
	}
	defer rows.Close()

	records := make([]serialRecord, 0, len(serialNumbers))
	for rows.Next() {
		var rec serialRecord
		if err := rows.Scan(&rec.ProductSerialID, &rec.StockLotID, &rec.CostPrice, &rec.SerialNumber); err != nil {
			return nil, fmt.Errorf("failed to scan serial: %w", err)
		}
		records = append(records, rec)
	}
	if len(records) != len(serialNumbers) {
		return nil, fmt.Errorf("one or more serial numbers are unavailable")
	}
	sort.Slice(records, func(i, j int) bool { return records[i].SerialNumber < records[j].SerialNumber })
	return records, nil
}

func (s *inventoryTrackingService) loadSerialsForTransferReceiveTx(tx *sql.Tx, companyID int, variant *resolvedVariant, serialNumbers []string) ([]serialRecord, error) {
	rows, err := tx.Query(`
		SELECT product_serial_id, stock_lot_id, cost_price::float8, serial_number
		FROM product_serials
		WHERE company_id = $1
		  AND product_id = $2
		  AND barcode_id = $3
		  AND status = 'TRANSFER_IN_TRANSIT'
		  AND serial_number = ANY($4)
		FOR UPDATE
	`, companyID, variant.ProductID, variant.BarcodeID, pq.Array(serialNumbers))
	if err != nil {
		return nil, fmt.Errorf("failed to load transfer serial numbers: %w", err)
	}
	defer rows.Close()

	records := make([]serialRecord, 0, len(serialNumbers))
	for rows.Next() {
		var rec serialRecord
		if err := rows.Scan(&rec.ProductSerialID, &rec.StockLotID, &rec.CostPrice, &rec.SerialNumber); err != nil {
			return nil, fmt.Errorf("failed to scan transfer serial: %w", err)
		}
		records = append(records, rec)
	}
	if len(records) != len(serialNumbers) {
		return nil, fmt.Errorf("one or more serial numbers are unavailable in transit")
	}
	sort.Slice(records, func(i, j int) bool { return records[i].SerialNumber < records[j].SerialNumber })
	return records, nil
}

func (s *inventoryTrackingService) markSerialStatusTx(tx *sql.Tx, serialID int, status string, locationID *int) error {
	_, err := tx.Exec(`
		UPDATE product_serials
		SET status = $1,
		    location_id = $2,
		    sold_at = CASE WHEN $1 = 'SOLD' THEN CURRENT_TIMESTAMP ELSE sold_at END,
		    last_movement_at = CURRENT_TIMESTAMP
		WHERE product_serial_id = $3
	`, status, locationID, serialID)
	return err
}

func (s *inventoryTrackingService) IssueStockTx(tx *sql.Tx, companyID, locationID, userID int, movementType, sourceType string, sourceLineID *int, sourceRef *string, selection inventorySelection) (*issueResult, error) {
	variant, err := s.resolveVariantTx(tx, companyID, selection.ProductID, selection.BarcodeID)
	if err != nil {
		return nil, err
	}

	method, err := s.getCompanyCostingMethodTx(tx, companyID)
	if err != nil {
		return nil, err
	}

	if selection.Quantity <= 0 {
		return nil, fmt.Errorf("quantity must be greater than zero")
	}

	totalCost := 0.0
	totalQty := selection.Quantity

	if variant.TrackingType == trackingTypeSerial {
		if selection.Quantity != float64(int(selection.Quantity)) {
			return nil, fmt.Errorf("serialized quantities must be whole numbers")
		}
		if len(selection.SerialNumbers) != int(selection.Quantity) {
			return nil, fmt.Errorf("serial numbers count must equal quantity")
		}
		records, err := s.loadSerialsForIssueTx(tx, companyID, locationID, variant, selection.SerialNumbers)
		if err != nil {
			return nil, err
		}
		for _, rec := range records {
			if rec.StockLotID != nil {
				if err := s.consumeLotTx(tx, *rec.StockLotID, 1); err != nil {
					return nil, err
				}
			}
			if err := s.markSerialStatusTx(tx, rec.ProductSerialID, serialStatusForMovement(movementType), nil); err != nil {
				return nil, fmt.Errorf("failed to update serial status: %w", err)
			}
			if err := s.createMovementTx(tx, companyID, locationID, variant, movementType, sourceType, sourceLineID, sourceRef, rec.StockLotID, &rec.ProductSerialID, -1, rec.CostPrice, userID, selection.Notes); err != nil {
				return nil, err
			}
			totalCost += rec.CostPrice
		}
	} else {
		lots, err := s.loadAvailableLotsTx(tx, companyID, locationID, variant)
		if err != nil {
			return nil, err
		}

		avgCost := variant.DefaultCostPrice
		if err := tx.QueryRow(`
			SELECT COALESCE(average_cost, 0)::float8
			FROM stock_variants
			WHERE location_id = $1 AND barcode_id = $2
		`, locationID, variant.BarcodeID).Scan(&avgCost); err != nil && err != sql.ErrNoRows {
			return nil, fmt.Errorf("failed to get average cost: %w", err)
		}

		remaining := selection.Quantity
		if len(selection.BatchAllocations) > 0 {
			for _, alloc := range selection.BatchAllocations {
				if remaining < alloc.Quantity-1e-9 {
					return nil, fmt.Errorf("batch allocations exceed requested quantity")
				}
				lotCost := avgCost
				found := false
				for _, lot := range lots {
					if lot.LotID == alloc.LotID {
						lotCost = lot.CostPrice
						found = true
						break
					}
				}
				if !found {
					return nil, fmt.Errorf("selected batch not found")
				}
				if err := s.consumeLotTx(tx, alloc.LotID, alloc.Quantity); err != nil {
					return nil, err
				}
				unitCost := lotCost
				if method == costingMethodWAC {
					unitCost = avgCost
				}
				if err := s.createMovementTx(tx, companyID, locationID, variant, movementType, sourceType, sourceLineID, sourceRef, &alloc.LotID, nil, -alloc.Quantity, unitCost, userID, selection.Notes); err != nil {
					return nil, err
				}
				totalCost += alloc.Quantity * unitCost
				remaining -= alloc.Quantity
			}
			if remaining > 1e-9 {
				return nil, fmt.Errorf("batch allocations do not cover requested quantity")
			}
		} else {
			if variant.TrackingType == trackingTypeBatch {
				return nil, fmt.Errorf("batch selection is required")
			}
			for _, lot := range lots {
				if remaining <= 1e-9 {
					break
				}
				consumeQty := lot.RemainingQuantity
				if consumeQty > remaining {
					consumeQty = remaining
				}
				if consumeQty <= 0 {
					continue
				}
				if err := s.consumeLotTx(tx, lot.LotID, consumeQty); err != nil {
					return nil, err
				}
				unitCost := lot.CostPrice
				if method == costingMethodWAC {
					unitCost = avgCost
				}
				if err := s.createMovementTx(tx, companyID, locationID, variant, movementType, sourceType, sourceLineID, sourceRef, &lot.LotID, nil, -consumeQty, unitCost, userID, selection.Notes); err != nil {
					return nil, err
				}
				totalCost += consumeQty * unitCost
				remaining -= consumeQty
			}
			if remaining > 1e-9 {
				if err := s.validateNegativeStockPolicyTx(tx, companyID, selection.OverridePassword); err != nil {
					if _, ok := err.(*NegativeStockApprovalRequiredError); ok {
						return nil, err
					}
					if err.Error() == "insufficient stock" || variant.TrackingType != trackingTypeVariant {
						return nil, fmt.Errorf("insufficient stock")
					}
					return nil, err
				}
				if variant.TrackingType != trackingTypeVariant {
					return nil, fmt.Errorf("insufficient stock")
				}
				unitCost := avgCost
				if unitCost <= 0 {
					unitCost = variant.DefaultCostPrice
				}
				if err := s.createMovementTx(tx, companyID, locationID, variant, movementType, sourceType, sourceLineID, sourceRef, nil, nil, -remaining, unitCost, userID, selection.Notes); err != nil {
					return nil, err
				}
				totalCost += remaining * unitCost
			}
		}
	}

	if _, _, err := s.adjustVariantBalanceTx(tx, companyID, locationID, variant, -selection.Quantity, 0, selection.OverridePassword); err != nil {
		return nil, err
	}
	if err := s.updateProductCostSnapshotTx(tx, companyID, variant.ProductID); err != nil {
		return nil, fmt.Errorf("failed to update product cost snapshot: %w", err)
	}

	unitCost := 0.0
	if totalQty > 0 {
		unitCost = totalCost / totalQty
	}
	return &issueResult{
		BarcodeID: variant.BarcodeID,
		UnitCost:  unitCost,
		TotalCost: totalCost,
	}, nil
}

func serialStatusForMovement(movementType string) string {
	switch strings.ToUpper(strings.TrimSpace(movementType)) {
	case "TRANSFER_OUT":
		return "TRANSFER_IN_TRANSIT"
	case "PURCHASE_RETURN", "ADJUSTMENT_OUT":
		return "ADJUSTED_OUT"
	default:
		return "SOLD"
	}
}

func marshalVariantAttributes(input map[string]string) models.JSONB {
	if len(input) == 0 {
		return models.JSONB{}
	}
	output := make(models.JSONB, len(input))
	for k, v := range input {
		output[k] = v
	}
	return output
}

func normalizeVariantAttributes(raw models.JSONB) models.JSONB {
	if raw == nil {
		return models.JSONB{}
	}
	b, err := json.Marshal(raw)
	if err != nil {
		return models.JSONB{}
	}
	var normalized models.JSONB
	if err := json.Unmarshal(b, &normalized); err != nil {
		return models.JSONB{}
	}
	return normalized
}
