package services

import (
	"database/sql/driver"
	"strings"
	"testing"

	"erp-backend/internal/models"
)

func TestGetUnits_DeduplicatesSemanticallyEquivalentRows(t *testing.T) {
	db := mockDB(map[string]stubResp{
		"FROM units": {
			columns: []string{"unit_id", "name", "symbol", "base_unit_id", "conversion_factor"},
			rows: [][]driver.Value{
				{1, " Pieces ", "pcs", nil, nil},
				{2, "pieces", " pcs ", nil, 1.0},
				{3, "Kilograms", "kg", nil, 1.0},
			},
		},
	})

	svc := &ProductService{db: db}
	units, err := svc.GetUnits()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(units) != 2 {
		t.Fatalf("expected 2 units after dedupe, got %d", len(units))
	}
	if units[0].UnitID != 1 {
		t.Fatalf("expected canonical duplicate to keep earliest ID, got %d", units[0].UnitID)
	}
	if units[0].Name != "Pieces" {
		t.Fatalf("expected trimmed unit name, got %q", units[0].Name)
	}
	if units[0].ConversionFactor == nil || *units[0].ConversionFactor != 1.0 {
		t.Fatalf("expected default conversion factor 1.0, got %#v", units[0].ConversionFactor)
	}
}

func TestCreateUnit_RejectsDuplicateDefinition(t *testing.T) {
	db := mockDB(map[string]stubResp{
		"FROM units": {
			columns: []string{"unit_id", "name", "symbol", "base_unit_id", "conversion_factor"},
			rows: [][]driver.Value{
				{4, "Pieces", "pcs", nil, 1.0},
			},
		},
	})

	svc := &ProductService{db: db}
	_, err := svc.CreateUnit(&models.CreateUnitRequest{
		Name:   " pieces ",
		Symbol: stringPtr(" pcs "),
	})
	if err == nil || !strings.Contains(err.Error(), "unit already exists") {
		t.Fatalf("expected duplicate unit error, got %v", err)
	}
}

func stringPtr(value string) *string {
	return &value
}
