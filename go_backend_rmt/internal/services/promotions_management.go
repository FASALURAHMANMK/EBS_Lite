package services

import (
	"bytes"
	"database/sql"
	"fmt"
	"math"
	"strings"
	"time"

	"erp-backend/internal/models"

	"github.com/google/uuid"
	"github.com/lib/pq"
	"github.com/xuri/excelize/v2"
)

func promotionDate(value string) (time.Time, error) {
	return time.Parse("2006-01-02", strings.TrimSpace(value))
}

func promoPtrFloat(v sql.NullFloat64) *float64 {
	if !v.Valid {
		return nil
	}
	x := v.Float64
	return &x
}

func promoPtrInt(v sql.NullInt64) *int {
	if !v.Valid {
		return nil
	}
	x := int(v.Int64)
	return &x
}

func promoPtrString(v sql.NullString) *string {
	if !v.Valid {
		return nil
	}
	x := v.String
	return &x
}

func promoCopyTime(v sql.NullTime) *time.Time {
	if !v.Valid {
		return nil
	}
	x := v.Time
	return &x
}

func normalizePromoCode(prefix string, length int) string {
	cleanPrefix := strings.ToUpper(strings.TrimSpace(prefix))
	raw := strings.ToUpper(strings.ReplaceAll(uuid.NewString(), "-", ""))
	bodyLen := length - len(cleanPrefix)
	if bodyLen < 4 {
		bodyLen = 4
	}
	if bodyLen > len(raw) {
		bodyLen = len(raw)
	}
	return cleanPrefix + raw[:bodyLen]
}

func (s *LoyaltyService) nextUniqueCode(tx *sql.Tx, table, column, prefix string, length int) (string, error) {
	for attempt := 0; attempt < 20; attempt++ {
		code := normalizePromoCode(prefix, length)
		query := fmt.Sprintf("SELECT COUNT(*) FROM %s WHERE %s = $1", table, column)
		var count int
		if err := tx.QueryRow(query, code).Scan(&count); err != nil {
			return "", err
		}
		if count == 0 {
			return code, nil
		}
	}
	return "", fmt.Errorf("failed to generate unique code")
}

func promoString(v *string) string {
	if v == nil {
		return ""
	}
	return *v
}

func intSetFromInterfaces(raw interface{}) map[int]struct{} {
	result := make(map[int]struct{})
	switch values := raw.(type) {
	case []interface{}:
		for _, value := range values {
			switch v := value.(type) {
			case float64:
				result[int(v)] = struct{}{}
			case int:
				result[v] = struct{}{}
			case int64:
				result[int(v)] = struct{}{}
			}
		}
	case []int:
		for _, value := range values {
			result[value] = struct{}{}
		}
	}
	return result
}

func itemMatchesPromotion(item models.PromotionEligibilityItem, promotion models.Promotion, conditions models.JSONB) bool {
	switch strings.ToUpper(strings.TrimSpace(promoString(promotion.ApplicableTo))) {
	case "", "ALL", "CUSTOMERS":
		return true
	case "PRODUCTS":
		set := intSetFromInterfaces(conditions["product_ids"])
		if len(set) == 0 {
			return true
		}
		if item.ProductID == nil {
			return false
		}
		_, ok := set[*item.ProductID]
		return ok
	case "CATEGORIES":
		set := intSetFromInterfaces(conditions["category_ids"])
		if len(set) == 0 {
			return true
		}
		if item.CategoryID == nil {
			return false
		}
		_, ok := set[*item.CategoryID]
		return ok
	default:
		return false
	}
}

func promotionCustomerMatches(customerID *int, tierID *int, promotion models.Promotion) bool {
	if promotion.Conditions == nil {
		if strings.EqualFold(promoString(promotion.ApplicableTo), "CUSTOMERS") {
			return customerID != nil
		}
		return true
	}
	conditions := *promotion.Conditions
	if raw := conditions["customer_ids"]; raw != nil {
		set := intSetFromInterfaces(raw)
		if len(set) > 0 {
			if customerID == nil {
				return false
			}
			if _, ok := set[*customerID]; !ok {
				return false
			}
		}
	}
	if raw := conditions["loyalty_tier_ids"]; raw != nil {
		set := intSetFromInterfaces(raw)
		if len(set) > 0 {
			if tierID == nil {
				return false
			}
			if _, ok := set[*tierID]; !ok {
				return false
			}
		}
	}
	if strings.EqualFold(promoString(promotion.ApplicableTo), "CUSTOMERS") {
		return customerID != nil
	}
	return true
}

func raffleCouponCount(totalAmount float64, definition models.RaffleDefinition) int {
	if definition.TriggerAmount <= 0 || totalAmount < definition.TriggerAmount {
		return 0
	}
	count := int(math.Floor(totalAmount/definition.TriggerAmount)) * definition.CouponsPerTrigger
	if definition.MaxCouponsPerSale != nil && count > *definition.MaxCouponsPerSale {
		count = *definition.MaxCouponsPerSale
	}
	if count < 0 {
		count = 0
	}
	return count
}

func (s *LoyaltyService) customerLoyaltyTier(companyID int, customerID *int) (*int, error) {
	if customerID == nil {
		return nil, nil
	}
	var tierID sql.NullInt64
	if err := s.db.QueryRow(`
		SELECT c.loyalty_tier_id
		FROM customers c
		WHERE c.customer_id = $1 AND c.company_id = $2 AND c.is_deleted = FALSE
	`, *customerID, companyID).Scan(&tierID); err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("customer not found")
		}
		return nil, err
	}
	return promoPtrInt(tierID), nil
}

func (s *LoyaltyService) attachPromotionProductRules(promotions []models.Promotion) error {
	if len(promotions) == 0 {
		return nil
	}
	ids := make([]int, 0, len(promotions))
	for _, promotion := range promotions {
		ids = append(ids, promotion.PromotionID)
	}
	rows, err := s.db.Query(`
		SELECT pr.promotion_rule_id, pr.promotion_id, pr.product_id, pr.barcode_id,
		       pr.discount_type, pr.value::float8, pr.min_qty::float8,
		       p.name, pb.barcode, pr.created_at, pr.updated_at
		FROM promotion_product_rules pr
		JOIN products p ON pr.product_id = p.product_id
		LEFT JOIN product_barcodes pb ON pr.barcode_id = pb.barcode_id
		WHERE pr.promotion_id = ANY($1)
		ORDER BY pr.promotion_id, p.name, pr.promotion_rule_id
	`, pq.Array(ids))
	if err != nil {
		if strings.Contains(err.Error(), "relation \"promotion_product_rules\" does not exist") {
			return nil
		}
		return fmt.Errorf("failed to load promotion product rules: %w", err)
	}
	defer rows.Close()

	rulesByPromotion := make(map[int][]models.PromotionProductRule, len(ids))
	for rows.Next() {
		var rule models.PromotionProductRule
		var barcodeID sql.NullInt64
		var productName string
		var barcode sql.NullString
		var updatedAt sql.NullTime
		if err := rows.Scan(
			&rule.PromotionRuleID,
			&rule.PromotionID,
			&rule.ProductID,
			&barcodeID,
			&rule.DiscountType,
			&rule.Value,
			&rule.MinQty,
			&productName,
			&barcode,
			&rule.CreatedAt,
			&updatedAt,
		); err != nil {
			return fmt.Errorf("failed to scan promotion product rule: %w", err)
		}
		rule.BarcodeID = promoPtrInt(barcodeID)
		rule.ProductName = &productName
		rule.Barcode = promoPtrString(barcode)
		rule.UpdatedAt = promoCopyTime(updatedAt)
		rulesByPromotion[rule.PromotionID] = append(rulesByPromotion[rule.PromotionID], rule)
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("failed to read promotion product rules: %w", err)
	}

	for i := range promotions {
		promotions[i].ProductRules = rulesByPromotion[promotions[i].PromotionID]
	}
	return nil
}

func (s *LoyaltyService) savePromotionProductRulesTx(tx *sql.Tx, promotionID int, rules []models.PromotionProductRuleRequest) error {
	if _, err := tx.Exec(`DELETE FROM promotion_product_rules WHERE promotion_id = $1`, promotionID); err != nil {
		if strings.Contains(err.Error(), "relation \"promotion_product_rules\" does not exist") {
			return nil
		}
		return fmt.Errorf("failed to clear promotion product rules: %w", err)
	}
	for _, rule := range rules {
		minQty := rule.MinQty
		if minQty < 0 {
			minQty = 0
		}
		if _, err := tx.Exec(`
			INSERT INTO promotion_product_rules (
				promotion_id, product_id, barcode_id, discount_type, value, min_qty
			) VALUES ($1, $2, $3, $4, $5, $6)
		`, promotionID, rule.ProductID, rule.BarcodeID, strings.ToUpper(strings.TrimSpace(rule.DiscountType)), rule.Value, minQty); err != nil {
			return fmt.Errorf("failed to save promotion product rule: %w", err)
		}
	}
	return nil
}

func (s *LoyaltyService) EvaluatePromotionEligibility(companyID int, req *models.PromotionEligibilityRequest) (*models.PromotionEligibilityResponse, error) {
	promotions, err := getPromotions(s, companyID, true)
	if err != nil {
		return nil, err
	}

	customerTierID, err := s.customerLoyaltyTier(companyID, req.CustomerID)
	if err != nil && err.Error() != "customer not found" {
		return nil, err
	}

	items := req.Items
	if len(items) == 0 && len(req.ProductIDs) > 0 {
		items = make([]models.PromotionEligibilityItem, 0, len(req.ProductIDs))
		categoryMap := make(map[int]int, len(req.CategoryIDs))
		for i, productID := range req.ProductIDs {
			var categoryID *int
			if i < len(req.CategoryIDs) {
				cid := req.CategoryIDs[i]
				categoryMap[productID] = cid
				categoryID = &cid
			} else if cid, ok := categoryMap[productID]; ok {
				categoryID = &cid
			}
			pid := productID
			items = append(items, models.PromotionEligibilityItem{
				ProductID:  &pid,
				CategoryID: categoryID,
				Quantity:   1,
				UnitPrice:  req.TotalAmount / math.Max(1, float64(len(req.ProductIDs))),
				LineTotal:  req.TotalAmount / math.Max(1, float64(len(req.ProductIDs))),
			})
		}
	}
	if len(items) == 0 && len(req.CategoryIDs) > 0 {
		items = make([]models.PromotionEligibilityItem, 0, len(req.CategoryIDs))
		for _, categoryID := range req.CategoryIDs {
			cid := categoryID
			items = append(items, models.PromotionEligibilityItem{
				CategoryID: &cid,
				Quantity:   1,
				UnitPrice:  req.TotalAmount / math.Max(1, float64(len(req.CategoryIDs))),
				LineTotal:  req.TotalAmount / math.Max(1, float64(len(req.CategoryIDs))),
			})
		}
	}

	applications := make([]models.PromotionApplication, 0)
	totalDiscount := 0.0

	for _, promotion := range promotions {
		if promotion.MinAmount != nil && req.TotalAmount < *promotion.MinAmount {
			continue
		}
		if !promotionCustomerMatches(req.CustomerID, customerTierID, promotion) {
			continue
		}

		conditions := models.JSONB{}
		if promotion.Conditions != nil {
			conditions = *promotion.Conditions
		}

		app := models.PromotionApplication{
			PromotionID:   promotion.PromotionID,
			Name:          promotion.Name,
			DiscountScope: promotion.DiscountScope,
		}

		if len(promotion.ProductRules) > 0 {
			lineItems := make([]models.PromotionLineApplication, 0)
			for _, item := range items {
				if !itemMatchesPromotion(item, promotion, conditions) {
					continue
				}
				for _, rule := range promotion.ProductRules {
					if item.ProductID == nil || *item.ProductID != rule.ProductID {
						continue
					}
					if rule.BarcodeID != nil && item.BarcodeID != nil && *rule.BarcodeID != *item.BarcodeID {
						continue
					}
					if rule.MinQty > 0 && item.Quantity < rule.MinQty {
						continue
					}
					discountAmount := 0.0
					discountType := strings.ToUpper(strings.TrimSpace(rule.DiscountType))
					var adjustedPrice *float64
					switch discountType {
					case "PERCENTAGE":
						discountAmount = item.LineTotal * (rule.Value / 100)
					case "FIXED":
						discountAmount = rule.Value
					case "FIXED_PRICE":
						targetLine := item.Quantity * rule.Value
						if item.LineTotal > targetLine {
							discountAmount = item.LineTotal - targetLine
							price := rule.Value
							adjustedPrice = &price
						}
					}
					if discountAmount <= 0 {
						continue
					}
					lineItems = append(lineItems, models.PromotionLineApplication{
						ProductID:       item.ProductID,
						BarcodeID:       item.BarcodeID,
						ProductName:     item.ProductName,
						Quantity:        item.Quantity,
						DiscountType:    discountType,
						Value:           rule.Value,
						DiscountAmount:  discountAmount,
						AdjustedPrice:   adjustedPrice,
						PromotionRuleID: &rule.PromotionRuleID,
					})
					totalDiscount += discountAmount
					app.DiscountAmount += discountAmount
				}
			}
			if len(lineItems) == 0 {
				continue
			}
			app.LineItems = lineItems
			app.DiscountType = "ITEM_RULES"
			applications = append(applications, app)
			continue
		}

		if promotion.DiscountType == nil || promotion.Value == nil {
			continue
		}

		targetAmount := req.TotalAmount
		if len(items) > 0 {
			matchedAmount := 0.0
			matchedCount := 0
			for _, item := range items {
				if itemMatchesPromotion(item, promotion, conditions) {
					matchedAmount += item.LineTotal
					matchedCount++
				}
			}
			if !strings.EqualFold(promoString(promotion.ApplicableTo), "") &&
				!strings.EqualFold(promoString(promotion.ApplicableTo), "ALL") &&
				!strings.EqualFold(promoString(promotion.ApplicableTo), "CUSTOMERS") &&
				matchedCount == 0 {
				continue
			}
			if strings.EqualFold(promotion.DiscountScope, "ITEM") {
				targetAmount = matchedAmount
				if targetAmount <= 0 {
					continue
				}
			}
		}

		app.DiscountType = strings.ToUpper(strings.TrimSpace(*promotion.DiscountType))
		app.Value = *promotion.Value
		switch app.DiscountType {
		case "PERCENTAGE":
			app.DiscountAmount = targetAmount * (*promotion.Value / 100)
		case "FIXED":
			app.DiscountAmount = *promotion.Value
		default:
			continue
		}
		if app.DiscountAmount <= 0 {
			continue
		}
		totalDiscount += app.DiscountAmount
		applications = append(applications, app)
	}

	return &models.PromotionEligibilityResponse{
		EligiblePromotions: applications,
		TotalDiscount:      totalDiscount,
	}, nil
}

func (s *LoyaltyService) GetCouponSeries(companyID int, activeOnly bool) ([]models.CouponSeries, error) {
	query := `
		SELECT cs.coupon_series_id, cs.company_id, cs.name, cs.description, cs.prefix,
		       cs.code_length, cs.discount_type, cs.discount_value::float8,
		       cs.min_purchase_amount::float8, cs.max_discount_amount::float8,
		       cs.start_date, cs.end_date, cs.total_coupons,
		       cs.usage_limit_per_coupon, cs.usage_limit_per_customer, cs.is_active,
		       cs.created_by, cs.created_at, cs.updated_at,
		       COALESCE(SUM(CASE WHEN cc.status = 'AVAILABLE' THEN 1 ELSE 0 END), 0)::int AS available_coupons,
		       COALESCE(SUM(CASE WHEN cc.status = 'REDEEMED' THEN 1 ELSE 0 END), 0)::int AS redeemed_coupons
		FROM coupon_series cs
		LEFT JOIN coupon_codes cc ON cc.coupon_series_id = cs.coupon_series_id
		WHERE cs.company_id = $1
	`
	if activeOnly {
		query += ` AND cs.is_active = TRUE AND cs.start_date <= CURRENT_DATE AND cs.end_date >= CURRENT_DATE`
	}
	query += `
		GROUP BY cs.coupon_series_id
		ORDER BY cs.start_date DESC, cs.coupon_series_id DESC
	`

	rows, err := s.db.Query(query, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get coupon series: %w", err)
	}
	defer rows.Close()

	series := make([]models.CouponSeries, 0)
	for rows.Next() {
		var item models.CouponSeries
		var description sql.NullString
		var maxDiscount sql.NullFloat64
		var createdBy sql.NullInt64
		var updatedAt sql.NullTime
		if err := rows.Scan(
			&item.CouponSeriesID,
			&item.CompanyID,
			&item.Name,
			&description,
			&item.Prefix,
			&item.CodeLength,
			&item.DiscountType,
			&item.DiscountValue,
			&item.MinPurchaseAmount,
			&maxDiscount,
			&item.StartDate,
			&item.EndDate,
			&item.TotalCoupons,
			&item.UsageLimitPerCoupon,
			&item.UsageLimitPerCustomer,
			&item.IsActive,
			&createdBy,
			&item.CreatedAt,
			&updatedAt,
			&item.AvailableCoupons,
			&item.RedeemedCoupons,
		); err != nil {
			return nil, fmt.Errorf("failed to scan coupon series: %w", err)
		}
		item.Description = promoPtrString(description)
		item.MaxDiscountAmount = promoPtrFloat(maxDiscount)
		item.CreatedBy = promoPtrInt(createdBy)
		item.UpdatedAt = promoCopyTime(updatedAt)
		series = append(series, item)
	}
	return series, rows.Err()
}

func (s *LoyaltyService) createCouponCodesTx(tx *sql.Tx, seriesID int, prefix string, length, count int) error {
	for i := 0; i < count; i++ {
		code, err := s.nextUniqueCode(tx, "coupon_codes", "code", prefix, length)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(`
			INSERT INTO coupon_codes (coupon_series_id, code)
			VALUES ($1, $2)
		`, seriesID, code); err != nil {
			return fmt.Errorf("failed to create coupon code: %w", err)
		}
	}
	return nil
}

func (s *LoyaltyService) CreateCouponSeries(companyID, userID int, req *models.CreateCouponSeriesRequest) (*models.CouponSeries, error) {
	startDate, err := promotionDate(req.StartDate)
	if err != nil {
		return nil, fmt.Errorf("invalid start date: %w", err)
	}
	endDate, err := promotionDate(req.EndDate)
	if err != nil {
		return nil, fmt.Errorf("invalid end date: %w", err)
	}
	if endDate.Before(startDate) {
		return nil, fmt.Errorf("end date cannot be before start date")
	}
	if req.UsageLimitPerCoupon == 0 {
		req.UsageLimitPerCoupon = 1
	}
	if req.UsageLimitPerCustomer == 0 {
		req.UsageLimitPerCustomer = 1
	}
	isActive := true
	if req.IsActive != nil {
		isActive = *req.IsActive
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	var seriesID int
	if err := tx.QueryRow(`
		INSERT INTO coupon_series (
			company_id, name, description, prefix, code_length, discount_type, discount_value,
			min_purchase_amount, max_discount_amount, start_date, end_date, total_coupons,
			usage_limit_per_coupon, usage_limit_per_customer, is_active, created_by
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7,
			$8, $9, $10, $11, $12,
			$13, $14, $15, $16
		) RETURNING coupon_series_id
	`, companyID, req.Name, req.Description, strings.ToUpper(strings.TrimSpace(req.Prefix)), req.CodeLength,
		req.DiscountType, req.DiscountValue, req.MinPurchaseAmount, req.MaxDiscountAmount,
		startDate, endDate, req.TotalCoupons, req.UsageLimitPerCoupon, req.UsageLimitPerCustomer, isActive, userID,
	).Scan(&seriesID); err != nil {
		return nil, fmt.Errorf("failed to create coupon series: %w", err)
	}

	if err := s.createCouponCodesTx(tx, seriesID, req.Prefix, req.CodeLength, req.TotalCoupons); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}

	items, err := s.GetCouponSeries(companyID, false)
	if err != nil {
		return nil, err
	}
	for _, item := range items {
		if item.CouponSeriesID == seriesID {
			return &item, nil
		}
	}
	return nil, fmt.Errorf("coupon series not found after create")
}

func (s *LoyaltyService) UpdateCouponSeries(companyID, seriesID int, req *models.UpdateCouponSeriesRequest) error {
	parts := make([]string, 0)
	args := make([]interface{}, 0)
	arg := 0

	if req.Name != nil {
		arg++
		parts = append(parts, fmt.Sprintf("name = $%d", arg))
		args = append(args, *req.Name)
	}
	if req.Description != nil {
		arg++
		parts = append(parts, fmt.Sprintf("description = $%d", arg))
		args = append(args, *req.Description)
	}
	if req.Prefix != nil {
		arg++
		parts = append(parts, fmt.Sprintf("prefix = $%d", arg))
		args = append(args, strings.ToUpper(strings.TrimSpace(*req.Prefix)))
	}
	if req.CodeLength != nil {
		arg++
		parts = append(parts, fmt.Sprintf("code_length = $%d", arg))
		args = append(args, *req.CodeLength)
	}
	if req.DiscountType != nil {
		arg++
		parts = append(parts, fmt.Sprintf("discount_type = $%d", arg))
		args = append(args, strings.ToUpper(strings.TrimSpace(*req.DiscountType)))
	}
	if req.DiscountValue != nil {
		arg++
		parts = append(parts, fmt.Sprintf("discount_value = $%d", arg))
		args = append(args, *req.DiscountValue)
	}
	if req.MinPurchaseAmount != nil {
		arg++
		parts = append(parts, fmt.Sprintf("min_purchase_amount = $%d", arg))
		args = append(args, *req.MinPurchaseAmount)
	}
	if req.MaxDiscountAmount != nil {
		arg++
		parts = append(parts, fmt.Sprintf("max_discount_amount = $%d", arg))
		args = append(args, *req.MaxDiscountAmount)
	}
	if req.StartDate != nil {
		startDate, err := promotionDate(*req.StartDate)
		if err != nil {
			return fmt.Errorf("invalid start date: %w", err)
		}
		arg++
		parts = append(parts, fmt.Sprintf("start_date = $%d", arg))
		args = append(args, startDate)
	}
	if req.EndDate != nil {
		endDate, err := promotionDate(*req.EndDate)
		if err != nil {
			return fmt.Errorf("invalid end date: %w", err)
		}
		arg++
		parts = append(parts, fmt.Sprintf("end_date = $%d", arg))
		args = append(args, endDate)
	}
	if req.UsageLimitPerCoupon != nil {
		arg++
		parts = append(parts, fmt.Sprintf("usage_limit_per_coupon = $%d", arg))
		args = append(args, *req.UsageLimitPerCoupon)
	}
	if req.UsageLimitPerCustomer != nil {
		arg++
		parts = append(parts, fmt.Sprintf("usage_limit_per_customer = $%d", arg))
		args = append(args, *req.UsageLimitPerCustomer)
	}
	if req.IsActive != nil {
		arg++
		parts = append(parts, fmt.Sprintf("is_active = $%d", arg))
		args = append(args, *req.IsActive)
	}
	if len(parts) == 0 {
		return nil
	}
	parts = append(parts, "updated_at = CURRENT_TIMESTAMP")
	arg++
	args = append(args, seriesID)
	query := fmt.Sprintf(`
		UPDATE coupon_series SET %s
		WHERE coupon_series_id = $%d AND company_id = %d
	`, strings.Join(parts, ", "), arg, companyID)
	res, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update coupon series: %w", err)
	}
	rows, _ := res.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("coupon series not found")
	}
	return nil
}

func (s *LoyaltyService) DeleteCouponSeries(companyID, seriesID int) error {
	res, err := s.db.Exec(`
		UPDATE coupon_series
		SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP
		WHERE coupon_series_id = $1 AND company_id = $2
	`, seriesID, companyID)
	if err != nil {
		return fmt.Errorf("failed to delete coupon series: %w", err)
	}
	rows, _ := res.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("coupon series not found")
	}
	return nil
}

func (s *LoyaltyService) GetCouponCodes(companyID, seriesID int) ([]models.CouponCode, error) {
	rows, err := s.db.Query(`
		SELECT cc.coupon_code_id, cc.coupon_series_id, cc.code, cc.status, cc.redeem_count,
		       cc.issued_to_customer_id, cc.issued_sale_id, cc.redeemed_sale_id,
		       cc.issued_at, cc.redeemed_at, cc.created_at, cc.updated_at
		FROM coupon_codes cc
		JOIN coupon_series cs ON cs.coupon_series_id = cc.coupon_series_id
		WHERE cs.company_id = $1 AND cs.coupon_series_id = $2
		ORDER BY cc.code
	`, companyID, seriesID)
	if err != nil {
		return nil, fmt.Errorf("failed to get coupon codes: %w", err)
	}
	defer rows.Close()

	codes := make([]models.CouponCode, 0)
	for rows.Next() {
		var item models.CouponCode
		var issuedCustomer sql.NullInt64
		var issuedSale sql.NullInt64
		var redeemedSale sql.NullInt64
		var issuedAt sql.NullTime
		var redeemedAt sql.NullTime
		var updatedAt sql.NullTime
		if err := rows.Scan(
			&item.CouponCodeID,
			&item.CouponSeriesID,
			&item.Code,
			&item.Status,
			&item.RedeemCount,
			&issuedCustomer,
			&issuedSale,
			&redeemedSale,
			&issuedAt,
			&redeemedAt,
			&item.CreatedAt,
			&updatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan coupon code: %w", err)
		}
		item.IssuedToCustomerID = promoPtrInt(issuedCustomer)
		item.IssuedSaleID = promoPtrInt(issuedSale)
		item.RedeemedSaleID = promoPtrInt(redeemedSale)
		item.IssuedAt = promoCopyTime(issuedAt)
		item.RedeemedAt = promoCopyTime(redeemedAt)
		item.UpdatedAt = promoCopyTime(updatedAt)
		codes = append(codes, item)
	}
	return codes, rows.Err()
}

func (s *LoyaltyService) ValidateCouponCode(companyID int, req *models.ValidateCouponCodeRequest) (*models.CouponValidationResponse, error) {
	var (
		seriesID              int
		name                  string
		discountType          string
		discountValue         float64
		minPurchaseAmount     float64
		maxDiscountAmount     sql.NullFloat64
		usageLimitPerCoupon   int
		usageLimitPerCustomer int
		redeemCount           int
		status                string
	)

	code := strings.ToUpper(strings.TrimSpace(req.Code))
	err := s.db.QueryRow(`
		SELECT cs.coupon_series_id, cs.name, cs.discount_type, cs.discount_value::float8,
		       cs.min_purchase_amount::float8, cs.max_discount_amount::float8,
		       cs.usage_limit_per_coupon, cs.usage_limit_per_customer,
		       cc.redeem_count, cc.status
		FROM coupon_codes cc
		JOIN coupon_series cs ON cs.coupon_series_id = cc.coupon_series_id
		WHERE cs.company_id = $1
		  AND cc.code = $2
		  AND cs.is_active = TRUE
		  AND cs.start_date <= CURRENT_DATE
		  AND cs.end_date >= CURRENT_DATE
	`, companyID, code).Scan(
		&seriesID,
		&name,
		&discountType,
		&discountValue,
		&minPurchaseAmount,
		&maxDiscountAmount,
		&usageLimitPerCoupon,
		&usageLimitPerCustomer,
		&redeemCount,
		&status,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("coupon code not found")
		}
		return nil, fmt.Errorf("failed to validate coupon code: %w", err)
	}
	if status == "VOID" {
		return nil, fmt.Errorf("coupon code is not active")
	}
	if usageLimitPerCoupon > 0 && redeemCount >= usageLimitPerCoupon {
		return nil, fmt.Errorf("coupon code already used")
	}
	if req.SaleAmount < minPurchaseAmount {
		return nil, fmt.Errorf("sale amount does not meet coupon minimum")
	}
	if req.CustomerID != nil && usageLimitPerCustomer > 0 {
		var customerUses int
		if err := s.db.QueryRow(`
			SELECT COUNT(*)
			FROM coupon_codes cc
			WHERE cc.coupon_series_id = $1
			  AND cc.issued_to_customer_id = $2
			  AND cc.redeem_count > 0
		`, seriesID, *req.CustomerID).Scan(&customerUses); err != nil {
			return nil, fmt.Errorf("failed to check coupon usage: %w", err)
		}
		if customerUses >= usageLimitPerCustomer {
			return nil, fmt.Errorf("customer has reached coupon usage limit")
		}
	}

	discountAmount := 0.0
	switch strings.ToUpper(strings.TrimSpace(discountType)) {
	case "PERCENTAGE":
		discountAmount = req.SaleAmount * (discountValue / 100)
	case "FIXED_AMOUNT":
		discountAmount = discountValue
	default:
		return nil, fmt.Errorf("unsupported coupon discount type")
	}
	if maxDiscountAmount.Valid && discountAmount > maxDiscountAmount.Float64 {
		discountAmount = maxDiscountAmount.Float64
	}
	if discountAmount > req.SaleAmount {
		discountAmount = req.SaleAmount
	}
	if discountAmount <= 0 {
		return nil, fmt.Errorf("coupon discount is zero")
	}

	return &models.CouponValidationResponse{
		CouponSeriesID:    seriesID,
		SeriesName:        name,
		Code:              code,
		DiscountType:      discountType,
		DiscountValue:     discountValue,
		DiscountAmount:    discountAmount,
		MinPurchaseAmount: minPurchaseAmount,
		MaxDiscountAmount: promoPtrFloat(maxDiscountAmount),
	}, nil
}

func (s *LoyaltyService) RedeemCouponCode(companyID int, code string, saleID int, customerID *int) error {
	var saleAmount float64
	if err := s.db.QueryRow(`
		SELECT total_amount::float8
		FROM sales s
		JOIN locations l ON l.location_id = s.location_id
		WHERE s.sale_id = $1 AND l.company_id = $2 AND s.is_deleted = FALSE
	`, saleID, companyID).Scan(&saleAmount); err != nil {
		return fmt.Errorf("failed to load sale amount: %w", err)
	}
	if _, err := s.ValidateCouponCode(companyID, &models.ValidateCouponCodeRequest{
		Code:       code,
		CustomerID: customerID,
		SaleAmount: saleAmount,
	}); err != nil {
		return err
	}

	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var usageLimit int
	var redeemCount int
	if err := tx.QueryRow(`
		SELECT cs.usage_limit_per_coupon, cc.redeem_count
		FROM coupon_codes cc
		JOIN coupon_series cs ON cs.coupon_series_id = cc.coupon_series_id
		WHERE cc.code = $1 AND cs.company_id = $2
		FOR UPDATE
	`, strings.ToUpper(strings.TrimSpace(code)), companyID).Scan(&usageLimit, &redeemCount); err != nil {
		return fmt.Errorf("failed to lock coupon code: %w", err)
	}
	newCount := redeemCount + 1
	status := "AVAILABLE"
	if usageLimit <= 1 || newCount >= usageLimit {
		status = "REDEEMED"
	}
	if _, err := tx.Exec(`
		UPDATE coupon_codes
		SET redeem_count = $1,
		    status = $2,
		    issued_to_customer_id = COALESCE($3, issued_to_customer_id),
		    redeemed_sale_id = $4,
		    redeemed_at = CURRENT_TIMESTAMP,
		    updated_at = CURRENT_TIMESTAMP
		WHERE code = $5
	`, newCount, status, customerID, saleID, strings.ToUpper(strings.TrimSpace(code))); err != nil {
		return fmt.Errorf("failed to redeem coupon code: %w", err)
	}

	return tx.Commit()
}

func (s *LoyaltyService) GetRaffleDefinitions(companyID int, activeOnly bool) ([]models.RaffleDefinition, error) {
	query := `
		SELECT rd.raffle_definition_id, rd.company_id, rd.name, rd.description, rd.prefix,
		       rd.code_length, rd.start_date, rd.end_date, rd.trigger_amount::float8,
		       rd.coupons_per_trigger, rd.max_coupons_per_sale,
		       rd.default_auto_fill_customer_data, rd.print_after_invoice, rd.is_active,
		       rd.created_by, rd.created_at, rd.updated_at,
		       COUNT(rc.raffle_coupon_id)::int AS issued_coupons,
		       COALESCE(SUM(CASE WHEN rc.status = 'WINNER' THEN 1 ELSE 0 END), 0)::int AS winner_count
		FROM raffle_definitions rd
		LEFT JOIN raffle_coupons rc ON rc.raffle_definition_id = rd.raffle_definition_id
		WHERE rd.company_id = $1
	`
	if activeOnly {
		query += ` AND rd.is_active = TRUE AND rd.start_date <= CURRENT_DATE AND rd.end_date >= CURRENT_DATE`
	}
	query += `
		GROUP BY rd.raffle_definition_id
		ORDER BY rd.start_date DESC, rd.raffle_definition_id DESC
	`

	rows, err := s.db.Query(query, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get raffle definitions: %w", err)
	}
	defer rows.Close()

	items := make([]models.RaffleDefinition, 0)
	for rows.Next() {
		var item models.RaffleDefinition
		var description sql.NullString
		var maxCoupons sql.NullInt64
		var createdBy sql.NullInt64
		var updatedAt sql.NullTime
		if err := rows.Scan(
			&item.RaffleDefinitionID,
			&item.CompanyID,
			&item.Name,
			&description,
			&item.Prefix,
			&item.CodeLength,
			&item.StartDate,
			&item.EndDate,
			&item.TriggerAmount,
			&item.CouponsPerTrigger,
			&maxCoupons,
			&item.DefaultAutoFillCustomerData,
			&item.PrintAfterInvoice,
			&item.IsActive,
			&createdBy,
			&item.CreatedAt,
			&updatedAt,
			&item.IssuedCoupons,
			&item.WinnerCount,
		); err != nil {
			return nil, fmt.Errorf("failed to scan raffle definition: %w", err)
		}
		item.Description = promoPtrString(description)
		item.MaxCouponsPerSale = promoPtrInt(maxCoupons)
		item.CreatedBy = promoPtrInt(createdBy)
		item.UpdatedAt = promoCopyTime(updatedAt)
		items = append(items, item)
	}
	return items, rows.Err()
}

func (s *LoyaltyService) CreateRaffleDefinition(companyID, userID int, req *models.CreateRaffleDefinitionRequest) (*models.RaffleDefinition, error) {
	startDate, err := promotionDate(req.StartDate)
	if err != nil {
		return nil, fmt.Errorf("invalid start date: %w", err)
	}
	endDate, err := promotionDate(req.EndDate)
	if err != nil {
		return nil, fmt.Errorf("invalid end date: %w", err)
	}
	if endDate.Before(startDate) {
		return nil, fmt.Errorf("end date cannot be before start date")
	}
	isActive := true
	if req.IsActive != nil {
		isActive = *req.IsActive
	}

	var item models.RaffleDefinition
	var description sql.NullString
	var maxCoupons sql.NullInt64
	var createdBy sql.NullInt64
	var updatedAt sql.NullTime
	if err := s.db.QueryRow(`
		INSERT INTO raffle_definitions (
			company_id, name, description, prefix, code_length, start_date, end_date,
			trigger_amount, coupons_per_trigger, max_coupons_per_sale,
			default_auto_fill_customer_data, print_after_invoice, is_active, created_by
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7,
			$8, $9, $10, $11, $12, $13, $14
		)
		RETURNING raffle_definition_id, company_id, name, description, prefix, code_length,
		          start_date, end_date, trigger_amount::float8, coupons_per_trigger, max_coupons_per_sale,
		          default_auto_fill_customer_data, print_after_invoice, is_active, created_by, created_at, updated_at
	`, companyID, req.Name, req.Description, strings.ToUpper(strings.TrimSpace(req.Prefix)), req.CodeLength,
		startDate, endDate, req.TriggerAmount, req.CouponsPerTrigger, req.MaxCouponsPerSale,
		req.DefaultAutoFillCustomerData, req.PrintAfterInvoice, isActive, userID,
	).Scan(
		&item.RaffleDefinitionID, &item.CompanyID, &item.Name, &description, &item.Prefix, &item.CodeLength,
		&item.StartDate, &item.EndDate, &item.TriggerAmount, &item.CouponsPerTrigger, &maxCoupons,
		&item.DefaultAutoFillCustomerData, &item.PrintAfterInvoice, &item.IsActive, &createdBy, &item.CreatedAt, &updatedAt,
	); err != nil {
		return nil, fmt.Errorf("failed to create raffle definition: %w", err)
	}
	item.Description = promoPtrString(description)
	item.MaxCouponsPerSale = promoPtrInt(maxCoupons)
	item.CreatedBy = promoPtrInt(createdBy)
	item.UpdatedAt = promoCopyTime(updatedAt)
	return &item, nil
}

func (s *LoyaltyService) UpdateRaffleDefinition(companyID, id int, req *models.UpdateRaffleDefinitionRequest) error {
	parts := make([]string, 0)
	args := make([]interface{}, 0)
	arg := 0

	if req.Name != nil {
		arg++
		parts = append(parts, fmt.Sprintf("name = $%d", arg))
		args = append(args, *req.Name)
	}
	if req.Description != nil {
		arg++
		parts = append(parts, fmt.Sprintf("description = $%d", arg))
		args = append(args, *req.Description)
	}
	if req.Prefix != nil {
		arg++
		parts = append(parts, fmt.Sprintf("prefix = $%d", arg))
		args = append(args, strings.ToUpper(strings.TrimSpace(*req.Prefix)))
	}
	if req.CodeLength != nil {
		arg++
		parts = append(parts, fmt.Sprintf("code_length = $%d", arg))
		args = append(args, *req.CodeLength)
	}
	if req.StartDate != nil {
		date, err := promotionDate(*req.StartDate)
		if err != nil {
			return err
		}
		arg++
		parts = append(parts, fmt.Sprintf("start_date = $%d", arg))
		args = append(args, date)
	}
	if req.EndDate != nil {
		date, err := promotionDate(*req.EndDate)
		if err != nil {
			return err
		}
		arg++
		parts = append(parts, fmt.Sprintf("end_date = $%d", arg))
		args = append(args, date)
	}
	if req.TriggerAmount != nil {
		arg++
		parts = append(parts, fmt.Sprintf("trigger_amount = $%d", arg))
		args = append(args, *req.TriggerAmount)
	}
	if req.CouponsPerTrigger != nil {
		arg++
		parts = append(parts, fmt.Sprintf("coupons_per_trigger = $%d", arg))
		args = append(args, *req.CouponsPerTrigger)
	}
	if req.MaxCouponsPerSale != nil {
		arg++
		parts = append(parts, fmt.Sprintf("max_coupons_per_sale = $%d", arg))
		args = append(args, *req.MaxCouponsPerSale)
	}
	if req.DefaultAutoFillCustomerData != nil {
		arg++
		parts = append(parts, fmt.Sprintf("default_auto_fill_customer_data = $%d", arg))
		args = append(args, *req.DefaultAutoFillCustomerData)
	}
	if req.PrintAfterInvoice != nil {
		arg++
		parts = append(parts, fmt.Sprintf("print_after_invoice = $%d", arg))
		args = append(args, *req.PrintAfterInvoice)
	}
	if req.IsActive != nil {
		arg++
		parts = append(parts, fmt.Sprintf("is_active = $%d", arg))
		args = append(args, *req.IsActive)
	}
	if len(parts) == 0 {
		return nil
	}
	parts = append(parts, "updated_at = CURRENT_TIMESTAMP")
	arg++
	args = append(args, id)
	query := fmt.Sprintf(`
		UPDATE raffle_definitions SET %s
		WHERE raffle_definition_id = $%d AND company_id = %d
	`, strings.Join(parts, ", "), arg, companyID)
	res, err := s.db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update raffle definition: %w", err)
	}
	rows, _ := res.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("raffle definition not found")
	}
	return nil
}

func (s *LoyaltyService) DeleteRaffleDefinition(companyID, id int) error {
	res, err := s.db.Exec(`
		UPDATE raffle_definitions
		SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP
		WHERE raffle_definition_id = $1 AND company_id = $2
	`, id, companyID)
	if err != nil {
		return fmt.Errorf("failed to delete raffle definition: %w", err)
	}
	rows, _ := res.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("raffle definition not found")
	}
	return nil
}

func (s *LoyaltyService) GetRaffleCoupons(companyID int, definitionID *int, saleID *int) ([]models.RaffleCoupon, error) {
	query := `
		SELECT rc.raffle_coupon_id, rc.raffle_definition_id, rc.sale_id, rc.customer_id,
		       rc.coupon_code, rc.status, rc.auto_filled, rd.print_after_invoice,
		       rc.customer_name, rc.customer_phone,
		       rc.customer_email, rc.customer_address, rc.winner_name, rc.winner_notes,
		       rc.issued_at, rc.winner_marked_at, rc.created_at, rc.updated_at,
		       rd.name, s.sale_number
		FROM raffle_coupons rc
		JOIN raffle_definitions rd ON rd.raffle_definition_id = rc.raffle_definition_id
		JOIN sales s ON s.sale_id = rc.sale_id
		JOIN locations l ON l.location_id = s.location_id
		WHERE l.company_id = $1
	`
	args := []interface{}{companyID}
	arg := 1
	if definitionID != nil {
		arg++
		query += fmt.Sprintf(" AND rc.raffle_definition_id = $%d", arg)
		args = append(args, *definitionID)
	}
	if saleID != nil {
		arg++
		query += fmt.Sprintf(" AND rc.sale_id = $%d", arg)
		args = append(args, *saleID)
	}
	query += " ORDER BY rc.issued_at DESC, rc.raffle_coupon_id DESC"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get raffle coupons: %w", err)
	}
	defer rows.Close()

	items := make([]models.RaffleCoupon, 0)
	for rows.Next() {
		var item models.RaffleCoupon
		var customerID sql.NullInt64
		var customerName sql.NullString
		var customerPhone sql.NullString
		var customerEmail sql.NullString
		var customerAddress sql.NullString
		var winnerName sql.NullString
		var winnerNotes sql.NullString
		var winnerMarkedAt sql.NullTime
		var updatedAt sql.NullTime
		var definitionName sql.NullString
		var saleNumber sql.NullString
		if err := rows.Scan(
			&item.RaffleCouponID,
			&item.RaffleDefinitionID,
			&item.SaleID,
			&customerID,
			&item.CouponCode,
			&item.Status,
			&item.AutoFilled,
			&item.PrintAfterInvoice,
			&customerName,
			&customerPhone,
			&customerEmail,
			&customerAddress,
			&winnerName,
			&winnerNotes,
			&item.IssuedAt,
			&winnerMarkedAt,
			&item.CreatedAt,
			&updatedAt,
			&definitionName,
			&saleNumber,
		); err != nil {
			return nil, fmt.Errorf("failed to scan raffle coupon: %w", err)
		}
		item.CustomerID = promoPtrInt(customerID)
		item.CustomerName = promoPtrString(customerName)
		item.CustomerPhone = promoPtrString(customerPhone)
		item.CustomerEmail = promoPtrString(customerEmail)
		item.CustomerAddress = promoPtrString(customerAddress)
		item.WinnerName = promoPtrString(winnerName)
		item.WinnerNotes = promoPtrString(winnerNotes)
		item.WinnerMarkedAt = promoCopyTime(winnerMarkedAt)
		item.UpdatedAt = promoCopyTime(updatedAt)
		item.RaffleDefinitionName = promoPtrString(definitionName)
		item.SaleNumber = promoPtrString(saleNumber)
		items = append(items, item)
	}
	return items, rows.Err()
}

func (s *LoyaltyService) MarkRaffleWinner(companyID, couponID int, req *models.MarkRaffleWinnerRequest) error {
	res, err := s.db.Exec(`
		UPDATE raffle_coupons rc
		SET status = 'WINNER',
		    winner_name = $1,
		    winner_notes = $2,
		    winner_marked_at = CURRENT_TIMESTAMP,
		    updated_at = CURRENT_TIMESTAMP
		FROM sales s
		JOIN locations l ON l.location_id = s.location_id
		WHERE rc.raffle_coupon_id = $3
		  AND rc.sale_id = s.sale_id
		  AND l.company_id = $4
	`, req.WinnerName, req.WinnerNotes, couponID, companyID)
	if err != nil {
		return fmt.Errorf("failed to mark raffle winner: %w", err)
	}
	rows, _ := res.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("raffle coupon not found")
	}
	return nil
}

func (s *LoyaltyService) IssueRaffleCouponsForSale(companyID, saleID int, customerID *int, autoFillOverride *bool) ([]models.RaffleCoupon, error) {
	var (
		totalAmount     float64
		customerName    sql.NullString
		customerPhone   sql.NullString
		customerEmail   sql.NullString
		customerAddress sql.NullString
	)
	if err := s.db.QueryRow(`
		SELECT s.total_amount::float8,
		       c.name, c.phone, c.email, c.address
		FROM sales s
		JOIN locations l ON l.location_id = s.location_id
		LEFT JOIN customers c ON c.customer_id = s.customer_id
		WHERE s.sale_id = $1 AND l.company_id = $2 AND s.is_deleted = FALSE
	`, saleID, companyID).Scan(&totalAmount, &customerName, &customerPhone, &customerEmail, &customerAddress); err != nil {
		return nil, fmt.Errorf("failed to load sale for raffle issuance: %w", err)
	}

	definitions, err := s.GetRaffleDefinitions(companyID, true)
	if err != nil {
		return nil, err
	}
	if len(definitions) == 0 {
		return nil, nil
	}

	tx, err := s.db.Begin()
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	issued := make([]models.RaffleCoupon, 0)
	for _, definition := range definitions {
		count := raffleCouponCount(totalAmount, definition)
		if count == 0 {
			continue
		}
		autoFill := definition.DefaultAutoFillCustomerData
		if autoFillOverride != nil {
			autoFill = *autoFillOverride
		}
		for i := 0; i < count; i++ {
			code, err := s.nextUniqueCode(tx, "raffle_coupons", "coupon_code", definition.Prefix, definition.CodeLength)
			if err != nil {
				return nil, err
			}
			var item models.RaffleCoupon
			var customerIDNull sql.NullInt64
			var winnerMarkedAt sql.NullTime
			var updatedAt sql.NullTime
			if customerID != nil {
				customerIDNull = sql.NullInt64{Int64: int64(*customerID), Valid: true}
			}
			if err := tx.QueryRow(`
				INSERT INTO raffle_coupons (
					raffle_definition_id, sale_id, customer_id, coupon_code, auto_filled,
					customer_name, customer_phone, customer_email, customer_address
				) VALUES (
					$1, $2, $3, $4, $5, $6, $7, $8, $9
				)
				RETURNING raffle_coupon_id, raffle_definition_id, sale_id, customer_id, coupon_code, status,
				          auto_filled, customer_name, customer_phone, customer_email, customer_address,
				          winner_name, winner_notes, issued_at, winner_marked_at, created_at, updated_at
			`, definition.RaffleDefinitionID, saleID, customerIDNull, code, autoFill,
				func() interface{} {
					if autoFill {
						return customerName
					}
					return nil
				}(),
				func() interface{} {
					if autoFill {
						return customerPhone
					}
					return nil
				}(),
				func() interface{} {
					if autoFill {
						return customerEmail
					}
					return nil
				}(),
				func() interface{} {
					if autoFill {
						return customerAddress
					}
					return nil
				}(),
			).Scan(
				&item.RaffleCouponID,
				&item.RaffleDefinitionID,
				&item.SaleID,
				&customerIDNull,
				&item.CouponCode,
				&item.Status,
				&item.AutoFilled,
				&customerName,
				&customerPhone,
				&customerEmail,
				&customerAddress,
				&item.WinnerName,
				&item.WinnerNotes,
				&item.IssuedAt,
				&winnerMarkedAt,
				&item.CreatedAt,
				&updatedAt,
			); err != nil {
				return nil, fmt.Errorf("failed to issue raffle coupon: %w", err)
			}
			item.CustomerID = promoPtrInt(customerIDNull)
			item.CustomerName = promoPtrString(customerName)
			item.CustomerPhone = promoPtrString(customerPhone)
			item.CustomerEmail = promoPtrString(customerEmail)
			item.CustomerAddress = promoPtrString(customerAddress)
			item.WinnerMarkedAt = promoCopyTime(winnerMarkedAt)
			item.UpdatedAt = promoCopyTime(updatedAt)
			definitionName := definition.Name
			item.RaffleDefinitionName = &definitionName
			issued = append(issued, item)
		}
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return issued, nil
}

func (s *LoyaltyService) ImportPromotionProductRules(companyID, userID int, data []byte) (*models.ImportResult, error) {
	xl, err := excelize.OpenReader(bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("failed to open workbook: %w", err)
	}
	sheet := xl.GetSheetName(0)
	rows, err := xl.GetRows(sheet)
	if err != nil {
		return nil, fmt.Errorf("failed to read sheet: %w", err)
	}
	if len(rows) < 2 {
		return &models.ImportResult{}, nil
	}

	header := make(map[string]int)
	for i, raw := range rows[0] {
		header[strings.ToLower(strings.TrimSpace(raw))] = i
	}
	get := func(row []string, name string) string {
		idx, ok := header[name]
		if !ok || idx >= len(row) {
			return ""
		}
		return strings.TrimSpace(row[idx])
	}

	type groupedPromotion struct {
		Name        string
		Description *string
		StartDate   string
		EndDate     string
		Priority    int
		Rules       []models.PromotionProductRuleRequest
	}

	grouped := make(map[string]*groupedPromotion)
	result := &models.ImportResult{}

	resolveProduct := func(productIDRaw, skuRaw, barcodeRaw string) (int, *int, error) {
		if productIDRaw != "" {
			var productID int
			if _, err := fmt.Sscanf(productIDRaw, "%d", &productID); err == nil && productID > 0 {
				return productID, nil, nil
			}
		}
		if barcodeRaw != "" {
			var productID int
			var barcodeID int
			err := s.db.QueryRow(`
				SELECT pb.product_id, pb.barcode_id
				FROM product_barcodes pb
				JOIN products p ON p.product_id = pb.product_id
				WHERE p.company_id = $1 AND pb.barcode = $2
				LIMIT 1
			`, companyID, barcodeRaw).Scan(&productID, &barcodeID)
			if err == nil {
				return productID, &barcodeID, nil
			}
		}
		if skuRaw != "" {
			var productID int
			err := s.db.QueryRow(`
				SELECT product_id
				FROM products
				WHERE company_id = $1 AND sku = $2 AND is_deleted = FALSE
				LIMIT 1
			`, companyID, skuRaw).Scan(&productID)
			if err == nil {
				return productID, nil, nil
			}
		}
		return 0, nil, fmt.Errorf("product could not be resolved")
	}

	for rowIndex, row := range rows[1:] {
		if len(row) == 0 {
			continue
		}
		name := get(row, "campaign name")
		if name == "" {
			name = get(row, "name")
		}
		if name == "" {
			result.Errors = append(result.Errors, models.ImportRowError{Row: rowIndex + 2, Column: "campaign name", Message: "Campaign name is required"})
			result.Skipped++
			continue
		}
		startDate := get(row, "start date")
		endDate := get(row, "end date")
		if startDate == "" || endDate == "" {
			result.Errors = append(result.Errors, models.ImportRowError{Row: rowIndex + 2, Column: "start/end date", Message: "Start date and end date are required"})
			result.Skipped++
			continue
		}
		productID, barcodeID, err := resolveProduct(get(row, "product id"), get(row, "sku"), get(row, "barcode"))
		if err != nil {
			result.Errors = append(result.Errors, models.ImportRowError{Row: rowIndex + 2, Column: "product", Message: err.Error()})
			result.Skipped++
			continue
		}
		discountType := strings.ToUpper(strings.TrimSpace(get(row, "discount type")))
		switch discountType {
		case "PERCENTAGE", "FIXED", "FIXED_PRICE":
		default:
			result.Errors = append(result.Errors, models.ImportRowError{Row: rowIndex + 2, Column: "discount type", Message: "Discount type must be PERCENTAGE, FIXED, or FIXED_PRICE"})
			result.Skipped++
			continue
		}
		var value float64
		if _, err := fmt.Sscanf(get(row, "value"), "%f", &value); err != nil || value < 0 {
			result.Errors = append(result.Errors, models.ImportRowError{Row: rowIndex + 2, Column: "value", Message: "Value must be numeric"})
			result.Skipped++
			continue
		}
		minQty := 0.0
		if raw := get(row, "min qty"); raw != "" {
			if _, err := fmt.Sscanf(raw, "%f", &minQty); err != nil {
				result.Errors = append(result.Errors, models.ImportRowError{Row: rowIndex + 2, Column: "min qty", Message: "Min qty must be numeric"})
				result.Skipped++
				continue
			}
		}
		priority := 0
		if raw := get(row, "priority"); raw != "" {
			_, _ = fmt.Sscanf(raw, "%d", &priority)
		}
		descriptionText := get(row, "description")
		var description *string
		if descriptionText != "" {
			description = &descriptionText
		}
		key := strings.Join([]string{name, startDate, endDate, fmt.Sprintf("%d", priority), descriptionText}, "|")
		item := grouped[key]
		if item == nil {
			item = &groupedPromotion{
				Name:        name,
				Description: description,
				StartDate:   startDate,
				EndDate:     endDate,
				Priority:    priority,
			}
			grouped[key] = item
		}
		item.Rules = append(item.Rules, models.PromotionProductRuleRequest{
			ProductID:    productID,
			BarcodeID:    barcodeID,
			DiscountType: discountType,
			Value:        value,
			MinQty:       minQty,
		})
	}

	for _, campaign := range grouped {
		priority := campaign.Priority
		scope := "ITEM"
		applicableTo := "PRODUCTS"
		if _, err := s.CreatePromotion(companyID, &models.CreatePromotionRequest{
			Name:          campaign.Name,
			Description:   campaign.Description,
			DiscountScope: &scope,
			StartDate:     campaign.StartDate,
			EndDate:       campaign.EndDate,
			ApplicableTo:  &applicableTo,
			Priority:      &priority,
			ProductRules:  campaign.Rules,
		}); err != nil {
			result.Errors = append(result.Errors, models.ImportRowError{Row: 0, Column: campaign.Name, Message: err.Error()})
			result.Skipped += len(campaign.Rules)
			continue
		}
		result.Created++
		result.Count++
	}

	return result, nil
}

func (s *LoyaltyService) PromotionImportTemplateXLSX() ([]byte, error) {
	f := excelize.NewFile()
	sheet := "Promotions"
	f.SetSheetName("Sheet1", sheet)
	headers := []string{
		"Campaign Name",
		"Description",
		"Start Date",
		"End Date",
		"Priority",
		"Product ID",
		"SKU",
		"Barcode",
		"Discount Type",
		"Value",
		"Min Qty",
	}
	for i, header := range headers {
		cell, _ := excelize.CoordinatesToCellName(i+1, 1)
		f.SetCellValue(sheet, cell, header)
	}
	_ = f.SetPanes(sheet, &excelize.Panes{Freeze: true, Split: true, YSplit: 1, TopLeftCell: "A2", ActivePane: "bottomLeft"})
	_ = f.AutoFilter(sheet, "A1:K1", nil)
	buf, err := f.WriteToBuffer()
	if err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func (s *LoyaltyService) PromotionImportExampleXLSX() ([]byte, error) {
	data, err := s.PromotionImportTemplateXLSX()
	if err != nil {
		return nil, err
	}
	f, err := excelize.OpenReader(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	sheet := "Promotions"
	values := []interface{}{
		"Weekend Price Drop",
		"Imported product pricing campaign",
		time.Now().Format("2006-01-02"),
		time.Now().AddDate(0, 0, 30).Format("2006-01-02"),
		10,
		"",
		"SKU-001",
		"",
		"FIXED_PRICE",
		9.99,
		1,
	}
	for i, value := range values {
		cell, _ := excelize.CoordinatesToCellName(i+1, 2)
		f.SetCellValue(sheet, cell, value)
	}
	buf, err := f.WriteToBuffer()
	if err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}
