package models

import (
	"time"
)

// Credit Note Models
type CreditNote struct {
	CreditNoteID     int         `json:"credit_note_id" db:"credit_note_id"`
	CreditNoteNumber string      `json:"credit_note_number" db:"credit_note_number"`
	ReturnID         int         `json:"return_id" db:"return_id"`
	CustomerID       int         `json:"customer_id" db:"customer_id"`
	LocationID       int         `json:"location_id" db:"location_id"`
	Amount           float64     `json:"amount" db:"amount"`
	Status           string      `json:"status" db:"status"`
	IssueDate        time.Time   `json:"issue_date" db:"issue_date"`
	ExpiryDate       *time.Time  `json:"expiry_date,omitempty" db:"expiry_date"`
	Notes            *string     `json:"notes,omitempty" db:"notes"`
	CreatedBy        int         `json:"created_by" db:"created_by"`
	AppliedToSaleID  *int        `json:"applied_to_sale_id,omitempty" db:"applied_to_sale_id"`
	Customer         *Customer   `json:"customer,omitempty"`
	SaleReturn       *SaleReturn `json:"sale_return,omitempty"`
	SyncModel
}

type CreateCreditNoteRequest struct {
	ReturnID   int     `json:"return_id" validate:"required"`
	Amount     float64 `json:"amount" validate:"required,gt=0"`
	ExpiryDays *int    `json:"expiry_days,omitempty"`
	Notes      *string `json:"notes,omitempty"`
}

// Customer Segment Models
type CustomerSegment struct {
	SegmentID   int     `json:"segment_id" db:"segment_id"`
	CompanyID   int     `json:"company_id" db:"company_id"`
	Name        string  `json:"name" db:"name" validate:"required,min=2,max=100"`
	Description *string `json:"description,omitempty" db:"description"`
	Criteria    *JSONB  `json:"criteria,omitempty" db:"criteria"`
	IsActive    bool    `json:"is_active" db:"is_active"`
	BaseModel
}

type CreateCustomerSegmentRequest struct {
	Name        string  `json:"name" validate:"required,min=2,max=100"`
	Description *string `json:"description,omitempty"`
	Criteria    *JSONB  `json:"criteria,omitempty"`
}

type CustomerSegmentMember struct {
	SegmentID  int       `json:"segment_id" db:"segment_id"`
	CustomerID int       `json:"customer_id" db:"customer_id"`
	AssignedAt time.Time `json:"assigned_at" db:"assigned_at"`
}

// Return Reason Models
type ReturnReason struct {
	ReasonID         int     `json:"reason_id" db:"reason_id"`
	CompanyID        int     `json:"company_id" db:"company_id"`
	Name             string  `json:"name" db:"name" validate:"required,min=2,max=100"`
	Description      *string `json:"description,omitempty" db:"description"`
	RequiresApproval bool    `json:"requires_approval" db:"requires_approval"`
	IsActive         bool    `json:"is_active" db:"is_active"`
	BaseModel
}

type CreateReturnReasonRequest struct {
	Name             string  `json:"name" validate:"required,min=2,max=100"`
	Description      *string `json:"description,omitempty"`
	RequiresApproval bool    `json:"requires_approval"`
}

// Enhanced Loyalty Models
type LoyaltySettings struct {
	SettingID           int     `json:"setting_id" db:"setting_id"`
	CompanyID           int     `json:"company_id" db:"company_id"`
	PointsPerCurrency   float64 `json:"points_per_currency" db:"points_per_currency"`
	PointValue          float64 `json:"point_value" db:"point_value"`
	MinRedemptionPoints int     `json:"min_redemption_points" db:"min_redemption_points"`
	PointsExpiryDays    int     `json:"points_expiry_days" db:"points_expiry_days"`
	IsActive            bool    `json:"is_active" db:"is_active"`
	BaseModel
}

type UpdateLoyaltySettingsRequest struct {
	PointsPerCurrency   *float64 `json:"points_per_currency,omitempty" validate:"omitempty,gt=0"`
	PointValue          *float64 `json:"point_value,omitempty" validate:"omitempty,gt=0"`
	MinRedemptionPoints *int     `json:"min_redemption_points,omitempty" validate:"omitempty,gt=0"`
	PointsExpiryDays    *int     `json:"points_expiry_days,omitempty" validate:"omitempty,gt=0"`
}

// Promotion Usage Tracking
type PromotionUsage struct {
	UsageID        int       `json:"usage_id" db:"usage_id"`
	PromotionID    int       `json:"promotion_id" db:"promotion_id"`
	CustomerID     *int      `json:"customer_id,omitempty" db:"customer_id"`
	SaleID         *int      `json:"sale_id,omitempty" db:"sale_id"`
	DiscountAmount float64   `json:"discount_amount" db:"discount_amount"`
	UsedAt         time.Time `json:"used_at" db:"used_at"`
}

// Advanced Analytics Models
type CustomerLoyaltyAnalytics struct {
	CustomerID         int        `json:"customer_id"`
	CustomerName       string     `json:"customer_name"`
	Tier               string     `json:"tier"`
	CurrentPoints      float64    `json:"current_points"`
	TotalEarned        float64    `json:"total_earned"`
	TotalRedeemed      float64    `json:"total_redeemed"`
	SalesLast12Months  int        `json:"sales_last_12_months"`
	SpentLast12Months  float64    `json:"spent_last_12_months"`
	LastActivity       *time.Time `json:"last_activity,omitempty"`
	PointsExpiringIn30 float64    `json:"points_expiring_in_30_days"`
}

type PromotionAnalytics struct {
	PromotionID     int     `json:"promotion_id"`
	PromotionName   string  `json:"promotion_name"`
	TotalUses       int     `json:"total_uses"`
	TotalDiscount   float64 `json:"total_discount"`
	UniqueCustomers int     `json:"unique_customers"`
	AvgOrderValue   float64 `json:"avg_order_value"`
	ConversionRate  float64 `json:"conversion_rate"`
}

type ReturnsAnalytics struct {
	Period           string  `json:"period"`
	TotalReturns     int     `json:"total_returns"`
	TotalAmount      float64 `json:"total_amount"`
	ReturnRate       float64 `json:"return_rate"` // Returns as % of sales
	AvgReturnValue   float64 `json:"avg_return_value"`
	TopReturnReasons []struct {
		Reason     string  `json:"reason"`
		Count      int     `json:"count"`
		Percentage float64 `json:"percentage"`
	} `json:"top_return_reasons"`
	TopReturnedProducts []struct {
		ProductID   int     `json:"product_id"`
		ProductName string  `json:"product_name"`
		Quantity    float64 `json:"quantity"`
		Amount      float64 `json:"amount"`
	} `json:"top_returned_products"`
}

// Bulk Operations Models
type BulkLoyaltyAwardRequest struct {
	CustomerIDs []int   `json:"customer_ids" validate:"required,min=1"`
	Points      float64 `json:"points" validate:"required,gt=0"`
	Reason      string  `json:"reason" validate:"required,min=2"`
}

type BulkPromotionApplicationRequest struct {
	PromotionID int   `json:"promotion_id" validate:"required"`
	SaleIDs     []int `json:"sale_ids" validate:"required,min=1"`
}

// Integration Models
type SaleWithLoyaltyInfo struct {
	Sale
	PointsEarned      float64 `json:"points_earned"`
	PromotionsApplied []struct {
		PromotionID    int     `json:"promotion_id"`
		PromotionName  string  `json:"promotion_name"`
		DiscountAmount float64 `json:"discount_amount"`
	} `json:"promotions_applied"`
}

type CustomerPurchaseHistory struct {
	CustomerID       int        `json:"customer_id"`
	CustomerName     string     `json:"customer_name"`
	TotalSales       int        `json:"total_sales"`
	TotalSpent       float64    `json:"total_spent"`
	AvgOrderValue    float64    `json:"avg_order_value"`
	LastPurchase     *time.Time `json:"last_purchase,omitempty"`
	FavoriteProducts []struct {
		ProductID   int     `json:"product_id"`
		ProductName string  `json:"product_name"`
		Quantity    float64 `json:"quantity"`
		TotalSpent  float64 `json:"total_spent"`
	} `json:"favorite_products"`
	LoyaltyInfo CustomerLoyaltyResponse `json:"loyalty_info"`
}

// Dashboard Summary Models
type LoyaltyDashboardSummary struct {
	TotalCustomers       int                  `json:"total_customers"`
	ActiveMembers        int                  `json:"active_members"`
	TotalPointsIssued    float64              `json:"total_points_issued"`
	TotalPointsRedeemed  float64              `json:"total_points_redeemed"`
	PointsOutstanding    float64              `json:"points_outstanding"`
	RedemptionRate       float64              `json:"redemption_rate"`
	AvgPointsPerCustomer float64              `json:"avg_points_per_customer"`
	TopTierCustomers     int                  `json:"top_tier_customers"`
	RecentActivity       []LoyaltyTransaction `json:"recent_activity"`
}

type PromotionsDashboardSummary struct {
	ActivePromotions       int     `json:"active_promotions"`
	TotalDiscountGiven     float64 `json:"total_discount_given"`
	PromotionsUsedToday    int     `json:"promotions_used_today"`
	TopPerformingPromotion struct {
		PromotionID   int     `json:"promotion_id"`
		Name          string  `json:"name"`
		UsageCount    int     `json:"usage_count"`
		TotalDiscount float64 `json:"total_discount"`
	} `json:"top_performing_promotion"`
	UpcomingExpirations []Promotion `json:"upcoming_expirations"`
}

type ReturnsDashboardSummary struct {
	TotalReturns           int     `json:"total_returns"`
	TotalReturnValue       float64 `json:"total_return_value"`
	ReturnsToday           int     `json:"returns_today"`
	ReturnRate             float64 `json:"return_rate"`
	PendingApprovals       int     `json:"pending_approvals"`
	OutstandingCreditNotes float64 `json:"outstanding_credit_notes"`
	TopReturnReason        string  `json:"top_return_reason"`
}
