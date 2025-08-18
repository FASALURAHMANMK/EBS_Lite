package utils

import (
	"fmt"
	"time"
)

// PurchaseNumberGenerator generates purchase numbers in a standardized format
type PurchaseNumberGenerator struct{}

func NewPurchaseNumberGenerator() *PurchaseNumberGenerator {
	return &PurchaseNumberGenerator{}
}

// GeneratePurchaseNumber creates a purchase number: PUR-{LocationID}-{YYYYMMDD}-{Sequence}
func (g *PurchaseNumberGenerator) GeneratePurchaseNumber(locationID int, sequence int) string {
	return fmt.Sprintf("PUR-%d-%s-%04d", locationID, time.Now().Format("20060102"), sequence)
}

// GenerateReturnNumber creates a return number: PRET-{LocationID}-{YYYYMMDD}-{Sequence}
func (g *PurchaseNumberGenerator) GenerateReturnNumber(locationID int, sequence int) string {
	return fmt.Sprintf("PRET-%d-%s-%04d", locationID, time.Now().Format("20060102"), sequence)
}

// PurchaseValidators contains validation functions for purchase operations
type PurchaseValidators struct{}

func NewPurchaseValidators() *PurchaseValidators {
	return &PurchaseValidators{}
}

// ValidatePurchaseStatus checks if a purchase status transition is valid
func (v *PurchaseValidators) ValidatePurchaseStatus(currentStatus, newStatus string) error {
	validTransitions := map[string][]string{
		"PENDING":            {"RECEIVED", "PARTIALLY_RECEIVED", "CANCELLED"},
		"PARTIALLY_RECEIVED": {"RECEIVED", "CANCELLED"},
		"RECEIVED":           {}, // Terminal state
		"CANCELLED":          {}, // Terminal state
	}

	validNextStates, exists := validTransitions[currentStatus]
	if !exists {
		return fmt.Errorf("invalid current status: %s", currentStatus)
	}

	for _, validState := range validNextStates {
		if validState == newStatus {
			return nil
		}
	}

	return fmt.Errorf("invalid status transition from %s to %s", currentStatus, newStatus)
}

// ValidateReceiveQuantity checks if received quantity is valid
func (v *PurchaseValidators) ValidateReceiveQuantity(orderedQty, previouslyReceived, newlyReceived float64) error {
	if newlyReceived <= 0 {
		return fmt.Errorf("received quantity must be greater than 0")
	}

	totalReceived := previouslyReceived + newlyReceived
	if totalReceived > orderedQty {
		return fmt.Errorf("total received quantity (%.2f) cannot exceed ordered quantity (%.2f)",
			totalReceived, orderedQty)
	}

	return nil
}

// PurchaseCalculators contains calculation functions for purchase operations
type PurchaseCalculators struct{}

func NewPurchaseCalculators() *PurchaseCalculators {
	return &PurchaseCalculators{}
}

// CalculateLineTotal calculates line total with discount and tax
func (c *PurchaseCalculators) CalculateLineTotal(quantity, unitPrice, discountPercentage, discountAmount, taxPercentage float64) (lineTotal, calculatedDiscount, calculatedTax float64) {
	subtotal := quantity * unitPrice

	// Apply discount
	if discountPercentage > 0 {
		calculatedDiscount = subtotal * (discountPercentage / 100)
	} else {
		calculatedDiscount = discountAmount
	}

	afterDiscount := subtotal - calculatedDiscount

	// Apply tax
	calculatedTax = afterDiscount * (taxPercentage / 100)

	lineTotal = afterDiscount + calculatedTax

	return lineTotal, calculatedDiscount, calculatedTax
}

// CalculateDueDate calculates due date based on purchase date and payment terms
func (c *PurchaseCalculators) CalculateDueDate(purchaseDate time.Time, paymentTermsDays int) *time.Time {
	if paymentTermsDays <= 0 {
		return nil // No due date for zero or negative payment terms
	}

	dueDate := purchaseDate.AddDate(0, 0, paymentTermsDays)
	return &dueDate
}

// PurchaseFilters contains filtering utilities for purchase queries
type PurchaseFilters struct{}

func NewPurchaseFilters() *PurchaseFilters {
	return &PurchaseFilters{}
}

// BuildDateFilter creates SQL date filter conditions
func (f *PurchaseFilters) BuildDateFilter(dateFrom, dateTo string, fieldName string) (condition string, values []interface{}, err error) {
	var conditions []string
	var vals []interface{}
	argCount := 0

	if dateFrom != "" {
		argCount++
		conditions = append(conditions, fmt.Sprintf("%s >= $%d", fieldName, argCount))
		vals = append(vals, dateFrom)
	}

	if dateTo != "" {
		argCount++
		conditions = append(conditions, fmt.Sprintf("%s <= $%d", fieldName, argCount))
		vals = append(vals, dateTo)
	}

	if len(conditions) > 0 {
		condition = fmt.Sprintf("(%s)", joinConditions(conditions, "AND"))
	}

	return condition, vals, nil
}

// Helper function to join conditions
func joinConditions(conditions []string, operator string) string {
	if len(conditions) == 0 {
		return ""
	}
	if len(conditions) == 1 {
		return conditions[0]
	}

	result := conditions[0]
	for i := 1; i < len(conditions); i++ {
		result += fmt.Sprintf(" %s %s", operator, conditions[i])
	}
	return result
}

// PurchaseConstants contains constant values used in purchase operations
var PurchaseConstants = struct {
	StatusPending           string
	StatusReceived          string
	StatusPartiallyReceived string
	StatusCancelled         string

	DefaultPaymentTerms int
	MaxPaymentTerms     int

	DefaultCreditLimit float64
	MaxCreditLimit     float64
}{
	StatusPending:           "PENDING",
	StatusReceived:          "RECEIVED",
	StatusPartiallyReceived: "PARTIALLY_RECEIVED",
	StatusCancelled:         "CANCELLED",

	DefaultPaymentTerms: 30,
	MaxPaymentTerms:     365,

	DefaultCreditLimit: 0.0,
	MaxCreditLimit:     1000000.0,
}

// PurchaseHelpers contains miscellaneous helper functions
type PurchaseHelpers struct{}

func NewPurchaseHelpers() *PurchaseHelpers {
	return &PurchaseHelpers{}
}

// FormatPurchaseAmount formats purchase amounts for display
func (h *PurchaseHelpers) FormatPurchaseAmount(amount float64, currencySymbol string) string {
	if currencySymbol == "" {
		currencySymbol = "$"
	}
	return fmt.Sprintf("%s%.2f", currencySymbol, amount)
}

// IsValidSupplierEmail validates supplier email format
func (h *PurchaseHelpers) IsValidSupplierEmail(email string) bool {
	if email == "" {
		return true // Email is optional
	}
	// Basic email validation - you can use a more sophisticated regex if needed
	return len(email) > 5 && contains(email, "@") && contains(email, ".")
}

// Helper function to check if string contains substring
func contains(s, substr string) bool {
	return len(s) >= len(substr) &&
		(s == substr ||
			(len(s) > len(substr) &&
				(s[:len(substr)] == substr ||
					s[len(s)-len(substr):] == substr ||
					containsMiddle(s, substr))))
}

func containsMiddle(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

// GetOutstandingAmount calculates outstanding amount for a purchase
func (h *PurchaseHelpers) GetOutstandingAmount(totalAmount, paidAmount float64) float64 {
	outstanding := totalAmount - paidAmount
	if outstanding < 0 {
		return 0
	}
	return outstanding
}

// IsOverdue checks if a purchase is overdue based on due date
func (h *PurchaseHelpers) IsOverdue(dueDate *time.Time, paidAmount, totalAmount float64) bool {
	if dueDate == nil || paidAmount >= totalAmount {
		return false
	}
	return time.Now().After(*dueDate)
}
