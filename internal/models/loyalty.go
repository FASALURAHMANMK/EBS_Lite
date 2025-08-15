package models

import (
	"time"
)

// Loyalty Program Models
type LoyaltyProgram struct {
	LoyaltyID     int       `json:"loyalty_id" db:"loyalty_id"`
	CustomerID    int       `json:"customer_id" db:"customer_id"`
	Points        float64   `json:"points" db:"points"`
	TotalEarned   float64   `json:"total_earned" db:"total_earned"`
	TotalRedeemed float64   `json:"total_redeemed" db:"total_redeemed"`
	LastUpdated   time.Time `json:"last_updated" db:"last_updated"`
	Customer      *Customer `json:"customer,omitempty"`
}

type LoyaltyRedemption struct {
	RedemptionID  int       `json:"redemption_id" db:"redemption_id"`
	SaleID        *int      `json:"sale_id,omitempty" db:"sale_id"`
	CustomerID    int       `json:"customer_id" db:"customer_id"`
	PointsUsed    float64   `json:"points_used" db:"points_used"`
	ValueRedeemed float64   `json:"value_redeemed" db:"value_redeemed"`
	RedeemedAt    time.Time `json:"redeemed_at" db:"redeemed_at"`
	Customer      *Customer `json:"customer,omitempty"`
	Sale          *Sale     `json:"sale,omitempty"`
}

type LoyaltyTransaction struct {
	TransactionID   int       `json:"transaction_id"`
	CustomerID      int       `json:"customer_id"`
	Type            string    `json:"type"` // EARNED, REDEEMED, EXPIRED
	Points          float64   `json:"points"`
	Description     string    `json:"description"`
	ReferenceID     *int      `json:"reference_id,omitempty"` // Sale ID or Redemption ID
	TransactionDate time.Time `json:"transaction_date"`
}

// Promotion Models
type Promotion struct {
	PromotionID  int       `json:"promotion_id" db:"promotion_id"`
	CompanyID    int       `json:"company_id" db:"company_id"`
	Name         string    `json:"name" db:"name" validate:"required,min=2,max=255"`
	Description  *string   `json:"description,omitempty" db:"description"`
	DiscountType *string   `json:"discount_type,omitempty" db:"discount_type"`
	Value        *float64  `json:"value,omitempty" db:"value"`
	MinAmount    *float64  `json:"min_amount,omitempty" db:"min_amount"`
	StartDate    time.Time `json:"start_date" db:"start_date"`
	EndDate      time.Time `json:"end_date" db:"end_date"`
	ApplicableTo *string   `json:"applicable_to,omitempty" db:"applicable_to"`
	Conditions   *JSONB    `json:"conditions,omitempty" db:"conditions"`
	IsActive     bool      `json:"is_active" db:"is_active"`
	BaseModel
}

// Request/Response Models
type CreateLoyaltyRedemptionRequest struct {
	CustomerID int     `json:"customer_id" validate:"required"`
	PointsUsed float64 `json:"points_used" validate:"required,gt=0"`
	Reference  *string `json:"reference,omitempty"`
}

type LoyaltyRedemptionResponse struct {
	RedemptionID    int     `json:"redemption_id"`
	CustomerID      int     `json:"customer_id"`
	PointsUsed      float64 `json:"points_used"`
	ValueRedeemed   float64 `json:"value_redeemed"`
	RemainingPoints float64 `json:"remaining_points"`
	Message         string  `json:"message"`
}

type CreatePromotionRequest struct {
	Name         string   `json:"name" validate:"required,min=2,max=255"`
	Description  *string  `json:"description,omitempty"`
	DiscountType *string  `json:"discount_type,omitempty" validate:"omitempty,oneof=PERCENTAGE FIXED BUY_X_GET_Y"`
	Value        *float64 `json:"value,omitempty"`
	MinAmount    *float64 `json:"min_amount,omitempty"`
	StartDate    string   `json:"start_date" validate:"required"`
	EndDate      string   `json:"end_date" validate:"required"`
	ApplicableTo *string  `json:"applicable_to,omitempty" validate:"omitempty,oneof=ALL PRODUCTS CATEGORIES CUSTOMERS"`
	Conditions   *JSONB   `json:"conditions,omitempty"`
}

type UpdatePromotionRequest struct {
	Name         *string  `json:"name,omitempty" validate:"omitempty,min=2,max=255"`
	Description  *string  `json:"description,omitempty"`
	DiscountType *string  `json:"discount_type,omitempty" validate:"omitempty,oneof=PERCENTAGE FIXED BUY_X_GET_Y"`
	Value        *float64 `json:"value,omitempty"`
	MinAmount    *float64 `json:"min_amount,omitempty"`
	StartDate    *string  `json:"start_date,omitempty"`
	EndDate      *string  `json:"end_date,omitempty"`
	ApplicableTo *string  `json:"applicable_to,omitempty" validate:"omitempty,oneof=ALL PRODUCTS CATEGORIES CUSTOMERS"`
	Conditions   *JSONB   `json:"conditions,omitempty"`
	IsActive     *bool    `json:"is_active,omitempty"`
}

type CustomerLoyaltyResponse struct {
	CustomerID     int                  `json:"customer_id"`
	CustomerName   string               `json:"customer_name"`
	CurrentPoints  float64              `json:"current_points"`
	TotalEarned    float64              `json:"total_earned"`
	TotalRedeemed  float64              `json:"total_redeemed"`
	RecentActivity []LoyaltyTransaction `json:"recent_activity"`
}

// PromotionEligibilityRequest defines the payload for checking promotion eligibility.
// Expected JSON format:
//
//	{
//	  "customer_id": 123,       // optional
//	  "total_amount": 100.0,    // required
//	  "product_ids": [1,2],     // optional - products in the transaction
//	  "category_ids": [10,20]   // optional - categories represented in the transaction
//	}
type PromotionEligibilityRequest struct {
	CustomerID  *int    `json:"customer_id,omitempty"`
	TotalAmount float64 `json:"total_amount" validate:"required,gt=0"`
	ProductIDs  []int   `json:"product_ids,omitempty"`
	CategoryIDs []int   `json:"category_ids,omitempty"`
}

type PromotionEligibilityResponse struct {
	EligiblePromotions []struct {
		PromotionID    int     `json:"promotion_id"`
		Name           string  `json:"name"`
		DiscountType   string  `json:"discount_type"`
		Value          float64 `json:"value"`
		DiscountAmount float64 `json:"discount_amount"`
	} `json:"eligible_promotions"`
	TotalDiscount float64 `json:"total_discount"`
}

type LoyaltySettingsResponse struct {
	PointsPerCurrency   float64 `json:"points_per_currency"`
	PointValue          float64 `json:"point_value"`
	MinRedemptionPoints float64 `json:"min_redemption_points"`
	PointsExpiryDays    int     `json:"points_expiry_days"`
}
