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

type LoyaltyService struct {
	db *sql.DB
}

func NewLoyaltyService() *LoyaltyService {
	return &LoyaltyService{
		db: database.GetDB(),
	}
}

var getPromotions = (*LoyaltyService).GetPromotions

func normalizeLoyaltyRedemptionType(value *string) string {
	if value == nil {
		return "DISCOUNT"
	}
	switch strings.ToUpper(strings.TrimSpace(*value)) {
	case "GIFT":
		return "GIFT"
	default:
		return "DISCOUNT"
	}
}

func loyaltyGiftEnabled(attrs models.JSONB) bool {
	if len(attrs) == 0 {
		return false
	}
	raw, ok := attrs["loyalty_gift_enabled"]
	if !ok {
		return false
	}
	switch value := raw.(type) {
	case bool:
		return value
	case string:
		return strings.EqualFold(strings.TrimSpace(value), "true")
	case float64:
		return value > 0
	default:
		return false
	}
}

func loyaltyGiftPointsRequired(attrs models.JSONB) float64 {
	if len(attrs) == 0 {
		return 0
	}
	raw, ok := attrs["loyalty_points_required"]
	if !ok {
		return 0
	}
	switch value := raw.(type) {
	case float64:
		return value
	case int:
		return float64(value)
	case int64:
		return float64(value)
	case string:
		var parsed float64
		_, _ = fmt.Sscan(strings.TrimSpace(value), &parsed)
		return parsed
	default:
		return 0
	}
}

// Loyalty Programs
func (s *LoyaltyService) GetCustomerLoyalty(customerID, companyID int) (*models.CustomerLoyaltyResponse, error) {
	// Verify customer belongs to company
	err := s.validateCustomerInCompany(customerID, companyID)
	if err != nil {
		return nil, err
	}

	// Get customer loyalty program
	query := `
		SELECT lp.loyalty_id, lp.customer_id, lp.points, lp.total_earned, lp.total_redeemed, lp.last_updated,
			   c.name as customer_name
		FROM loyalty_programs lp
		JOIN customers c ON lp.customer_id = c.customer_id
		WHERE lp.customer_id = $1 AND c.company_id = $2
	`

	var loyalty models.LoyaltyProgram
	var customerName string
	err = s.db.QueryRow(query, customerID, companyID).Scan(
		&loyalty.LoyaltyID, &loyalty.CustomerID, &loyalty.Points, &loyalty.TotalEarned,
		&loyalty.TotalRedeemed, &loyalty.LastUpdated, &customerName,
	)

	if err == sql.ErrNoRows {
		// Create loyalty program if doesn't exist
		_, err = s.db.Exec(`
			INSERT INTO loyalty_programs (customer_id, points, total_earned, total_redeemed)
			VALUES ($1, 0, 0, 0)
		`, customerID)

		if err != nil {
			return nil, fmt.Errorf("failed to create loyalty program: %w", err)
		}

		// Get customer name for response
		err = s.db.QueryRow("SELECT name FROM customers WHERE customer_id = $1", customerID).Scan(&customerName)
		if err != nil {
			return nil, fmt.Errorf("failed to get customer name: %w", err)
		}

		loyalty = models.LoyaltyProgram{
			CustomerID:    customerID,
			Points:        0,
			TotalEarned:   0,
			TotalRedeemed: 0,
			LastUpdated:   time.Now(),
		}
	} else if err != nil {
		return nil, fmt.Errorf("failed to get loyalty program: %w", err)
	}

	// Get recent loyalty transactions
	recentActivity, err := s.getLoyaltyTransactions(customerID, 10)
	if err != nil {
		return nil, fmt.Errorf("failed to get recent activity: %w", err)
	}

	return &models.CustomerLoyaltyResponse{
		CustomerID:     loyalty.CustomerID,
		CustomerName:   customerName,
		CurrentPoints:  loyalty.Points,
		TotalEarned:    loyalty.TotalEarned,
		TotalRedeemed:  loyalty.TotalRedeemed,
		RecentActivity: recentActivity,
	}, nil
}

func (s *LoyaltyService) GetLoyaltyPrograms(companyID int) ([]models.LoyaltyProgram, error) {
	query := `
		SELECT lp.loyalty_id, lp.customer_id, lp.points, lp.total_earned, lp.total_redeemed, lp.last_updated,
			   c.name as customer_name, c.phone, c.email
		FROM loyalty_programs lp
		JOIN customers c ON lp.customer_id = c.customer_id
		WHERE c.company_id = $1 AND c.is_deleted = FALSE
		ORDER BY lp.points DESC
	`

	rows, err := s.db.Query(query, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get loyalty programs: %w", err)
	}
	defer rows.Close()

	var programs []models.LoyaltyProgram
	for rows.Next() {
		var program models.LoyaltyProgram
		var customer models.Customer

		err := rows.Scan(
			&program.LoyaltyID, &program.CustomerID, &program.Points, &program.TotalEarned,
			&program.TotalRedeemed, &program.LastUpdated, &customer.Name, &customer.Phone, &customer.Email,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan loyalty program: %w", err)
		}

		customer.CustomerID = program.CustomerID
		program.Customer = &customer
		programs = append(programs, program)
	}

	return programs, nil
}

func (s *LoyaltyService) RedeemPoints(companyID, userID int, req *models.CreateLoyaltyRedemptionRequest) (*models.LoyaltyRedemptionResponse, error) {
	if normalizeLoyaltyRedemptionType(req.RedemptionType) == "GIFT" {
		return s.redeemGiftPoints(companyID, userID, req)
	}

	if err := s.validateCustomerInCompany(req.CustomerID, companyID); err != nil {
		return nil, err
	}

	var currentPoints float64
	err := s.db.QueryRow(`
        SELECT COALESCE(points, 0) FROM loyalty_programs WHERE customer_id = $1
    `, req.CustomerID).Scan(&currentPoints)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("customer has no loyalty program")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get current points: %w", err)
	}

	settings, err := s.getLoyaltySettings(companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get loyalty settings: %w", err)
	}
	if settings.RedemptionType == "GIFT" {
		return nil, fmt.Errorf("discount redemption is disabled in loyalty settings")
	}

	redeemable := currentPoints - float64(settings.MinPointsReserve)
	if redeemable <= 0 {
		return nil, fmt.Errorf("insufficient points available")
	}
	pointsToUse := req.PointsUsed
	if pointsToUse > redeemable {
		pointsToUse = redeemable
	}
	if pointsToUse <= 0 {
		return nil, fmt.Errorf("insufficient points available")
	}
	if settings.MinRedemptionPoints > 0 && pointsToUse < settings.MinRedemptionPoints {
		return nil, fmt.Errorf("insufficient points available")
	}

	valueRedeemed := pointsToUse * settings.PointValue

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	var redemptionID int
	err = tx.QueryRow(`
        INSERT INTO loyalty_redemptions (customer_id, points_used, value_redeemed, redemption_type, location_id, notes)
        VALUES ($1, $2, $3, 'DISCOUNT', NULL, $4)
        RETURNING redemption_id
    `, req.CustomerID, pointsToUse, valueRedeemed, req.Notes).Scan(&redemptionID)
	if err != nil {
		return nil, fmt.Errorf("failed to create redemption: %w", err)
	}

	if _, err = tx.Exec(`
        UPDATE loyalty_programs
        SET points = points - $1, total_redeemed = total_redeemed + $1, last_updated = CURRENT_TIMESTAMP
        WHERE customer_id = $2
    `, pointsToUse, req.CustomerID); err != nil {
		return nil, fmt.Errorf("failed to update loyalty points: %w", err)
	}

	_, _ = tx.Exec(`
        INSERT INTO loyalty_transactions (customer_id, transaction_type, points, description, reference_type, reference_id, balance_after)
        SELECT $1, 'REDEEMED', -$2, 'Points redeemed as discount', 'LOYALTY_REDEMPTION', $3, lp.points
        FROM loyalty_programs lp WHERE lp.customer_id = $1
    `, req.CustomerID, pointsToUse, redemptionID)

	if err := s.updateCustomerTierTx(tx, companyID, req.CustomerID); err != nil {
		return nil, err
	}

	if err = tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	remainingPoints := currentPoints - pointsToUse

	return &models.LoyaltyRedemptionResponse{
		RedemptionID:    redemptionID,
		CustomerID:      req.CustomerID,
		PointsUsed:      pointsToUse,
		ValueRedeemed:   valueRedeemed,
		RemainingPoints: remainingPoints,
		RedemptionType:  "DISCOUNT",
		Message:         fmt.Sprintf("Successfully redeemed %.0f points for %.2f", pointsToUse, valueRedeemed),
	}, nil
}

func (s *LoyaltyService) redeemGiftPoints(companyID, userID int, req *models.CreateLoyaltyRedemptionRequest) (*models.LoyaltyRedemptionResponse, error) {
	if err := s.validateCustomerInCompany(req.CustomerID, companyID); err != nil {
		return nil, err
	}
	if req.LocationID == nil || *req.LocationID <= 0 {
		return nil, fmt.Errorf("location_id is required for gift redemption")
	}
	if len(req.Items) == 0 {
		return nil, fmt.Errorf("at least one gift item is required")
	}
	if err := s.validateLocationInCompany(*req.LocationID, companyID); err != nil {
		return nil, err
	}

	settings, err := s.getLoyaltySettings(companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get loyalty settings: %w", err)
	}
	if settings.RedemptionType != "GIFT" {
		return nil, fmt.Errorf("gift redemption is disabled in loyalty settings")
	}

	var currentPoints float64
	err = s.db.QueryRow(`
        SELECT COALESCE(points, 0) FROM loyalty_programs WHERE customer_id = $1
    `, req.CustomerID).Scan(&currentPoints)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("customer has no loyalty program")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get current points: %w", err)
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	type preparedGiftItem struct {
		req          models.LoyaltyRedemptionItemInput
		productName  string
		variantName  *string
		pointsPerQty float64
	}

	trackingSvc := newInventoryTrackingService(s.db)
	preparedItems := make([]preparedGiftItem, 0, len(req.Items))
	totalPoints := 0.0
	totalValue := 0.0

	for _, item := range req.Items {
		variant, err := trackingSvc.resolveVariantTx(tx, companyID, item.ProductID, item.BarcodeID)
		if err != nil {
			return nil, err
		}
		if !loyaltyGiftEnabled(variant.VariantAttributes) {
			return nil, fmt.Errorf("selected item is not enabled for loyalty gift redemption")
		}
		pointsPerQty := loyaltyGiftPointsRequired(variant.VariantAttributes)
		if pointsPerQty <= 0 {
			return nil, fmt.Errorf("selected item does not have a valid loyalty points requirement")
		}
		productName, err := s.getProductNameTx(tx, companyID, item.ProductID)
		if err != nil {
			return nil, err
		}
		preparedItems = append(preparedItems, preparedGiftItem{
			req:          item,
			productName:  productName,
			variantName:  variant.VariantName,
			pointsPerQty: pointsPerQty,
		})
		totalPoints += pointsPerQty * item.Quantity
		totalValue += pointsPerQty * item.Quantity * settings.PointValue
	}

	redeemable := currentPoints - float64(settings.MinPointsReserve)
	if redeemable <= 0 || totalPoints <= 0 || totalPoints > redeemable {
		return nil, fmt.Errorf("insufficient points available")
	}
	if settings.MinRedemptionPoints > 0 && totalPoints < settings.MinRedemptionPoints {
		return nil, fmt.Errorf("insufficient points available")
	}

	items := make([]models.LoyaltyRedemptionItem, 0, len(preparedItems))
	profitDetails := &ProfitGuardDetails{
		Lines: make([]ProfitGuardLine, 0, len(preparedItems)),
	}

	for _, prepared := range preparedItems {
		selection := inventorySelection{
			ProductID:        prepared.req.ProductID,
			BarcodeID:        prepared.req.BarcodeID,
			Quantity:         prepared.req.Quantity,
			SerialNumbers:    prepared.req.SerialNumbers,
			BatchAllocations: prepared.req.BatchAllocations,
			Notes:            req.Notes,
			OverridePassword: req.OverridePassword,
		}
		issue, err := trackingSvc.IssueStockTx(
			tx,
			companyID,
			*req.LocationID,
			userID,
			"LOYALTY_GIFT",
			"loyalty_redemption_item",
			nil,
			nil,
			selection,
		)
		if err != nil {
			return nil, err
		}

		itemPoints := prepared.pointsPerQty * prepared.req.Quantity
		itemValue := itemPoints * settings.PointValue
		item := models.LoyaltyRedemptionItem{
			ProductID:     prepared.req.ProductID,
			BarcodeID:     intPtr(issue.BarcodeID),
			ProductName:   prepared.productName,
			VariantName:   prepared.variantName,
			Quantity:      prepared.req.Quantity,
			PointsUsed:    itemPoints,
			ValueRedeemed: itemValue,
			UnitCost:      issue.UnitCost,
			TotalCost:     issue.TotalCost,
			SerialNumbers: append([]string(nil), prepared.req.SerialNumbers...),
			BatchAllocations: batchAllocationsJSON(
				prepared.req.BatchAllocations,
			),
		}
		items = append(items, item)

		profit := itemValue - issue.TotalCost
		profitDetails.TotalRevenue += itemValue
		profitDetails.TotalCost += issue.TotalCost
		profitDetails.Lines = append(profitDetails.Lines, ProfitGuardLine{
			ProductID:        intPtr(prepared.req.ProductID),
			BarcodeID:        intPtr(issue.BarcodeID),
			ProductName:      prepared.productName,
			Quantity:         prepared.req.Quantity,
			UnitPrice:        itemValue / prepared.req.Quantity,
			Revenue:          itemValue,
			Cost:             issue.TotalCost,
			Profit:           profit,
			CostPricePerUnit: issue.UnitCost,
		})
	}
	profitDetails.Profit = profitDetails.TotalRevenue - profitDetails.TotalCost
	if profitDetails.Profit < 0 {
		profitDetails.LossAmount = -profitDetails.Profit
	}
	if err := (&SalesService{db: s.db}).enforceNegativeProfitPolicyTx(tx, companyID, req.OverridePassword, profitDetails); err != nil {
		return nil, err
	}

	var redemptionID int
	err = tx.QueryRow(`
        INSERT INTO loyalty_redemptions (customer_id, points_used, value_redeemed, redemption_type, location_id, notes)
        VALUES ($1, $2, $3, 'GIFT', $4, $5)
        RETURNING redemption_id
    `, req.CustomerID, totalPoints, totalValue, *req.LocationID, req.Notes).Scan(&redemptionID)
	if err != nil {
		return nil, fmt.Errorf("failed to create redemption: %w", err)
	}

	for index := range items {
		items[index].RedemptionID = redemptionID
		err = tx.QueryRow(`
            INSERT INTO loyalty_redemption_items (
                redemption_id, product_id, barcode_id, product_name, variant_name,
                quantity, points_used, value_redeemed, unit_cost, total_cost,
                serial_numbers, batch_allocations
            )
            VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
            RETURNING redemption_item_id
        `,
			redemptionID,
			items[index].ProductID,
			items[index].BarcodeID,
			items[index].ProductName,
			items[index].VariantName,
			items[index].Quantity,
			items[index].PointsUsed,
			items[index].ValueRedeemed,
			items[index].UnitCost,
			items[index].TotalCost,
			pq.Array(items[index].SerialNumbers),
			items[index].BatchAllocations,
		).Scan(&items[index].RedemptionItemID)
		if err != nil {
			return nil, fmt.Errorf("failed to save gift redemption item: %w", err)
		}
	}

	if _, err = tx.Exec(`
        UPDATE loyalty_programs
        SET points = points - $1, total_redeemed = total_redeemed + $1, last_updated = CURRENT_TIMESTAMP
        WHERE customer_id = $2
    `, totalPoints, req.CustomerID); err != nil {
		return nil, fmt.Errorf("failed to update loyalty points: %w", err)
	}

	_, _ = tx.Exec(`
        INSERT INTO loyalty_transactions (customer_id, transaction_type, points, description, reference_type, reference_id, balance_after)
        SELECT $1, 'REDEEMED', -$2, 'Points redeemed for loyalty gifts', 'LOYALTY_REDEMPTION', $3, lp.points
        FROM loyalty_programs lp WHERE lp.customer_id = $1
    `, req.CustomerID, totalPoints, redemptionID)

	if err := s.updateCustomerTierTx(tx, companyID, req.CustomerID); err != nil {
		return nil, err
	}

	if err = tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	remainingPoints := currentPoints - totalPoints
	return &models.LoyaltyRedemptionResponse{
		RedemptionID:    redemptionID,
		CustomerID:      req.CustomerID,
		PointsUsed:      totalPoints,
		ValueRedeemed:   totalValue,
		RemainingPoints: remainingPoints,
		RedemptionType:  "GIFT",
		Message:         fmt.Sprintf("Successfully redeemed %.0f points for %d gift item(s)", totalPoints, len(items)),
		Items:           items,
	}, nil
}

func batchAllocationsJSON(items []models.InventoryBatchSelectionInput) models.JSONB {
	if len(items) == 0 {
		return models.JSONB{}
	}
	values := make([]map[string]interface{}, 0, len(items))
	for _, item := range items {
		values = append(values, map[string]interface{}{
			"lot_id":   item.LotID,
			"quantity": item.Quantity,
		})
	}
	return models.JSONB{"items": values}
}

func (s *LoyaltyService) getProductNameTx(tx *sql.Tx, companyID, productID int) (string, error) {
	var name string
	err := tx.QueryRow(`
        SELECT name
        FROM products
        WHERE company_id = $1 AND product_id = $2 AND is_deleted = FALSE
    `, companyID, productID).Scan(&name)
	if err == sql.ErrNoRows {
		return "", fmt.Errorf("product not found")
	}
	if err != nil {
		return "", fmt.Errorf("failed to get product name: %w", err)
	}
	return name, nil
}

func (s *LoyaltyService) GetLoyaltyRedemptions(companyID int, customerID *int) ([]models.LoyaltyRedemption, error) {
	query := `
		SELECT lr.redemption_id, lr.sale_id, lr.customer_id, lr.points_used, lr.value_redeemed, lr.redeemed_at,
			   COALESCE(lr.redemption_type, 'DISCOUNT'), lr.location_id, lr.notes,
			   c.name as customer_name
		FROM loyalty_redemptions lr
		JOIN customers c ON lr.customer_id = c.customer_id
		WHERE c.company_id = $1
	`

	args := []interface{}{companyID}
	argCount := 1

	if customerID != nil {
		argCount++
		query += fmt.Sprintf(" AND lr.customer_id = $%d", argCount)
		args = append(args, *customerID)
	}

	query += " ORDER BY lr.redeemed_at DESC"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get redemptions: %w", err)
	}
	defer rows.Close()

	var redemptions []models.LoyaltyRedemption
	for rows.Next() {
		var redemption models.LoyaltyRedemption
		var customerName string

		err := rows.Scan(
			&redemption.RedemptionID, &redemption.SaleID, &redemption.CustomerID,
			&redemption.PointsUsed, &redemption.ValueRedeemed, &redemption.RedeemedAt,
			&redemption.RedemptionType, &redemption.LocationID, &redemption.Notes,
			&customerName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan redemption: %w", err)
		}

		redemption.Customer = &models.Customer{
			CustomerID: redemption.CustomerID,
			Name:       customerName,
		}
		if redemption.RedemptionType == "GIFT" {
			items, err := s.getLoyaltyRedemptionItems(redemption.RedemptionID)
			if err != nil {
				return nil, err
			}
			redemption.Items = items
		}

		redemptions = append(redemptions, redemption)
	}

	return redemptions, nil
}

func (s *LoyaltyService) getLoyaltyRedemptionItems(redemptionID int) ([]models.LoyaltyRedemptionItem, error) {
	rows, err := s.db.Query(`
        SELECT redemption_item_id, redemption_id, product_id, barcode_id, product_name, variant_name,
               quantity::float8, points_used::float8, value_redeemed::float8, unit_cost::float8, total_cost::float8,
               COALESCE(serial_numbers, ARRAY[]::text[]), COALESCE(batch_allocations, '{}'::jsonb)
        FROM loyalty_redemption_items
        WHERE redemption_id = $1
        ORDER BY redemption_item_id
    `, redemptionID)
	if err != nil {
		return nil, fmt.Errorf("failed to get redemption items: %w", err)
	}
	defer rows.Close()

	items := make([]models.LoyaltyRedemptionItem, 0)
	for rows.Next() {
		var item models.LoyaltyRedemptionItem
		if err := rows.Scan(
			&item.RedemptionItemID,
			&item.RedemptionID,
			&item.ProductID,
			&item.BarcodeID,
			&item.ProductName,
			&item.VariantName,
			&item.Quantity,
			&item.PointsUsed,
			&item.ValueRedeemed,
			&item.UnitCost,
			&item.TotalCost,
			pq.Array(&item.SerialNumbers),
			&item.BatchAllocations,
		); err != nil {
			return nil, fmt.Errorf("failed to scan redemption item: %w", err)
		}
		items = append(items, item)
	}
	return items, nil
}

func (s *LoyaltyService) AwardPoints(companyID, customerID int, saleAmount float64, saleID int) error {
	// Check if customer is enrolled in loyalty
	var isLoyalty bool
	if err := s.db.QueryRow(`SELECT is_loyalty FROM customers WHERE customer_id=$1`, customerID).Scan(&isLoyalty); err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("customer not found")
		}
		return fmt.Errorf("failed to check loyalty enrollment: %w", err)
	}
	if !isLoyalty {
		return nil // do nothing if not enrolled
	}

	// Get loyalty settings
	settings, err := s.getLoyaltySettings(companyID)
	if err != nil {
		return fmt.Errorf("failed to get loyalty settings: %w", err)
	}

	// Determine earn rate: tier override if present
	earnRate := settings.PointsPerCurrency
	var tierRate sql.NullFloat64
	if err := s.db.QueryRow(`SELECT lt.points_per_currency FROM customers c LEFT JOIN loyalty_tiers lt ON c.loyalty_tier_id = lt.tier_id WHERE c.customer_id=$1`, customerID).Scan(&tierRate); err == nil {
		if tierRate.Valid && tierRate.Float64 > 0 {
			earnRate = tierRate.Float64
		}
	}

	pointsEarned := saleAmount * earnRate
	if pointsEarned <= 0 {
		return nil
	}

	// Start transaction
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	var alreadyAwarded bool
	if err := tx.QueryRow(`
		SELECT EXISTS(
			SELECT 1
			FROM loyalty_transactions
			WHERE customer_id = $1
			  AND transaction_type = 'EARNED'
			  AND reference_type = 'SALE'
			  AND reference_id = $2
		)
	`, customerID, saleID).Scan(&alreadyAwarded); err == nil && alreadyAwarded {
		return tx.Commit()
	}

	// Update or create loyalty program
	_, err = tx.Exec(`
        INSERT INTO loyalty_programs (customer_id, points, total_earned, last_updated)
        VALUES ($1, $2, $2, CURRENT_TIMESTAMP)
        ON CONFLICT (customer_id)
        DO UPDATE SET 
            points = loyalty_programs.points + $2,
            total_earned = loyalty_programs.total_earned + $2,
            last_updated = CURRENT_TIMESTAMP
    `, customerID, pointsEarned)
	if err != nil {
		return fmt.Errorf("failed to award points: %w", err)
	}

	// Optional: log to loyalty_transactions if table exists
	_, _ = tx.Exec(`
        INSERT INTO loyalty_transactions (customer_id, transaction_type, points, description, reference_type, reference_id, balance_after)
        SELECT $1, 'EARNED', $2, 'Points earned on sale', 'SALE', $3, lp.points
        FROM loyalty_programs lp WHERE lp.customer_id=$1
    `, customerID, pointsEarned, saleID)

	// Recompute and update customer's tier based on points
	if err := s.updateCustomerTierTx(tx, companyID, customerID); err != nil {
		return err
	}

	return tx.Commit()
}

// RedeemPointsForSale redeems points during a POS sale and binds redemption to sale_id.
func (s *LoyaltyService) RedeemPointsForSale(companyID, customerID, saleID int, requestedPoints float64) (usedPoints float64, valueRedeemed float64, err error) {
	// Validate customer belongs to company
	if err := s.validateCustomerInCompany(customerID, companyID); err != nil {
		return 0, 0, err
	}

	var existingUsed float64
	var existingValue float64
	err = s.db.QueryRow(`
		SELECT points_used::float8, value_redeemed::float8
		FROM loyalty_redemptions
		WHERE sale_id = $1 AND customer_id = $2 AND redemption_type = 'DISCOUNT'
		ORDER BY redemption_id DESC
		LIMIT 1
	`, saleID, customerID).Scan(&existingUsed, &existingValue)
	if err == nil {
		return existingUsed, existingValue, nil
	}
	if err != nil && err != sql.ErrNoRows {
		return 0, 0, fmt.Errorf("failed to check existing sale redemption: %w", err)
	}

	// Current balance
	var currentPoints float64
	if err := s.db.QueryRow(`SELECT COALESCE(points,0) FROM loyalty_programs WHERE customer_id=$1`, customerID).Scan(&currentPoints); err != nil {
		if err == sql.ErrNoRows {
			return 0, 0, fmt.Errorf("customer has no loyalty program")
		}
		return 0, 0, fmt.Errorf("failed to get current points: %w", err)
	}

	// Settings
	settings, err2 := s.getLoyaltySettings(companyID)
	if err2 != nil {
		return 0, 0, err2
	}
	redeemable := currentPoints - float64(settings.MinPointsReserve)
	if redeemable <= 0 {
		return 0, 0, fmt.Errorf("insufficient points available")
	}

	used := requestedPoints
	if used > redeemable {
		used = redeemable
	}
	if used <= 0 {
		return 0, 0, fmt.Errorf("insufficient points available")
	}
	if settings.MinRedemptionPoints > 0 && used < settings.MinRedemptionPoints {
		return 0, 0, fmt.Errorf("insufficient points available")
	}

	val := used * settings.PointValue

	tx, err := s.db.Begin()
	if err != nil {
		return 0, 0, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	var redID int
	if err := tx.QueryRow(`INSERT INTO loyalty_redemptions (sale_id, customer_id, points_used, value_redeemed) VALUES ($1,$2,$3,$4) RETURNING redemption_id`, saleID, customerID, used, val).Scan(&redID); err != nil {
		return 0, 0, fmt.Errorf("failed to create redemption: %w", err)
	}

	if _, err := tx.Exec(`UPDATE loyalty_programs SET points = points - $1, total_redeemed = total_redeemed + $1, last_updated = CURRENT_TIMESTAMP WHERE customer_id=$2`, used, customerID); err != nil {
		return 0, 0, fmt.Errorf("failed to update loyalty points: %w", err)
	}

	if err := s.updateCustomerTierTx(tx, companyID, customerID); err != nil {
		return 0, 0, err
	}

	if err := tx.Commit(); err != nil {
		return 0, 0, fmt.Errorf("failed to commit transaction: %w", err)
	}
	return used, val, nil
}

func (s *LoyaltyService) updateCustomerTierTx(tx *sql.Tx, companyID, customerID int) error {
	// Get current points
	var pts float64
	if err := tx.QueryRow(`SELECT COALESCE(points,0) FROM loyalty_programs WHERE customer_id=$1`, customerID).Scan(&pts); err != nil {
		return fmt.Errorf("failed to get current points: %w", err)
	}
	// Find highest tier with min_points <= pts
	var tierID int
	err := tx.QueryRow(`
        SELECT tier_id FROM loyalty_tiers 
        WHERE company_id=$1 AND is_active=TRUE AND min_points <= $2
        ORDER BY min_points DESC
        LIMIT 1`, companyID, pts).Scan(&tierID)
	if err == sql.ErrNoRows {
		// No active tier qualifies; set NULL
		_, _ = tx.Exec(`UPDATE customers SET loyalty_tier_id = NULL WHERE customer_id=$1`, customerID)
		return nil
	} else if err != nil {
		return fmt.Errorf("failed to compute tier: %w", err)
	}
	_, _ = tx.Exec(`UPDATE customers SET loyalty_tier_id=$1 WHERE customer_id=$2`, tierID, customerID)
	return nil
}

// Promotions
func (s *LoyaltyService) GetPromotions(companyID int, activeOnly bool) ([]models.Promotion, error) {
	query := `
		SELECT promotion_id, company_id, name, description, discount_type, discount_scope, value, min_amount,
			   start_date, end_date, applicable_to, conditions, priority, is_active, created_at, updated_at
		FROM promotions 
		WHERE company_id = $1
	`

	args := []interface{}{companyID}
	argCount := 1

	if activeOnly {
		argCount++
		query += " AND is_active = TRUE AND start_date <= CURRENT_DATE AND end_date >= CURRENT_DATE"
	}

	query += " ORDER BY start_date DESC"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get promotions: %w", err)
	}
	defer rows.Close()

	var promotions []models.Promotion
	for rows.Next() {
		var promotion models.Promotion
		err := rows.Scan(
			&promotion.PromotionID, &promotion.CompanyID, &promotion.Name, &promotion.Description,
			&promotion.DiscountType, &promotion.DiscountScope, &promotion.Value, &promotion.MinAmount, &promotion.StartDate,
			&promotion.EndDate, &promotion.ApplicableTo, &promotion.Conditions, &promotion.Priority, &promotion.IsActive,
			&promotion.CreatedAt, &promotion.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan promotion: %w", err)
		}
		if strings.TrimSpace(promotion.DiscountScope) == "" {
			promotion.DiscountScope = "ORDER"
		}
		promotions = append(promotions, promotion)
	}

	if err := s.attachPromotionProductRules(promotions); err != nil {
		return nil, err
	}
	return promotions, nil
}

func (s *LoyaltyService) CreatePromotion(companyID int, req *models.CreatePromotionRequest) (*models.Promotion, error) {
	startDate, err := time.Parse("2006-01-02", req.StartDate)
	if err != nil {
		return nil, fmt.Errorf("invalid start date format: %w", err)
	}

	endDate, err := time.Parse("2006-01-02", req.EndDate)
	if err != nil {
		return nil, fmt.Errorf("invalid end date format: %w", err)
	}

	if endDate.Before(startDate) {
		return nil, fmt.Errorf("end date cannot be before start date")
	}

	discountScope := "ORDER"
	if req.DiscountScope != nil && strings.TrimSpace(*req.DiscountScope) != "" {
		discountScope = strings.ToUpper(strings.TrimSpace(*req.DiscountScope))
	}
	priority := 0
	if req.Priority != nil {
		priority = *req.Priority
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to begin promotion transaction: %w", err)
	}
	defer tx.Rollback()

	query := `
		INSERT INTO promotions (company_id, name, description, discount_type, discount_scope, value, min_amount,
							   start_date, end_date, applicable_to, conditions, priority)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		RETURNING promotion_id, created_at
	`

	var promotion models.Promotion
	err = tx.QueryRow(query,
		companyID, req.Name, req.Description, req.DiscountType, discountScope, req.Value, req.MinAmount,
		startDate, endDate, req.ApplicableTo, req.Conditions, priority,
	).Scan(&promotion.PromotionID, &promotion.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create promotion: %w", err)
	}

	if err := s.savePromotionProductRulesTx(tx, promotion.PromotionID, req.ProductRules); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit promotion: %w", err)
	}

	promotion.CompanyID = companyID
	promotion.Name = req.Name
	promotion.Description = req.Description
	promotion.DiscountType = req.DiscountType
	promotion.DiscountScope = discountScope
	promotion.Value = req.Value
	promotion.MinAmount = req.MinAmount
	promotion.StartDate = startDate
	promotion.EndDate = endDate
	promotion.ApplicableTo = req.ApplicableTo
	promotion.Conditions = req.Conditions
	promotion.Priority = priority
	promotion.IsActive = true
	return &promotion, nil
}

func (s *LoyaltyService) UpdatePromotion(promotionID, companyID int, req *models.UpdatePromotionRequest) error {
	// Verify promotion belongs to company
	err := s.verifyPromotionInCompany(promotionID, companyID)
	if err != nil {
		return err
	}

	setParts := []string{}
	args := []interface{}{}
	argCount := 0

	if req.Name != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("name = $%d", argCount))
		args = append(args, *req.Name)
	}
	if req.Description != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("description = $%d", argCount))
		args = append(args, *req.Description)
	}
	if req.DiscountType != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("discount_type = $%d", argCount))
		args = append(args, *req.DiscountType)
	}
	if req.DiscountScope != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("discount_scope = $%d", argCount))
		args = append(args, strings.ToUpper(strings.TrimSpace(*req.DiscountScope)))
	}
	if req.Value != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("value = $%d", argCount))
		args = append(args, *req.Value)
	}
	if req.MinAmount != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("min_amount = $%d", argCount))
		args = append(args, *req.MinAmount)
	}
	if req.StartDate != nil {
		startDate, err := time.Parse("2006-01-02", *req.StartDate)
		if err != nil {
			return fmt.Errorf("invalid start date format: %w", err)
		}
		argCount++
		setParts = append(setParts, fmt.Sprintf("start_date = $%d", argCount))
		args = append(args, startDate)
	}
	if req.EndDate != nil {
		endDate, err := time.Parse("2006-01-02", *req.EndDate)
		if err != nil {
			return fmt.Errorf("invalid end date format: %w", err)
		}
		argCount++
		setParts = append(setParts, fmt.Sprintf("end_date = $%d", argCount))
		args = append(args, endDate)
	}
	if req.ApplicableTo != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("applicable_to = $%d", argCount))
		args = append(args, *req.ApplicableTo)
	}
	if req.Conditions != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("conditions = $%d", argCount))
		args = append(args, *req.Conditions)
	}
	if req.Priority != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("priority = $%d", argCount))
		args = append(args, *req.Priority)
	}
	if req.IsActive != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("is_active = $%d", argCount))
		args = append(args, *req.IsActive)
	}

	if len(setParts) == 0 && req.ProductRules == nil {
		return fmt.Errorf("no fields to update")
	}

	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to start promotion update transaction: %w", err)
	}
	defer tx.Rollback()

	if len(setParts) > 0 {
		setParts = append(setParts, "updated_at = CURRENT_TIMESTAMP")
		query := fmt.Sprintf("UPDATE promotions SET %s WHERE promotion_id = $%d",
			strings.Join(setParts, ", "), argCount+1)
		args = append(args, promotionID)

		result, err := tx.Exec(query, args...)
		if err != nil {
			return fmt.Errorf("failed to update promotion: %w", err)
		}

		rowsAffected, err := result.RowsAffected()
		if err != nil {
			return fmt.Errorf("failed to get rows affected: %w", err)
		}

		if rowsAffected == 0 {
			return fmt.Errorf("promotion not found")
		}
	}

	if req.ProductRules != nil {
		if err := s.savePromotionProductRulesTx(tx, promotionID, req.ProductRules); err != nil {
			return err
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit promotion update: %w", err)
	}

	return nil
}

func (s *LoyaltyService) DeletePromotion(promotionID, companyID int) error {
	// Verify promotion belongs to company
	err := s.verifyPromotionInCompany(promotionID, companyID)
	if err != nil {
		return err
	}

	query := `UPDATE promotions SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP WHERE promotion_id = $1`

	result, err := s.db.Exec(query, promotionID)
	if err != nil {
		return fmt.Errorf("failed to delete promotion: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("promotion not found")
	}

	return nil
}

func (s *LoyaltyService) CheckPromotionEligibility(companyID int, req *models.PromotionEligibilityRequest) (*models.PromotionEligibilityResponse, error) {
	return s.EvaluatePromotionEligibility(companyID, req)
}

// Helper methods
func (s *LoyaltyService) validateCustomerInCompany(customerID, companyID int) error {
	var count int
	err := s.db.QueryRow(`
		SELECT COUNT(*) FROM customers 
		WHERE customer_id = $1 AND company_id = $2 AND is_deleted = FALSE
	`, customerID, companyID).Scan(&count)

	if err != nil {
		return fmt.Errorf("failed to validate customer: %w", err)
	}

	if count == 0 {
		return fmt.Errorf("customer not found")
	}

	return nil
}

func (s *LoyaltyService) validateLocationInCompany(locationID, companyID int) error {
	var count int
	err := s.db.QueryRow(`
        SELECT COUNT(*) FROM locations
        WHERE location_id = $1 AND company_id = $2 AND is_active = TRUE
    `, locationID, companyID).Scan(&count)
	if err != nil {
		return fmt.Errorf("failed to validate location: %w", err)
	}
	if count == 0 {
		return fmt.Errorf("location not found")
	}
	return nil
}

func (s *LoyaltyService) verifyPromotionInCompany(promotionID, companyID int) error {
	var count int
	err := s.db.QueryRow(`
		SELECT COUNT(*) FROM promotions 
		WHERE promotion_id = $1 AND company_id = $2
	`, promotionID, companyID).Scan(&count)

	if err != nil {
		return fmt.Errorf("failed to verify promotion: %w", err)
	}

	if count == 0 {
		return fmt.Errorf("promotion not found")
	}

	return nil
}

func (s *LoyaltyService) getLoyaltySettings(companyID int) (*models.LoyaltySettingsResponse, error) {
	// Fetch company-specific settings; fall back to defaults if not present
	var pointsPer float64
	var pointValue float64
	var minRedemption int
	var minReserve int
	var expiry int
	var redemptionType string

	err := s.db.QueryRow(`
        SELECT points_per_currency, point_value, min_redemption_points, COALESCE(min_points_reserve,0), points_expiry_days,
               COALESCE(redemption_type, 'DISCOUNT')
        FROM loyalty_settings WHERE company_id = $1 AND is_active = TRUE
    `, companyID).Scan(&pointsPer, &pointValue, &minRedemption, &minReserve, &expiry, &redemptionType)

	if err == sql.ErrNoRows {
		// defaults
		pointsPer = 1.0
		pointValue = 0.01
		minRedemption = 100
		minReserve = 0
		expiry = 365
		redemptionType = "DISCOUNT"
	} else if err != nil {
		// Fallback for older DBs missing min_points_reserve column
		var fallbackErr error
		fallbackErr = s.db.QueryRow(`
            SELECT points_per_currency, point_value, min_redemption_points, points_expiry_days
            FROM loyalty_settings WHERE company_id = $1 AND is_active = TRUE
        `, companyID).Scan(&pointsPer, &pointValue, &minRedemption, &expiry)
		if fallbackErr == sql.ErrNoRows {
			pointsPer = 1.0
			pointValue = 0.01
			minRedemption = 100
			minReserve = 0
			expiry = 365
			redemptionType = "DISCOUNT"
		} else if fallbackErr != nil {
			return nil, fmt.Errorf("failed to get loyalty settings: %w", err)
		}
	}
	redemptionType = normalizeLoyaltyRedemptionType(&redemptionType)

	return &models.LoyaltySettingsResponse{
		PointsPerCurrency:   pointsPer,
		PointValue:          pointValue,
		MinRedemptionPoints: float64(minRedemption),
		MinPointsReserve:    minReserve,
		PointsExpiryDays:    expiry,
		RedemptionType:      redemptionType,
	}, nil
}

// GetLoyaltySettings exposes company settings outside services package
func (s *LoyaltyService) GetLoyaltySettings(companyID int) (*models.LoyaltySettingsResponse, error) {
	return s.getLoyaltySettings(companyID)
}

// Loyalty tiers CRUD
func (s *LoyaltyService) GetTiers(companyID int) ([]models.LoyaltyTier, error) {
	rows, err := s.db.Query(`SELECT tier_id, company_id, name, min_points, points_per_currency, is_active, created_at, updated_at FROM loyalty_tiers WHERE company_id=$1 ORDER BY min_points ASC`, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get tiers: %w", err)
	}
	defer rows.Close()
	var tiers []models.LoyaltyTier
	for rows.Next() {
		var t models.LoyaltyTier
		if err := rows.Scan(&t.TierID, &t.CompanyID, &t.Name, &t.MinPoints, &t.PointsPerCurrency, &t.IsActive, &t.CreatedAt, &t.UpdatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan tier: %w", err)
		}
		tiers = append(tiers, t)
	}
	return tiers, nil
}

func (s *LoyaltyService) CreateTier(companyID int, req *models.CreateLoyaltyTierRequest) (*models.LoyaltyTier, error) {
	var t models.LoyaltyTier
	var err error
	if req.PointsPerCurrency != nil {
		err = s.db.QueryRow(`INSERT INTO loyalty_tiers (company_id, name, min_points, points_per_currency) VALUES ($1,$2,$3,$4) RETURNING tier_id, created_at, updated_at`, companyID, req.Name, req.MinPoints, *req.PointsPerCurrency).
			Scan(&t.TierID, &t.CreatedAt, &t.UpdatedAt)
	} else {
		err = s.db.QueryRow(`INSERT INTO loyalty_tiers (company_id, name, min_points) VALUES ($1,$2,$3) RETURNING tier_id, created_at, updated_at`, companyID, req.Name, req.MinPoints).
			Scan(&t.TierID, &t.CreatedAt, &t.UpdatedAt)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to create tier: %w", err)
	}
	t.CompanyID = companyID
	t.Name = req.Name
	t.MinPoints = req.MinPoints
	t.IsActive = true
	t.PointsPerCurrency = req.PointsPerCurrency
	return &t, nil
}

func (s *LoyaltyService) UpdateTier(companyID, tierID int, req *models.UpdateLoyaltyTierRequest) error {
	// Ensure tier belongs to company
	var count int
	if err := s.db.QueryRow(`SELECT COUNT(*) FROM loyalty_tiers WHERE tier_id=$1 AND company_id=$2`, tierID, companyID).Scan(&count); err != nil {
		return fmt.Errorf("failed to verify tier: %w", err)
	}
	if count == 0 {
		return fmt.Errorf("tier not found")
	}

	parts := []string{}
	args := []interface{}{}
	n := 0
	if req.Name != nil {
		n++
		parts = append(parts, fmt.Sprintf("name=$%d", n))
		args = append(args, *req.Name)
	}
	if req.MinPoints != nil {
		n++
		parts = append(parts, fmt.Sprintf("min_points=$%d", n))
		args = append(args, *req.MinPoints)
	}
	if req.PointsPerCurrency != nil {
		n++
		parts = append(parts, fmt.Sprintf("points_per_currency=$%d", n))
		args = append(args, *req.PointsPerCurrency)
	}
	if req.IsActive != nil {
		n++
		parts = append(parts, fmt.Sprintf("is_active=$%d", n))
		args = append(args, *req.IsActive)
	}
	if len(parts) == 0 {
		return nil
	}
	parts = append(parts, "updated_at = CURRENT_TIMESTAMP")
	q := fmt.Sprintf("UPDATE loyalty_tiers SET %s WHERE tier_id=$%d", strings.Join(parts, ", "), n+1)
	args = append(args, tierID)
	_, err := s.db.Exec(q, args...)
	if err != nil {
		return fmt.Errorf("failed to update tier: %w", err)
	}
	return nil
}

func (s *LoyaltyService) DeleteTier(companyID, tierID int) error {
	res, err := s.db.Exec(`DELETE FROM loyalty_tiers WHERE tier_id=$1 AND company_id=$2`, tierID, companyID)
	if err != nil {
		return fmt.Errorf("failed to delete tier: %w", err)
	}
	rows, _ := res.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("tier not found")
	}
	// Null out customers referencing this tier
	_, _ = s.db.Exec(`UPDATE customers SET loyalty_tier_id = NULL WHERE loyalty_tier_id=$1`, tierID)
	return nil
}

func (s *LoyaltyService) UpdateLoyaltySettings(companyID int, req *models.UpdateLoyaltySettingsRequest) error {
	// Upsert settings row for company
	// Build dynamic update set for partial updates
	setParts := []string{}
	args := []interface{}{}
	idx := 0

	if req.PointsPerCurrency != nil {
		idx++
		setParts = append(setParts, fmt.Sprintf("points_per_currency = $%d", idx))
		args = append(args, *req.PointsPerCurrency)
	}
	if req.PointValue != nil {
		idx++
		setParts = append(setParts, fmt.Sprintf("point_value = $%d", idx))
		args = append(args, *req.PointValue)
	}
	if req.MinRedemptionPoints != nil {
		idx++
		setParts = append(setParts, fmt.Sprintf("min_redemption_points = $%d", idx))
		args = append(args, *req.MinRedemptionPoints)
	}
	if req.MinPointsReserve != nil {
		idx++
		setParts = append(setParts, fmt.Sprintf("min_points_reserve = $%d", idx))
		args = append(args, *req.MinPointsReserve)
	}
	if req.PointsExpiryDays != nil {
		idx++
		setParts = append(setParts, fmt.Sprintf("points_expiry_days = $%d", idx))
		args = append(args, *req.PointsExpiryDays)
	}
	if req.RedemptionType != nil {
		idx++
		setParts = append(setParts, fmt.Sprintf("redemption_type = $%d", idx))
		args = append(args, normalizeLoyaltyRedemptionType(req.RedemptionType))
	}

	if len(setParts) == 0 {
		return nil
	}

	// Ensure a row exists
	_, _ = s.db.Exec(`INSERT INTO loyalty_settings (company_id) VALUES ($1) ON CONFLICT (company_id) DO NOTHING`, companyID)

	// Apply update
	setParts = append(setParts, "updated_at = CURRENT_TIMESTAMP")
	query := fmt.Sprintf("UPDATE loyalty_settings SET %s WHERE company_id = $%d", strings.Join(setParts, ", "), idx+1)
	args = append(args, companyID)
	_, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update loyalty settings: %w", err)
	}
	return nil
}

func (s *LoyaltyService) getLoyaltyTransactions(customerID int, limit int) ([]models.LoyaltyTransaction, error) {
	// This is a simplified version - you might want to create a loyalty_transactions table
	// For now, we'll return redemption history
	query := `
		SELECT redemption_id, customer_id, points_used, value_redeemed, redeemed_at
		FROM loyalty_redemptions
		WHERE customer_id = $1
		ORDER BY redeemed_at DESC
		LIMIT $2
	`

	rows, err := s.db.Query(query, customerID, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to get loyalty transactions: %w", err)
	}
	defer rows.Close()

	var transactions []models.LoyaltyTransaction
	for rows.Next() {
		var redemptionID int
		var customerIDFromDB int
		var pointsUsed, valueRedeemed float64
		var redeemedAt time.Time

		err := rows.Scan(&redemptionID, &customerIDFromDB, &pointsUsed, &valueRedeemed, &redeemedAt)
		if err != nil {
			return nil, fmt.Errorf("failed to scan loyalty transaction: %w", err)
		}

		transactions = append(transactions, models.LoyaltyTransaction{
			TransactionID:   redemptionID,
			CustomerID:      customerID,
			Type:            "REDEEMED",
			Points:          -pointsUsed,
			Description:     fmt.Sprintf("Redeemed %.0f points for $%.2f", pointsUsed, valueRedeemed),
			ReferenceID:     &redemptionID,
			TransactionDate: redeemedAt,
		})
	}

	return transactions, nil
}
