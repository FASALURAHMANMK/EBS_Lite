package services

import (
	"database/sql"
	"fmt"
	"strings"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type ProductStorageService struct {
	db *sql.DB
}

func NewProductStorageService() *ProductStorageService {
	return &ProductStorageService{db: database.GetDB()}
}

func (s *ProductStorageService) GetAssignments(productID, companyID int, locationID *int) ([]models.ProductStorageAssignment, error) {
	args := []interface{}{productID, companyID}
	query := `
		SELECT psa.storage_assignment_id, psa.product_id, psa.location_id, psa.barcode_id,
		       psa.storage_type, psa.storage_label, psa.notes, psa.is_primary, psa.sort_order,
		       l.name, pb.barcode, pb.variant_name
		FROM product_storage_assignments psa
		JOIN products p ON p.product_id = psa.product_id
		JOIN locations l ON l.location_id = psa.location_id
		JOIN product_barcodes pb ON pb.barcode_id = psa.barcode_id
		WHERE psa.product_id = $1 AND p.company_id = $2 AND p.is_deleted = FALSE
	`
	if locationID != nil && *locationID > 0 {
		args = append(args, *locationID)
		query += fmt.Sprintf(" AND psa.location_id = $%d", len(args))
	}
	query += " ORDER BY psa.location_id, psa.is_primary DESC, psa.sort_order, psa.storage_assignment_id"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to load storage assignments: %w", err)
	}
	defer rows.Close()

	assignments := make([]models.ProductStorageAssignment, 0)
	for rows.Next() {
		var item models.ProductStorageAssignment
		if err := rows.Scan(
			&item.StorageAssignmentID, &item.ProductID, &item.LocationID, &item.BarcodeID,
			&item.StorageType, &item.StorageLabel, &item.Notes, &item.IsPrimary, &item.SortOrder,
			&item.LocationName, &item.Barcode, &item.VariantName,
		); err != nil {
			return nil, fmt.Errorf("failed to scan storage assignment: %w", err)
		}
		assignments = append(assignments, item)
	}
	return assignments, nil
}

func (s *ProductStorageService) ReplaceAssignments(productID, companyID, locationID int, req *models.ReplaceProductStorageAssignmentsRequest) ([]models.ProductStorageAssignment, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	if err := s.validateProductLocationTx(tx, productID, companyID, locationID); err != nil {
		return nil, err
	}
	barcodeByCode, err := s.loadProductBarcodesTx(tx, productID)
	if err != nil {
		return nil, err
	}
	barcodeLookup := make(map[string]int, len(barcodeByCode))
	barcodeByID := make(map[int]struct{}, len(barcodeByCode))
	for _, item := range barcodeByCode {
		barcodeLookup[strings.ToLower(strings.TrimSpace(item.Barcode))] = item.BarcodeID
		barcodeByID[item.BarcodeID] = struct{}{}
	}

	primaryCount := 0
	for _, assignment := range req.Assignments {
		if strings.TrimSpace(assignment.StorageType) == "" || strings.TrimSpace(assignment.StorageLabel) == "" {
			return nil, fmt.Errorf("storage type and label are required")
		}
		resolvedBarcodeID := 0
		if assignment.BarcodeID != nil && *assignment.BarcodeID > 0 {
			if _, ok := barcodeByID[*assignment.BarcodeID]; !ok {
				return nil, fmt.Errorf("storage assignment barcode does not belong to product")
			}
			resolvedBarcodeID = *assignment.BarcodeID
		} else if assignment.Barcode != nil && strings.TrimSpace(*assignment.Barcode) != "" {
			if id, ok := barcodeLookup[strings.ToLower(strings.TrimSpace(*assignment.Barcode))]; ok {
				resolvedBarcodeID = id
			}
		}
		if resolvedBarcodeID == 0 {
			return nil, fmt.Errorf("each storage assignment must target a product variation")
		}
		if assignment.IsPrimary {
			primaryCount++
		}
	}
	if primaryCount > 1 {
		return nil, fmt.Errorf("only one primary storage assignment is allowed per location")
	}

	if _, err := tx.Exec(`DELETE FROM product_storage_assignments WHERE product_id = $1 AND location_id = $2`, productID, locationID); err != nil {
		return nil, fmt.Errorf("failed to clear storage assignments: %w", err)
	}

	for index, assignment := range req.Assignments {
		resolvedBarcodeID := 0
		if assignment.BarcodeID != nil && *assignment.BarcodeID > 0 {
			resolvedBarcodeID = *assignment.BarcodeID
		} else if assignment.Barcode != nil {
			resolvedBarcodeID = barcodeLookup[strings.ToLower(strings.TrimSpace(*assignment.Barcode))]
		}
		sortOrder := assignment.SortOrder
		if sortOrder == 0 {
			sortOrder = index + 1
		}
		if _, err := tx.Exec(`
			INSERT INTO product_storage_assignments (
				product_id, location_id, barcode_id, storage_type, storage_label, notes, is_primary, sort_order
			) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		`, productID, locationID, resolvedBarcodeID, strings.TrimSpace(assignment.StorageType), strings.TrimSpace(assignment.StorageLabel),
			normalizeOptionalString(assignment.Notes), assignment.IsPrimary, sortOrder,
		); err != nil {
			return nil, fmt.Errorf("failed to save storage assignment: %w", err)
		}
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit storage assignments: %w", err)
	}
	return s.GetAssignments(productID, companyID, &locationID)
}

func (s *ProductStorageService) validateProductLocationTx(tx *sql.Tx, productID, companyID, locationID int) error {
	var ok bool
	if err := tx.QueryRow(`SELECT EXISTS(SELECT 1 FROM products WHERE product_id = $1 AND company_id = $2 AND is_deleted = FALSE)`, productID, companyID).Scan(&ok); err != nil {
		return fmt.Errorf("failed to validate product: %w", err)
	}
	if !ok {
		return fmt.Errorf("product not found")
	}
	if err := tx.QueryRow(`SELECT EXISTS(SELECT 1 FROM locations WHERE location_id = $1 AND company_id = $2)`, locationID, companyID).Scan(&ok); err != nil {
		return fmt.Errorf("failed to validate location: %w", err)
	}
	if !ok {
		return fmt.Errorf("location not found")
	}
	return nil
}

func (s *ProductStorageService) loadProductBarcodesTx(tx *sql.Tx, productID int) ([]models.ProductBarcode, error) {
	rows, err := tx.Query(`
		SELECT barcode_id, product_id, barcode, pack_size, cost_price, selling_price, is_primary,
		       variant_name, COALESCE(variant_attributes, '{}'::jsonb), COALESCE(is_active, TRUE)
		FROM product_barcodes
		WHERE product_id = $1 AND COALESCE(is_active, TRUE) = TRUE
	`, productID)
	if err != nil {
		return nil, fmt.Errorf("failed to load product barcodes: %w", err)
	}
	defer rows.Close()

	items := make([]models.ProductBarcode, 0)
	for rows.Next() {
		var item models.ProductBarcode
		if err := rows.Scan(
			&item.BarcodeID, &item.ProductID, &item.Barcode, &item.PackSize, &item.CostPrice, &item.SellingPrice,
			&item.IsPrimary, &item.VariantName, &item.VariantAttributes, &item.IsActive,
		); err != nil {
			return nil, fmt.Errorf("failed to scan product barcode: %w", err)
		}
		items = append(items, item)
	}
	return items, nil
}
