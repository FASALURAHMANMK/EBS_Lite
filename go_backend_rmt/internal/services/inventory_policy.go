package services

import (
	"database/sql"
	"fmt"
	"strings"

	"erp-backend/internal/models"
)

type settingsQueryRower interface {
	QueryRow(query string, args ...interface{}) *sql.Row
}

func loadCompanyInventoryPolicy(querier settingsQueryRower, companyID int) (*companyInventoryPolicy, error) {
	var raw models.JSONB
	err := querier.QueryRow(`SELECT value FROM settings WHERE company_id = $1 AND key = 'inventory'`, companyID).Scan(&raw)
	if err != nil && err != sql.ErrNoRows {
		return nil, fmt.Errorf("failed to get inventory settings: %w", err)
	}

	policy := &companyInventoryPolicy{
		CostingMethod:        costingMethodFIFO,
		NegativeStockPolicy:  negativeStockPolicyDisallow,
		NegativeProfitPolicy: negativeStockPolicyDisallow,
	}
	if err == nil {
		if value, ok := raw["inventory_costing_method"].(string); ok {
			policy.CostingMethod = normalizeCostingMethod(value)
		}
		if value, ok := raw["negative_stock_policy"].(string); ok {
			policy.NegativeStockPolicy = normalizeNegativeStockPolicy(value)
		}
		if value, ok := raw["negative_profit_policy"].(string); ok {
			policy.NegativeProfitPolicy = normalizeNegativeStockPolicy(value)
		}
		if value, ok := raw["negative_stock_approval_password_hash"].(string); ok {
			policy.NegativeStockApprovalPasswordHash = strings.TrimSpace(value)
		}
		if value, ok := raw["approval_password_hash"].(string); ok {
			policy.ApprovalPasswordHash = strings.TrimSpace(value)
		}
	}
	if policy.ApprovalPasswordHash == "" {
		policy.ApprovalPasswordHash = policy.NegativeStockApprovalPasswordHash
	}

	var legacy models.JSONB
	if err := querier.QueryRow(`SELECT value FROM settings WHERE company_id = $1 AND key = 'company'`, companyID).Scan(&legacy); err != nil && err != sql.ErrNoRows {
		return nil, fmt.Errorf("failed to get company settings: %w", err)
	} else if err == nil && policy.CostingMethod == costingMethodFIFO {
		if value, ok := legacy["inventory_costing_method"].(string); ok {
			policy.CostingMethod = normalizeCostingMethod(value)
		} else if value, ok := legacy["value"].(string); ok {
			policy.CostingMethod = normalizeCostingMethod(value)
		}
	}

	return policy, nil
}

func loadCompanyCostingMethod(querier settingsQueryRower, companyID int) (string, error) {
	policy, err := loadCompanyInventoryPolicy(querier, companyID)
	if err != nil {
		return "", err
	}
	return policy.CostingMethod, nil
}
