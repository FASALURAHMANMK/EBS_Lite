package services

import (
	"database/sql"
	"fmt"
	"math"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"

	"github.com/lib/pq"
)

type WarrantyService struct {
	db *sql.DB
}

type warrantySaleContext struct {
	SaleID          int
	SaleNumber      string
	SaleDate        time.Time
	CustomerID      *int
	CustomerName    sql.NullString
	CustomerPhone   sql.NullString
	CustomerEmail   sql.NullString
	CustomerAddress sql.NullString
}

type warrantyBaseLine struct {
	SaleDetailID         int
	ProductID            int
	BarcodeID            *int
	ProductName          string
	Barcode              *string
	VariantName          *string
	TrackingType         string
	IsSerialized         bool
	Quantity             float64
	WarrantyPeriodMonths int
	WarrantyStartDate    time.Time
	WarrantyEndDate      time.Time
}

func NewWarrantyService() *WarrantyService {
	return &WarrantyService{db: database.GetDB()}
}

func normalizeWarrantyDate(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

func approxEqual(a, b float64) bool {
	return math.Abs(a-b) <= 0.0001
}

func trimStringPtr(value *string) *string {
	if value == nil {
		return nil
	}
	trimmed := strings.TrimSpace(*value)
	if trimmed == "" {
		return nil
	}
	return &trimmed
}

func warrantyStringPtr(value string) *string {
	v := value
	return &v
}

func candidateKey(saleDetailID int, serialNumber *string, stockLotID *int) string {
	key := fmt.Sprintf("%d", saleDetailID)
	if serialNumber != nil && strings.TrimSpace(*serialNumber) != "" {
		return key + "|serial:" + strings.TrimSpace(*serialNumber)
	}
	if stockLotID != nil && *stockLotID > 0 {
		return fmt.Sprintf("%s|lot:%d", key, *stockLotID)
	}
	return key + "|line"
}

func nullStringPtr(value sql.NullString) *string {
	if !value.Valid {
		return nil
	}
	return warrantyStringPtr(value.String)
}

func (s *WarrantyService) resolveSaleByNumber(companyID int, saleNumber string) (*warrantySaleContext, error) {
	query := `
		SELECT s.sale_id, s.sale_number, s.sale_date, s.customer_id,
		       c.name, c.phone, c.email, c.address
		FROM sales s
		JOIN locations l ON l.location_id = s.location_id
		LEFT JOIN customers c ON c.customer_id = s.customer_id
		WHERE l.company_id = $1
		  AND s.sale_number = $2
		  AND s.is_deleted = FALSE
	`

	var ctx warrantySaleContext
	if err := s.db.QueryRow(query, companyID, strings.TrimSpace(saleNumber)).Scan(
		&ctx.SaleID,
		&ctx.SaleNumber,
		&ctx.SaleDate,
		&ctx.CustomerID,
		&ctx.CustomerName,
		&ctx.CustomerPhone,
		&ctx.CustomerEmail,
		&ctx.CustomerAddress,
	); err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("sale not found")
		}
		return nil, fmt.Errorf("failed to resolve sale: %w", err)
	}

	return &ctx, nil
}

func buildWarrantyCustomerSnapshot(ctx *warrantySaleContext) *models.WarrantyCustomerSnapshot {
	if ctx == nil || !ctx.CustomerName.Valid || strings.TrimSpace(ctx.CustomerName.String) == "" {
		return nil
	}
	return &models.WarrantyCustomerSnapshot{
		CustomerID: ctx.CustomerID,
		Name:       strings.TrimSpace(ctx.CustomerName.String),
		Phone:      nullStringPtr(ctx.CustomerPhone),
		Email:      nullStringPtr(ctx.CustomerEmail),
		Address:    nullStringPtr(ctx.CustomerAddress),
	}
}

func (s *WarrantyService) loadWarrantyBaseLines(companyID, saleID int, saleDate time.Time) (map[int]warrantyBaseLine, error) {
	query := `
		SELECT sd.sale_detail_id, sd.product_id, sd.barcode_id,
		       COALESCE(sd.product_name, p.name) AS product_name,
		       pb.barcode, pb.variant_name,
		       COALESCE(p.tracking_type, 'VARIANT') AS tracking_type,
		       CASE
		         WHEN COALESCE(p.is_serialized, FALSE) OR COALESCE(p.tracking_type, '') = 'SERIAL' THEN TRUE
		         ELSE FALSE
		       END AS is_serialized,
		       sd.quantity::float8,
		       p.warranty_period_months
		FROM sale_details sd
		JOIN products p ON p.product_id = sd.product_id
		LEFT JOIN product_barcodes pb ON pb.barcode_id = sd.barcode_id
		WHERE sd.sale_id = $1
		  AND p.company_id = $2
		  AND p.is_deleted = FALSE
		  AND COALESCE(p.has_warranty, FALSE) = TRUE
		  AND p.warranty_period_months IS NOT NULL
		ORDER BY sd.sale_detail_id
	`

	rows, err := s.db.Query(query, saleID, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to load warranty-eligible sale lines: %w", err)
	}
	defer rows.Close()

	startDate := normalizeWarrantyDate(saleDate)
	lines := make(map[int]warrantyBaseLine)
	for rows.Next() {
		var line warrantyBaseLine
		if err := rows.Scan(
			&line.SaleDetailID,
			&line.ProductID,
			&line.BarcodeID,
			&line.ProductName,
			&line.Barcode,
			&line.VariantName,
			&line.TrackingType,
			&line.IsSerialized,
			&line.Quantity,
			&line.WarrantyPeriodMonths,
		); err != nil {
			return nil, fmt.Errorf("failed to scan warranty sale line: %w", err)
		}
		line.WarrantyStartDate = startDate
		line.WarrantyEndDate = startDate.AddDate(0, line.WarrantyPeriodMonths, 0)
		lines[line.SaleDetailID] = line
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read warranty sale lines: %w", err)
	}
	return lines, nil
}

func (s *WarrantyService) loadWarrantyCandidates(companyID, saleID int, saleDate time.Time) ([]models.WarrantyCandidate, error) {
	baseLines, err := s.loadWarrantyBaseLines(companyID, saleID, saleDate)
	if err != nil {
		return nil, err
	}
	if len(baseLines) == 0 {
		return []models.WarrantyCandidate{}, nil
	}

	saleDetailIDs := make([]int, 0, len(baseLines))
	for id := range baseLines {
		saleDetailIDs = append(saleDetailIDs, id)
	}

	candidates := make([]models.WarrantyCandidate, 0, len(baseLines))

	serialRows, err := s.db.Query(`
		SELECT im.source_line_id,
		       ps.serial_number,
		       sl.lot_id,
		       sl.batch_number,
		       sl.expiry_date
		FROM inventory_movements im
		JOIN product_serials ps ON ps.product_serial_id = im.product_serial_id
		LEFT JOIN stock_lots sl ON sl.lot_id = COALESCE(ps.stock_lot_id, im.stock_lot_id)
		WHERE im.source_type = 'sale_detail'
		  AND im.movement_type = 'SALE'
		  AND im.source_line_id = ANY($1)
		ORDER BY im.source_line_id, ps.serial_number
	`, pq.Array(saleDetailIDs))
	if err != nil {
		return nil, fmt.Errorf("failed to load sold serials: %w", err)
	}
	defer serialRows.Close()

	for serialRows.Next() {
		var saleDetailID int
		var serialNumber string
		var stockLotID sql.NullInt64
		var batchNumber sql.NullString
		var expiryDate sql.NullTime
		if err := serialRows.Scan(&saleDetailID, &serialNumber, &stockLotID, &batchNumber, &expiryDate); err != nil {
			return nil, fmt.Errorf("failed to scan sold serial: %w", err)
		}
		line, ok := baseLines[saleDetailID]
		if !ok || !line.IsSerialized {
			continue
		}
		candidate := models.WarrantyCandidate{
			SaleDetailID:         saleDetailID,
			ProductID:            line.ProductID,
			BarcodeID:            line.BarcodeID,
			ProductName:          line.ProductName,
			Barcode:              line.Barcode,
			VariantName:          line.VariantName,
			TrackingType:         "SERIAL",
			IsSerialized:         true,
			Quantity:             1,
			SerialNumber:         warrantyStringPtr(serialNumber),
			WarrantyPeriodMonths: line.WarrantyPeriodMonths,
			WarrantyStartDate:    line.WarrantyStartDate,
			WarrantyEndDate:      line.WarrantyEndDate,
		}
		if stockLotID.Valid {
			value := int(stockLotID.Int64)
			candidate.StockLotID = &value
		}
		if batchNumber.Valid {
			candidate.BatchNumber = warrantyStringPtr(batchNumber.String)
		}
		if expiryDate.Valid {
			date := normalizeWarrantyDate(expiryDate.Time)
			candidate.BatchExpiryDate = &date
		}
		candidates = append(candidates, candidate)
	}
	if err := serialRows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read sold serials: %w", err)
	}

	batchRows, err := s.db.Query(`
		SELECT im.source_line_id,
		       im.stock_lot_id,
		       sl.batch_number,
		       sl.expiry_date,
		       SUM(ABS(im.quantity))::float8 AS quantity
		FROM inventory_movements im
		JOIN stock_lots sl ON sl.lot_id = im.stock_lot_id
		WHERE im.source_type = 'sale_detail'
		  AND im.movement_type = 'SALE'
		  AND im.source_line_id = ANY($1)
		  AND im.stock_lot_id IS NOT NULL
		  AND im.product_serial_id IS NULL
		GROUP BY im.source_line_id, im.stock_lot_id, sl.batch_number, sl.expiry_date
		ORDER BY im.source_line_id, sl.batch_number, im.stock_lot_id
	`, pq.Array(saleDetailIDs))
	if err != nil {
		return nil, fmt.Errorf("failed to load sold batches: %w", err)
	}
	defer batchRows.Close()

	for batchRows.Next() {
		var saleDetailID int
		var stockLotID int
		var batchNumber sql.NullString
		var expiryDate sql.NullTime
		var quantity float64
		if err := batchRows.Scan(&saleDetailID, &stockLotID, &batchNumber, &expiryDate, &quantity); err != nil {
			return nil, fmt.Errorf("failed to scan sold batch: %w", err)
		}
		line, ok := baseLines[saleDetailID]
		if !ok || line.IsSerialized || line.TrackingType != "BATCH" {
			continue
		}
		candidate := models.WarrantyCandidate{
			SaleDetailID:         saleDetailID,
			ProductID:            line.ProductID,
			BarcodeID:            line.BarcodeID,
			ProductName:          line.ProductName,
			Barcode:              line.Barcode,
			VariantName:          line.VariantName,
			TrackingType:         "BATCH",
			IsSerialized:         false,
			Quantity:             quantity,
			StockLotID:           &stockLotID,
			WarrantyPeriodMonths: line.WarrantyPeriodMonths,
			WarrantyStartDate:    line.WarrantyStartDate,
			WarrantyEndDate:      line.WarrantyEndDate,
		}
		if batchNumber.Valid {
			candidate.BatchNumber = warrantyStringPtr(batchNumber.String)
		}
		if expiryDate.Valid {
			date := normalizeWarrantyDate(expiryDate.Time)
			candidate.BatchExpiryDate = &date
		}
		candidates = append(candidates, candidate)
	}
	if err := batchRows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read sold batches: %w", err)
	}

	for _, line := range baseLines {
		if line.IsSerialized || line.TrackingType == "BATCH" {
			continue
		}
		candidates = append(candidates, models.WarrantyCandidate{
			SaleDetailID:         line.SaleDetailID,
			ProductID:            line.ProductID,
			BarcodeID:            line.BarcodeID,
			ProductName:          line.ProductName,
			Barcode:              line.Barcode,
			VariantName:          line.VariantName,
			TrackingType:         "VARIANT",
			IsSerialized:         false,
			Quantity:             line.Quantity,
			WarrantyPeriodMonths: line.WarrantyPeriodMonths,
			WarrantyStartDate:    line.WarrantyStartDate,
			WarrantyEndDate:      line.WarrantyEndDate,
		})
	}

	existingRows, err := s.db.Query(`
		SELECT wi.sale_detail_id, wi.serial_number, wi.stock_lot_id
		FROM warranty_items wi
		JOIN warranty_registrations wr ON wr.warranty_id = wi.warranty_id
		WHERE wr.company_id = $1
		  AND wr.is_deleted = FALSE
		  AND wi.sale_detail_id = ANY($2)
	`, companyID, pq.Array(saleDetailIDs))
	if err != nil {
		return nil, fmt.Errorf("failed to load existing warranties: %w", err)
	}
	defer existingRows.Close()

	registered := make(map[string]struct{})
	for existingRows.Next() {
		var saleDetailID int
		var serialNumber sql.NullString
		var stockLotID sql.NullInt64
		if err := existingRows.Scan(&saleDetailID, &serialNumber, &stockLotID); err != nil {
			return nil, fmt.Errorf("failed to scan existing warranty item: %w", err)
		}
		key := candidateKey(saleDetailID, nullStringPtr(serialNumber), intPtrFromNullInt64(stockLotID))
		registered[key] = struct{}{}
	}
	if err := existingRows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read existing warranties: %w", err)
	}

	for idx := range candidates {
		_, exists := registered[candidateKey(candidates[idx].SaleDetailID, candidates[idx].SerialNumber, candidates[idx].StockLotID)]
		candidates[idx].AlreadyRegistered = exists
	}

	return candidates, nil
}

func (s *WarrantyService) PrepareWarranty(companyID int, saleNumber string) (*models.PrepareWarrantyResponse, error) {
	saleCtx, err := s.resolveSaleByNumber(companyID, saleNumber)
	if err != nil {
		return nil, err
	}

	eligibleItems, err := s.loadWarrantyCandidates(companyID, saleCtx.SaleID, saleCtx.SaleDate)
	if err != nil {
		return nil, err
	}

	existing, err := s.LookupWarranties(companyID, models.WarrantyLookupFilters{
		SaleNumber: saleCtx.SaleNumber,
	})
	if err != nil {
		return nil, err
	}

	return &models.PrepareWarrantyResponse{
		SaleID:             saleCtx.SaleID,
		SaleNumber:         saleCtx.SaleNumber,
		SaleDate:           normalizeWarrantyDate(saleCtx.SaleDate),
		InvoiceCustomer:    buildWarrantyCustomerSnapshot(saleCtx),
		EligibleItems:      eligibleItems,
		ExistingWarranties: existing,
	}, nil
}

func (s *WarrantyService) resolveWarrantyCustomer(companyID int, saleCtx *warrantySaleContext, req *models.CreateWarrantyRequest) (*models.WarrantyCustomerSnapshot, error) {
	if req.CustomerID != nil {
		query := `
			SELECT customer_id, name, phone, email, address
			FROM customers
			WHERE company_id = $1
			  AND customer_id = $2
			  AND is_deleted = FALSE
		`
		var customer models.WarrantyCustomerSnapshot
		if err := s.db.QueryRow(query, companyID, *req.CustomerID).Scan(
			&customer.CustomerID,
			&customer.Name,
			&customer.Phone,
			&customer.Email,
			&customer.Address,
		); err != nil {
			if err == sql.ErrNoRows {
				return nil, fmt.Errorf("customer not found")
			}
			return nil, fmt.Errorf("failed to load customer: %w", err)
		}
		customer.Name = strings.TrimSpace(customer.Name)
		if customer.Name == "" {
			return nil, fmt.Errorf("customer name is required")
		}
		return &customer, nil
	}

	name := trimStringPtr(req.CustomerName)
	phone := trimStringPtr(req.CustomerPhone)
	email := trimStringPtr(req.CustomerEmail)
	address := trimStringPtr(req.CustomerAddress)
	if name != nil || phone != nil || email != nil || address != nil {
		if name == nil || phone == nil {
			return nil, fmt.Errorf("customer_name and customer_phone are required for walk-in warranty registration")
		}
		return &models.WarrantyCustomerSnapshot{
			Name:    *name,
			Phone:   phone,
			Email:   email,
			Address: address,
		}, nil
	}

	if saleCustomer := buildWarrantyCustomerSnapshot(saleCtx); saleCustomer != nil {
		return saleCustomer, nil
	}

	return nil, fmt.Errorf("customer details are required")
}

func (s *WarrantyService) CreateWarranty(companyID, userID int, req *models.CreateWarrantyRequest) (*models.WarrantyRegistration, error) {
	saleCtx, err := s.resolveSaleByNumber(companyID, req.SaleNumber)
	if err != nil {
		return nil, err
	}

	candidates, err := s.loadWarrantyCandidates(companyID, saleCtx.SaleID, saleCtx.SaleDate)
	if err != nil {
		return nil, err
	}
	if len(candidates) == 0 {
		return nil, fmt.Errorf("no warranty-eligible items found for this invoice")
	}

	candidateByKey := make(map[string]models.WarrantyCandidate, len(candidates))
	for _, candidate := range candidates {
		candidateByKey[candidateKey(candidate.SaleDetailID, candidate.SerialNumber, candidate.StockLotID)] = candidate
	}

	customer, err := s.resolveWarrantyCustomer(companyID, saleCtx, req)
	if err != nil {
		return nil, err
	}

	selected := make([]models.WarrantyCandidate, 0, len(req.Items))
	for _, item := range req.Items {
		key := candidateKey(item.SaleDetailID, trimStringPtr(item.SerialNumber), item.StockLotID)
		candidate, ok := candidateByKey[key]
		if !ok {
			return nil, fmt.Errorf("selected warranty item was not found on the invoice")
		}
		if candidate.AlreadyRegistered {
			return nil, fmt.Errorf("selected warranty item is already registered")
		}
		if !approxEqual(candidate.Quantity, item.Quantity) {
			return nil, fmt.Errorf("selected warranty quantity must match the invoice quantity")
		}
		selected = append(selected, candidate)
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start warranty transaction: %w", err)
	}
	defer tx.Rollback()

	var warrantyID int
	var registeredAt time.Time
	var createdAt time.Time
	var updatedAt time.Time
	if err := tx.QueryRow(`
		INSERT INTO warranty_registrations (
			company_id, sale_id, sale_number, customer_id, customer_name, customer_phone,
			customer_email, customer_address, notes, created_by, updated_by
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $10)
		RETURNING warranty_id, registered_at, created_at, updated_at
	`, companyID, saleCtx.SaleID, saleCtx.SaleNumber, customer.CustomerID, customer.Name, customer.Phone, customer.Email, customer.Address, trimStringPtr(req.Notes), userID).Scan(
		&warrantyID,
		&registeredAt,
		&createdAt,
		&updatedAt,
	); err != nil {
		return nil, fmt.Errorf("failed to create warranty registration: %w", err)
	}

	for _, item := range selected {
		_, err := tx.Exec(`
			INSERT INTO warranty_items (
				warranty_id, sale_detail_id, product_id, barcode_id, product_name, barcode, variant_name,
				tracking_type, is_serialized, quantity, serial_number, stock_lot_id, batch_number, batch_expiry_date,
				warranty_period_months, warranty_start_date, warranty_end_date
			)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
		`, warrantyID, item.SaleDetailID, item.ProductID, item.BarcodeID, item.ProductName, item.Barcode, item.VariantName,
			item.TrackingType, item.IsSerialized, item.Quantity, item.SerialNumber, item.StockLotID, item.BatchNumber, item.BatchExpiryDate,
			item.WarrantyPeriodMonths, item.WarrantyStartDate, item.WarrantyEndDate)
		if err != nil {
			if isUniqueViolation(err) {
				return nil, fmt.Errorf("selected warranty item is already registered")
			}
			return nil, fmt.Errorf("failed to create warranty item: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit warranty registration: %w", err)
	}

	return s.GetWarrantyByID(companyID, warrantyID)
}

func (s *WarrantyService) loadWarrantyHeaders(query string, args ...interface{}) ([]models.WarrantyRegistration, error) {
	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	list := make([]models.WarrantyRegistration, 0)
	for rows.Next() {
		var item models.WarrantyRegistration
		if err := rows.Scan(
			&item.WarrantyID,
			&item.CompanyID,
			&item.SaleID,
			&item.SaleNumber,
			&item.CustomerID,
			&item.CustomerName,
			&item.CustomerPhone,
			&item.CustomerEmail,
			&item.CustomerAddress,
			&item.Notes,
			&item.RegisteredAt,
			&item.CreatedBy,
			&item.UpdatedBy,
			&item.CreatedAt,
			&item.UpdatedAt,
			&item.IsDeleted,
		); err != nil {
			return nil, fmt.Errorf("failed to scan warranty registration: %w", err)
		}
		list = append(list, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read warranty registrations: %w", err)
	}
	return list, nil
}

func (s *WarrantyService) loadWarrantyItemsByWarrantyIDs(ids []int) (map[int][]models.WarrantyItem, error) {
	result := make(map[int][]models.WarrantyItem)
	if len(ids) == 0 {
		return result, nil
	}

	rows, err := s.db.Query(`
		SELECT warranty_item_id, warranty_id, sale_detail_id, product_id, barcode_id, product_name, barcode,
		       variant_name, tracking_type, is_serialized, quantity::float8, serial_number, stock_lot_id, batch_number,
		       batch_expiry_date, warranty_period_months, warranty_start_date, warranty_end_date, notes, created_at, updated_at
		FROM warranty_items
		WHERE warranty_id = ANY($1)
		ORDER BY warranty_id, product_name, serial_number NULLS LAST, batch_number NULLS LAST, warranty_item_id
	`, pq.Array(ids))
	if err != nil {
		return nil, fmt.Errorf("failed to load warranty items: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var item models.WarrantyItem
		if err := rows.Scan(
			&item.WarrantyItemID,
			&item.WarrantyID,
			&item.SaleDetailID,
			&item.ProductID,
			&item.BarcodeID,
			&item.ProductName,
			&item.Barcode,
			&item.VariantName,
			&item.TrackingType,
			&item.IsSerialized,
			&item.Quantity,
			&item.SerialNumber,
			&item.StockLotID,
			&item.BatchNumber,
			&item.BatchExpiryDate,
			&item.WarrantyPeriodMonths,
			&item.WarrantyStartDate,
			&item.WarrantyEndDate,
			&item.Notes,
			&item.CreatedAt,
			&item.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan warranty item: %w", err)
		}
		result[item.WarrantyID] = append(result[item.WarrantyID], item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read warranty items: %w", err)
	}
	return result, nil
}

func (s *WarrantyService) LookupWarranties(companyID int, filters models.WarrantyLookupFilters) ([]models.WarrantyRegistration, error) {
	saleNumber := strings.TrimSpace(filters.SaleNumber)
	phone := strings.TrimSpace(filters.Phone)
	if saleNumber == "" && phone == "" {
		return nil, fmt.Errorf("sale_number or phone is required")
	}

	query := `
		SELECT warranty_id, company_id, sale_id, sale_number, customer_id, customer_name, customer_phone, customer_email,
		       customer_address, notes, registered_at, created_by, updated_by, created_at, updated_at, is_deleted
		FROM warranty_registrations
		WHERE company_id = $1
		  AND is_deleted = FALSE
	`

	args := []interface{}{companyID}
	argCount := 1
	if saleNumber != "" && phone != "" {
		argCount++
		query += fmt.Sprintf(" AND (sale_number ILIKE '%%' || $%d || '%%'", argCount)
		args = append(args, saleNumber)
		argCount++
		query += fmt.Sprintf(" OR customer_phone ILIKE '%%' || $%d || '%%')", argCount)
		args = append(args, phone)
	} else if saleNumber != "" {
		argCount++
		query += fmt.Sprintf(" AND sale_number ILIKE '%%' || $%d || '%%'", argCount)
		args = append(args, saleNumber)
	} else {
		argCount++
		query += fmt.Sprintf(" AND customer_phone ILIKE '%%' || $%d || '%%'", argCount)
		args = append(args, phone)
	}
	query += " ORDER BY registered_at DESC, warranty_id DESC"

	headers, err := s.loadWarrantyHeaders(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to lookup warranties: %w", err)
	}
	if len(headers) == 0 {
		return []models.WarrantyRegistration{}, nil
	}

	ids := make([]int, 0, len(headers))
	for _, item := range headers {
		ids = append(ids, item.WarrantyID)
	}
	itemsByWarrantyID, err := s.loadWarrantyItemsByWarrantyIDs(ids)
	if err != nil {
		return nil, err
	}
	for idx := range headers {
		headers[idx].Items = itemsByWarrantyID[headers[idx].WarrantyID]
	}

	return headers, nil
}

func (s *WarrantyService) GetWarrantyByID(companyID, warrantyID int) (*models.WarrantyRegistration, error) {
	headers, err := s.loadWarrantyHeaders(`
		SELECT warranty_id, company_id, sale_id, sale_number, customer_id, customer_name, customer_phone, customer_email,
		       customer_address, notes, registered_at, created_by, updated_by, created_at, updated_at, is_deleted
		FROM warranty_registrations
		WHERE company_id = $1
		  AND warranty_id = $2
		  AND is_deleted = FALSE
	`, companyID, warrantyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get warranty: %w", err)
	}
	if len(headers) == 0 {
		return nil, fmt.Errorf("warranty not found")
	}

	itemsByWarrantyID, err := s.loadWarrantyItemsByWarrantyIDs([]int{warrantyID})
	if err != nil {
		return nil, err
	}
	headers[0].Items = itemsByWarrantyID[warrantyID]
	return &headers[0], nil
}

func (s *WarrantyService) GetWarrantyCardData(companyID, warrantyID int) (*models.WarrantyCardDataResponse, error) {
	warranty, err := s.GetWarrantyByID(companyID, warrantyID)
	if err != nil {
		return nil, err
	}

	var company models.Company
	if err := s.db.QueryRow(`
		SELECT company_id, name, logo, address, phone, email, tax_number, currency_id,
		       is_active, created_at, updated_at
		FROM companies
		WHERE company_id = $1
	`, companyID).Scan(
		&company.CompanyID,
		&company.Name,
		&company.Logo,
		&company.Address,
		&company.Phone,
		&company.Email,
		&company.TaxNumber,
		&company.CurrencyID,
		&company.IsActive,
		&company.CreatedAt,
		&company.UpdatedAt,
	); err != nil {
		return nil, fmt.Errorf("failed to load company for warranty card: %w", err)
	}

	return &models.WarrantyCardDataResponse{
		Warranty: *warranty,
		Company:  company,
	}, nil
}
