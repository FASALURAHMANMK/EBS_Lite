package services

import (
	"testing"
	"time"

	"erp-backend/internal/models"
)

func TestCheckPromotionEligibility_ProductSpecificPromotion(t *testing.T) {
	start := time.Now().Add(-time.Hour)
	end := time.Now().Add(time.Hour)
	cond := models.JSONB{"product_ids": []interface{}{1, 2}}
	promo := models.Promotion{
		PromotionID:  1,
		CompanyID:    1,
		Name:         "Promo",
		DiscountType: func() *string { s := "PERCENTAGE"; return &s }(),
		Value:        func() *float64 { v := 10.0; return &v }(),
		StartDate:    start,
		EndDate:      end,
		ApplicableTo: func() *string { s := "PRODUCTS"; return &s }(),
		Conditions:   &cond,
		IsActive:     true,
	}

	s := &LoyaltyService{}
	orig := getPromotions
	defer func() { getPromotions = orig }()
	getPromotions = func(_ *LoyaltyService, companyID int, activeOnly bool) ([]models.Promotion, error) {
		return []models.Promotion{promo}, nil
	}

	req := &models.PromotionEligibilityRequest{TotalAmount: 100, ProductIDs: []int{1}}

	resp, err := s.CheckPromotionEligibility(1, req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.EligiblePromotions) != 1 {
		t.Fatalf("expected 1 promotion, got %d", len(resp.EligiblePromotions))
	}
	if resp.TotalDiscount != 10 {
		t.Fatalf("expected discount 10, got %f", resp.TotalDiscount)
	}
}

func TestCheckPromotionEligibility_ProductSpecificPromotion_NotEligible(t *testing.T) {
	start := time.Now().Add(-time.Hour)
	end := time.Now().Add(time.Hour)
	cond := models.JSONB{"product_ids": []interface{}{1, 2}}
	promo := models.Promotion{
		PromotionID:  1,
		CompanyID:    1,
		Name:         "Promo",
		DiscountType: func() *string { s := "PERCENTAGE"; return &s }(),
		Value:        func() *float64 { v := 10.0; return &v }(),
		StartDate:    start,
		EndDate:      end,
		ApplicableTo: func() *string { s := "PRODUCTS"; return &s }(),
		Conditions:   &cond,
		IsActive:     true,
	}

	s := &LoyaltyService{}
	orig := getPromotions
	defer func() { getPromotions = orig }()
	getPromotions = func(_ *LoyaltyService, companyID int, activeOnly bool) ([]models.Promotion, error) {
		return []models.Promotion{promo}, nil
	}

	req := &models.PromotionEligibilityRequest{TotalAmount: 100, ProductIDs: []int{3}}

	resp, err := s.CheckPromotionEligibility(1, req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.EligiblePromotions) != 0 {
		t.Fatalf("expected 0 promotions, got %d", len(resp.EligiblePromotions))
	}
	if resp.TotalDiscount != 0 {
		t.Fatalf("expected discount 0, got %f", resp.TotalDiscount)
	}
}
