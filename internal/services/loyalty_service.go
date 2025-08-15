package services

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
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

func (s *LoyaltyService) RedeemPoints(companyID int, req *models.CreateLoyaltyRedemptionRequest) (*models.LoyaltyRedemptionResponse, error) {
	// Verify customer belongs to company
	err := s.validateCustomerInCompany(req.CustomerID, companyID)
	if err != nil {
		return nil, err
	}

	// Get current points
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

	// Check sufficient points
	if currentPoints < req.PointsUsed {
		return nil, fmt.Errorf("insufficient points available")
	}

	// Get loyalty settings for point value
	settings, err := s.getLoyaltySettings(companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get loyalty settings: %w", err)
	}

	valueRedeemed := req.PointsUsed * settings.PointValue

	// Start transaction
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	// Create redemption record
	var redemptionID int
	err = tx.QueryRow(`
		INSERT INTO loyalty_redemptions (customer_id, points_used, value_redeemed)
		VALUES ($1, $2, $3)
		RETURNING redemption_id
	`, req.CustomerID, req.PointsUsed, valueRedeemed).Scan(&redemptionID)

	if err != nil {
		return nil, fmt.Errorf("failed to create redemption: %w", err)
	}

	// Update loyalty program
	_, err = tx.Exec(`
		UPDATE loyalty_programs 
		SET points = points - $1, total_redeemed = total_redeemed + $1, last_updated = CURRENT_TIMESTAMP
		WHERE customer_id = $2
	`, req.PointsUsed, req.CustomerID)

	if err != nil {
		return nil, fmt.Errorf("failed to update loyalty points: %w", err)
	}

	// Commit transaction
	if err = tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	remainingPoints := currentPoints - req.PointsUsed

	return &models.LoyaltyRedemptionResponse{
		RedemptionID:    redemptionID,
		CustomerID:      req.CustomerID,
		PointsUsed:      req.PointsUsed,
		ValueRedeemed:   valueRedeemed,
		RemainingPoints: remainingPoints,
		Message:         fmt.Sprintf("Successfully redeemed %.0f points for $%.2f", req.PointsUsed, valueRedeemed),
	}, nil
}

func (s *LoyaltyService) GetLoyaltyRedemptions(companyID int, customerID *int) ([]models.LoyaltyRedemption, error) {
	query := `
		SELECT lr.redemption_id, lr.sale_id, lr.customer_id, lr.points_used, lr.value_redeemed, lr.redeemed_at,
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
			&customerName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan redemption: %w", err)
		}

		redemption.Customer = &models.Customer{
			CustomerID: redemption.CustomerID,
			Name:       customerName,
		}

		redemptions = append(redemptions, redemption)
	}

	return redemptions, nil
}

func (s *LoyaltyService) AwardPoints(customerID int, saleAmount float64, saleID int) error {
	// Get loyalty settings
	settings, err := s.getLoyaltySettings(0) // Default settings
	if err != nil {
		return fmt.Errorf("failed to get loyalty settings: %w", err)
	}

	pointsEarned := saleAmount * settings.PointsPerCurrency

	// Start transaction
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

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

	// Log the transaction (if you have a loyalty_transactions table)
	// This is optional - you can create this table for detailed tracking

	return tx.Commit()
}

// Promotions
func (s *LoyaltyService) GetPromotions(companyID int, activeOnly bool) ([]models.Promotion, error) {
	query := `
		SELECT promotion_id, company_id, name, description, discount_type, value, min_amount,
			   start_date, end_date, applicable_to, conditions, is_active, created_at, updated_at
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
			&promotion.DiscountType, &promotion.Value, &promotion.MinAmount, &promotion.StartDate,
			&promotion.EndDate, &promotion.ApplicableTo, &promotion.Conditions, &promotion.IsActive,
			&promotion.CreatedAt, &promotion.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan promotion: %w", err)
		}
		promotions = append(promotions, promotion)
	}

	return promotions, nil
}

func (s *LoyaltyService) CreatePromotion(companyID int, req *models.CreatePromotionRequest) (*models.Promotion, error) {
	// Parse dates
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

	query := `
		INSERT INTO promotions (company_id, name, description, discount_type, value, min_amount,
							   start_date, end_date, applicable_to, conditions)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING promotion_id, created_at
	`

	var promotion models.Promotion
	err = s.db.QueryRow(query,
		companyID, req.Name, req.Description, req.DiscountType, req.Value, req.MinAmount,
		startDate, endDate, req.ApplicableTo, req.Conditions,
	).Scan(&promotion.PromotionID, &promotion.CreatedAt)

	if err != nil {
		return nil, fmt.Errorf("failed to create promotion: %w", err)
	}

	promotion.CompanyID = companyID
	promotion.Name = req.Name
	promotion.Description = req.Description
	promotion.DiscountType = req.DiscountType
	promotion.Value = req.Value
	promotion.MinAmount = req.MinAmount
	promotion.StartDate = startDate
	promotion.EndDate = endDate
	promotion.ApplicableTo = req.ApplicableTo
	promotion.Conditions = req.Conditions
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
	if req.IsActive != nil {
		argCount++
		setParts = append(setParts, fmt.Sprintf("is_active = $%d", argCount))
		args = append(args, *req.IsActive)
	}

	if len(setParts) == 0 {
		return fmt.Errorf("no fields to update")
	}

	setParts = append(setParts, "updated_at = CURRENT_TIMESTAMP")

	query := fmt.Sprintf("UPDATE promotions SET %s WHERE promotion_id = $%d",
		strings.Join(setParts, ", "), argCount+1)
	args = append(args, promotionID)

	result, err := s.db.Exec(query, args...)
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
	// Get active promotions
	promotions, err := getPromotions(s, companyID, true)
	if err != nil {
		return nil, fmt.Errorf("failed to get promotions: %w", err)
	}

	var eligiblePromotions []struct {
		PromotionID    int     `json:"promotion_id"`
		Name           string  `json:"name"`
		DiscountType   string  `json:"discount_type"`
		Value          float64 `json:"value"`
		DiscountAmount float64 `json:"discount_amount"`
	}

	totalDiscount := float64(0)

	for _, promotion := range promotions {
		// Check minimum amount requirement
		if promotion.MinAmount != nil && req.TotalAmount < *promotion.MinAmount {
			continue
		}

		// Check applicability
		if promotion.ApplicableTo != nil && *promotion.ApplicableTo != "ALL" {
			switch *promotion.ApplicableTo {
			case "PRODUCTS":
				if promotion.Conditions == nil {
					continue
				}
				rawIDs, ok := (*promotion.Conditions)["product_ids"]
				if !ok {
					continue
				}
				idsSlice, ok := rawIDs.([]interface{})
				if !ok {
					continue
				}
				condSet := make(map[int]struct{})
				for _, v := range idsSlice {
					switch id := v.(type) {
					case float64:
						condSet[int(id)] = struct{}{}
					case int:
						condSet[id] = struct{}{}
					}
				}
				match := false
				for _, pid := range req.ProductIDs {
					if _, exists := condSet[pid]; exists {
						match = true
						break
					}
				}
				if !match {
					continue
				}
			case "CATEGORIES":
				if promotion.Conditions == nil {
					continue
				}
				rawIDs, ok := (*promotion.Conditions)["category_ids"]
				if !ok {
					continue
				}
				idsSlice, ok := rawIDs.([]interface{})
				if !ok {
					continue
				}
				condSet := make(map[int]struct{})
				for _, v := range idsSlice {
					switch id := v.(type) {
					case float64:
						condSet[int(id)] = struct{}{}
					case int:
						condSet[id] = struct{}{}
					}
				}
				match := false
				for _, cid := range req.CategoryIDs {
					if _, exists := condSet[cid]; exists {
						match = true
						break
					}
				}
				if !match {
					continue
				}
			default:
				continue
			}
		}

		var discountAmount float64
		if promotion.DiscountType != nil && promotion.Value != nil {
			switch *promotion.DiscountType {
			case "PERCENTAGE":
				discountAmount = req.TotalAmount * (*promotion.Value / 100)
			case "FIXED":
				discountAmount = *promotion.Value
			default:
				continue // Skip unknown discount types
			}
		}

		if discountAmount > 0 {
			eligiblePromotions = append(eligiblePromotions, struct {
				PromotionID    int     `json:"promotion_id"`
				Name           string  `json:"name"`
				DiscountType   string  `json:"discount_type"`
				Value          float64 `json:"value"`
				DiscountAmount float64 `json:"discount_amount"`
			}{
				PromotionID:    promotion.PromotionID,
				Name:           promotion.Name,
				DiscountType:   *promotion.DiscountType,
				Value:          *promotion.Value,
				DiscountAmount: discountAmount,
			})

			totalDiscount += discountAmount
		}
	}

	return &models.PromotionEligibilityResponse{
		EligiblePromotions: eligiblePromotions,
		TotalDiscount:      totalDiscount,
	}, nil
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
	// For now, return default settings
	// In a real implementation, you'd store these in a settings table
	return &models.LoyaltySettingsResponse{
		PointsPerCurrency:   1.0,  // 1 point per $1
		PointValue:          0.01, // 1 point = $0.01
		MinRedemptionPoints: 100,  // Minimum 100 points to redeem
		PointsExpiryDays:    365,  // Points expire after 1 year
	}, nil
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
