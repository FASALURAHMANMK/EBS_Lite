package services

import (
	"testing"

	"erp-backend/internal/models"
)

// TestCreateSale_PaidAmountExceedsTotal verifies that CreateSale returns an error
// when the paid amount is greater than the total amount.
func TestCreateSale_PaidAmountExceedsTotal(t *testing.T) {
	svc := &SalesService{}

	req := &models.CreateSaleRequest{
		Items: []models.CreateSaleDetailRequest{
			{Quantity: 1, UnitPrice: 10},
		},
		PaidAmount: 20, // Greater than calculated total of 10
	}

	_, err := svc.CreateSale(1, 1, 1, req, nil)
	if err == nil {
		t.Fatal("expected error but got nil")
	}

	if err.Error() != "paid amount cannot exceed total amount" {
		t.Fatalf("unexpected error: %v", err)
	}
}
