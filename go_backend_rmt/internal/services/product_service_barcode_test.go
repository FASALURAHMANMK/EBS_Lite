package services

import (
	"testing"

	"erp-backend/internal/models"
)

func TestCreateProduct_InvalidPrimaryBarcode(t *testing.T) {
	svc := &ProductService{}
	req := &models.CreateProductRequest{
		Name: "Test",
		Barcodes: []models.ProductBarcode{
			{Barcode: "111"},
			{Barcode: "222"},
		},
	}
	if _, err := svc.CreateProduct(1, 1, req); err == nil {
		t.Fatalf("expected error for missing primary barcode")
	}
	req.Barcodes[0].IsPrimary = true
	req.Barcodes[1].IsPrimary = true
	if _, err := svc.CreateProduct(1, 1, req); err == nil {
		t.Fatalf("expected error for multiple primary barcodes")
	}
}

func TestUpdateProduct_InvalidPrimaryBarcode(t *testing.T) {
	svc := &ProductService{}
	req := &models.UpdateProductRequest{
		Barcodes: []models.ProductBarcode{
			{Barcode: "111"},
			{Barcode: "222"},
		},
	}
	if _, err := svc.UpdateProduct(1, 1, 1, req); err == nil {
		t.Fatalf("expected error for missing primary barcode")
	}
	req.Barcodes[0].IsPrimary = true
	req.Barcodes[1].IsPrimary = true
	if _, err := svc.UpdateProduct(1, 1, 1, req); err == nil {
		t.Fatalf("expected error for multiple primary barcodes")
	}
}
