package services

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"

	"erp-backend/internal/models"
)

const (
	taxPriceModeExclusive = "EXCLUSIVE"
	taxPriceModeInclusive = "INCLUSIVE"
)

type sqlQueryRower interface {
	QueryRow(query string, args ...any) *sql.Row
}

type computedTaxLine struct {
	NetAmount      float64
	TaxAmount      float64
	GrossAmount    float64
	DiscountAmount float64
}

func normalizeTaxPriceMode(value string) string {
	switch strings.ToUpper(strings.TrimSpace(value)) {
	case taxPriceModeInclusive:
		return taxPriceModeInclusive
	default:
		return taxPriceModeExclusive
	}
}

func loadCompanyTaxSettings(q sqlQueryRower, companyID int) (models.TaxSettings, error) {
	cfg := models.TaxSettings{PriceMode: taxPriceModeExclusive}
	if q == nil || companyID <= 0 {
		return cfg, nil
	}
	switch v := q.(type) {
	case *sql.DB:
		if v == nil {
			return cfg, nil
		}
	case *sql.Tx:
		if v == nil {
			return cfg, nil
		}
	}

	var value models.JSONB
	err := q.QueryRow(`
		SELECT value
		FROM settings
		WHERE company_id = $1 AND key = 'tax'
	`, companyID).Scan(&value)
	if err == sql.ErrNoRows {
		return cfg, nil
	}
	if err != nil {
		return cfg, fmt.Errorf("failed to get tax settings: %w", err)
	}

	raw, err := json.Marshal(value)
	if err != nil {
		return cfg, fmt.Errorf("failed to marshal tax settings: %w", err)
	}
	if err := json.Unmarshal(raw, &cfg); err != nil {
		return cfg, fmt.Errorf("failed to unmarshal tax settings: %w", err)
	}
	cfg.PriceMode = normalizeTaxPriceMode(cfg.PriceMode)
	return cfg, nil
}

func computeTaxLine(quantity, unitPrice, discountPercent, taxPercent float64, priceMode string) computedTaxLine {
	return computeTaxLineWithDiscount(quantity, unitPrice, discountPercent, 0, false, taxPercent, priceMode)
}

func computeTaxLineWithDiscount(quantity, unitPrice, discountPercent, explicitDiscount float64, hasExplicitDiscount bool, taxPercent float64, priceMode string) computedTaxLine {
	lineGrossBeforeDiscount := quantity * unitPrice
	discountAmount := lineGrossBeforeDiscount * (discountPercent / 100)
	if hasExplicitDiscount {
		discountAmount = explicitDiscount
	}
	lineGrossAfterDiscount := lineGrossBeforeDiscount - discountAmount
	taxRate := taxPercent / 100

	if taxRate <= 0 {
		return computedTaxLine{
			NetAmount:      lineGrossAfterDiscount,
			TaxAmount:      0,
			GrossAmount:    lineGrossAfterDiscount,
			DiscountAmount: discountAmount,
		}
	}

	if normalizeTaxPriceMode(priceMode) == taxPriceModeInclusive {
		netAmount := lineGrossAfterDiscount / (1 + taxRate)
		return computedTaxLine{
			NetAmount:      netAmount,
			TaxAmount:      lineGrossAfterDiscount - netAmount,
			GrossAmount:    lineGrossAfterDiscount,
			DiscountAmount: discountAmount,
		}
	}

	taxAmount := lineGrossAfterDiscount * taxRate
	return computedTaxLine{
		NetAmount:      lineGrossAfterDiscount,
		TaxAmount:      taxAmount,
		GrossAmount:    lineGrossAfterDiscount + taxAmount,
		DiscountAmount: discountAmount,
	}
}
