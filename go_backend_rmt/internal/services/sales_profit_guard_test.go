package services

import "testing"

func TestActualSaleLineCostUsesSaleUnits(t *testing.T) {
	line := preparedSaleDetail{
		Quantity: 2,
	}
	issue := &issueResult{
		BarcodeID: 10,
		UnitCost:  5,
		TotalCost: 20,
	}

	actual := actualSaleLineCost(line, issue)
	if actual.CostPricePerUnit != 10 {
		t.Fatalf("expected sale-unit cost 10, got %v", actual.CostPricePerUnit)
	}
	if actual.TotalCost != 20 {
		t.Fatalf("expected total cost 20, got %v", actual.TotalCost)
	}
	if actual.BarcodeID == nil || *actual.BarcodeID != 10 {
		t.Fatalf("expected barcode_id 10, got %#v", actual.BarcodeID)
	}
}

func TestBuildProfitGuardDetailsAllocatesBillDiscount(t *testing.T) {
	lines := []preparedSaleDetail{
		{
			ProductID: intPtr(1),
			ProductName: func() *string {
				v := "Item A"
				return &v
			}(),
			Quantity:  1,
			UnitPrice: 100,
			LineTotal: 100,
		},
		{
			ProductID: intPtr(2),
			ProductName: func() *string {
				v := "Item B"
				return &v
			}(),
			Quantity:  1,
			UnitPrice: 50,
			LineTotal: 50,
		},
	}
	actualCosts := []issuedSaleLineCost{
		{CostPricePerUnit: 90, TotalCost: 90},
		{CostPricePerUnit: 20, TotalCost: 20},
	}

	details := buildProfitGuardDetails(lines, actualCosts, 30)
	if details == nil {
		t.Fatal("expected details")
	}
	if details.TotalRevenue != 120 {
		t.Fatalf("expected total revenue 120, got %v", details.TotalRevenue)
	}
	if details.TotalCost != 110 {
		t.Fatalf("expected total cost 110, got %v", details.TotalCost)
	}
	if details.Profit != 10 {
		t.Fatalf("expected profit 10, got %v", details.Profit)
	}
	if len(details.Lines) != 2 {
		t.Fatalf("expected 2 lines, got %d", len(details.Lines))
	}
	if details.Lines[0].HeaderDiscountShare != 20 {
		t.Fatalf("expected first line discount share 20, got %v", details.Lines[0].HeaderDiscountShare)
	}
	if details.Lines[1].HeaderDiscountShare != 10 {
		t.Fatalf("expected second line discount share 10, got %v", details.Lines[1].HeaderDiscountShare)
	}
}
