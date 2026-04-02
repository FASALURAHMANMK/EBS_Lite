package services

import (
	"database/sql"
	"fmt"
	"strings"
)

type issuedSaleLineCost struct {
	BarcodeID        *int
	CostPricePerUnit float64
	TotalCost        float64
}

type ProfitGuardLine struct {
	ProductID           *int    `json:"product_id,omitempty"`
	ComboProductID      *int    `json:"combo_product_id,omitempty"`
	BarcodeID           *int    `json:"barcode_id,omitempty"`
	ProductName         string  `json:"product_name"`
	Quantity            float64 `json:"quantity"`
	UnitPrice           float64 `json:"unit_price"`
	Revenue             float64 `json:"revenue"`
	Cost                float64 `json:"cost"`
	Profit              float64 `json:"profit"`
	CostPricePerUnit    float64 `json:"cost_price_per_unit"`
	HeaderDiscountShare float64 `json:"header_discount_share"`
}

type ProfitGuardDetails struct {
	TotalRevenue float64           `json:"total_revenue"`
	TotalCost    float64           `json:"total_cost"`
	Profit       float64           `json:"profit"`
	LossAmount   float64           `json:"loss_amount"`
	Lines        []ProfitGuardLine `json:"lines,omitempty"`
}

type NegativeProfitApprovalRequiredError struct {
	Message string
	Details *ProfitGuardDetails
}

func (e *NegativeProfitApprovalRequiredError) Error() string {
	if e == nil || strings.TrimSpace(e.Message) == "" {
		return "negative profit approval password required"
	}
	return e.Message
}

type NegativeProfitNotAllowedError struct {
	Message string
	Details *ProfitGuardDetails
}

func (e *NegativeProfitNotAllowedError) Error() string {
	if e == nil || strings.TrimSpace(e.Message) == "" {
		return "sale would result in negative profit"
	}
	return e.Message
}

func actualSaleLineCost(line preparedSaleDetail, issue *issueResult) issuedSaleLineCost {
	result := issuedSaleLineCost{
		BarcodeID: line.BarcodeID,
	}
	if issue == nil {
		return result
	}
	result.TotalCost = issue.TotalCost
	if line.Quantity > 0 {
		result.CostPricePerUnit = issue.TotalCost / line.Quantity
	}
	if issue.BarcodeID > 0 {
		result.BarcodeID = intPtr(issue.BarcodeID)
	}
	return result
}

func allocateHeaderDiscountByLine(lines []preparedSaleDetail, totalDiscount float64) []float64 {
	allocations := make([]float64, len(lines))
	if totalDiscount <= 0 || len(lines) == 0 {
		return allocations
	}

	totalBase := 0.0
	eligible := make([]int, 0, len(lines))
	for index, line := range lines {
		if line.LineTotal <= 0 {
			continue
		}
		totalBase += line.LineTotal
		eligible = append(eligible, index)
	}
	if totalBase <= 0 || len(eligible) == 0 {
		return allocations
	}

	remaining := totalDiscount
	for idx, lineIndex := range eligible {
		share := totalDiscount * (lines[lineIndex].LineTotal / totalBase)
		if idx == len(eligible)-1 {
			share = remaining
		}
		allocations[lineIndex] = share
		remaining -= share
	}
	return allocations
}

func buildProfitGuardDetails(lines []preparedSaleDetail, actualCosts []issuedSaleLineCost, totalDiscount float64) *ProfitGuardDetails {
	if len(lines) == 0 {
		return nil
	}

	headerDiscounts := allocateHeaderDiscountByLine(lines, totalDiscount)
	details := &ProfitGuardDetails{
		Lines: make([]ProfitGuardLine, 0, len(lines)),
	}

	for index, line := range lines {
		if line.Quantity <= 0 || line.LineTotal <= 0 {
			continue
		}
		actual := issuedSaleLineCost{}
		if index < len(actualCosts) {
			actual = actualCosts[index]
		}

		revenue := line.LineTotal - headerDiscounts[index]
		cost := actual.TotalCost
		profit := revenue - cost
		productName := strings.TrimSpace(ptrString(line.ProductName))
		if productName == "" {
			if line.ProductID == nil {
				productName = "Quick sale item"
			} else {
				productName = "Product"
			}
		}

		details.TotalRevenue += revenue
		details.TotalCost += cost
		details.Lines = append(details.Lines, ProfitGuardLine{
			ProductID:           line.ProductID,
			ComboProductID:      line.ComboProductID,
			BarcodeID:           actual.BarcodeID,
			ProductName:         productName,
			Quantity:            line.Quantity,
			UnitPrice:           line.UnitPrice,
			Revenue:             revenue,
			Cost:                cost,
			Profit:              profit,
			CostPricePerUnit:    actual.CostPricePerUnit,
			HeaderDiscountShare: headerDiscounts[index],
		})
	}

	details.Profit = details.TotalRevenue - details.TotalCost
	if details.Profit < 0 {
		details.LossAmount = -details.Profit
	}
	return details
}

func (s *SalesService) enforceNegativeProfitPolicyTx(tx *sql.Tx, companyID int, overridePassword *string, details *ProfitGuardDetails) error {
	if details == nil || details.Profit >= -0.000001 {
		return nil
	}

	trackingSvc := newInventoryTrackingService(s.db)
	policy, err := trackingSvc.getCompanyInventoryPolicyTx(tx, companyID)
	if err != nil {
		return err
	}

	message := fmt.Sprintf(
		"Sale would result in a loss of %.2f (revenue %.2f, cost %.2f).",
		round2(details.LossAmount),
		round2(details.TotalRevenue),
		round2(details.TotalCost),
	)

	switch policy.NegativeProfitPolicy {
	case negativeStockPolicyAllow:
		return nil
	case negativeStockPolicyApproval:
		approved, err := verifyApprovalPassword(policy.ApprovalPasswordHash, overridePassword)
		if err != nil {
			return err
		}
		if !approved {
			return &NegativeProfitApprovalRequiredError{
				Message: message + " Enter the approval password to continue.",
				Details: details,
			}
		}
		return nil
	default:
		return &NegativeProfitNotAllowedError{
			Message: message + " Selling in loss is blocked by settings.",
			Details: details,
		}
	}
}
