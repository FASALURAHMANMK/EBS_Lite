package services

import (
	"database/sql"
	"fmt"
	"strings"

	"github.com/lib/pq"
)

const (
	productUOMModeLoose = "LOOSE"
	productUOMModePack  = "PACK"
)

func normalizeProductUOMMode(mode *string) (string, error) {
	if mode == nil {
		return productUOMModeLoose, nil
	}
	normalized := strings.ToUpper(strings.TrimSpace(*mode))
	if normalized == "" {
		return productUOMModeLoose, nil
	}
	switch normalized {
	case productUOMModeLoose, productUOMModePack:
		return normalized, nil
	default:
		return "", fmt.Errorf("invalid UOM mode %q", normalized)
	}
}

func normalizeProductUOMFactor(factor *float64) float64 {
	if factor == nil || *factor <= 0 {
		return 1.0
	}
	return *factor
}

func quantityInStockUOM(quantity, factor float64) float64 {
	return quantity * normalizeProductUOMFactor(&factor)
}

func stockUnitCost(unitPrice, factor float64) float64 {
	return unitPrice / normalizeProductUOMFactor(&factor)
}

func saleUnitCost(meta productMeta) float64 {
	return meta.CostPrice * normalizeProductUOMFactor(&meta.SellingToStock)
}

type saleLineSnapshot struct {
	StockUnitID      *int
	SellingUnitID    *int
	SellingUOMMode   string
	SellingToStock   float64
	StockQuantity    float64
	CostPricePerUnit float64
}

func newSaleLineSnapshot(meta productMeta, quantity float64) saleLineSnapshot {
	return saleLineSnapshot{
		StockUnitID:      meta.StockUnitID,
		SellingUnitID:    meta.SellingUnitID,
		SellingUOMMode:   meta.SellingUOMMode,
		SellingToStock:   normalizeProductUOMFactor(&meta.SellingToStock),
		StockQuantity:    saleQuantityToStock(meta, quantity),
		CostPricePerUnit: saleUnitCost(meta),
	}
}

type purchaseLineSnapshot struct {
	StockUnitID       *int
	PurchaseUnitID    *int
	PurchaseUOMMode   string
	PurchaseToStock   float64
	StockQuantity     float64
	CostPricePerStock float64
}

func newPurchaseLineSnapshot(meta productMeta, quantity, unitPrice float64) purchaseLineSnapshot {
	factor := normalizeProductUOMFactor(&meta.PurchaseToStock)
	return purchaseLineSnapshot{
		StockUnitID:       meta.StockUnitID,
		PurchaseUnitID:    meta.PurchaseUnitID,
		PurchaseUOMMode:   meta.PurchaseUOMMode,
		PurchaseToStock:   factor,
		StockQuantity:     purchaseQuantityToStock(meta, quantity),
		CostPricePerStock: stockUnitCost(unitPrice, factor),
	}
}

type saleDetailSnapshot struct {
	SaleDetailID   int
	ProductID      int
	Quantity       float64
	UnitPrice      float64
	TaxAmount      float64
	CostPrice      float64
	SellingToStock float64
	StockQuantity  float64
	SellingUOMMode string
	StockUnitID    *int
	SellingUnitID  *int
}

type purchaseDetailSnapshot struct {
	PurchaseDetailID  int
	ProductID         int
	Quantity          float64
	UnitPrice         float64
	TaxAmount         float64
	PurchaseToStock   float64
	StockQuantity     float64
	PurchaseUOMMode   string
	StockUnitID       *int
	PurchaseUnitID    *int
	CostPricePerStock float64
}

func intPtrFromNullInt64(v sql.NullInt64) *int {
	if !v.Valid || v.Int64 <= 0 {
		return nil
	}
	i := int(v.Int64)
	return &i
}

func fetchSaleDetailSnapshots(q sqlQueryer, companyID int, saleDetailIDs []int) (map[int]saleDetailSnapshot, error) {
	ids := uniqueInts(saleDetailIDs)
	if len(ids) == 0 {
		return map[int]saleDetailSnapshot{}, nil
	}
	rows, err := q.Query(`
		SELECT
			sd.sale_detail_id,
			COALESCE(sd.product_id, 0),
			sd.quantity::float8,
			sd.unit_price::float8,
			COALESCE(sd.tax_amount, 0)::float8,
			COALESCE(sd.cost_price, 0)::float8,
			COALESCE(sd.selling_to_stock_factor, 1.0)::float8,
			COALESCE(NULLIF(sd.stock_quantity, 0), sd.quantity * COALESCE(sd.selling_to_stock_factor, 1.0))::float8,
			COALESCE(sd.selling_uom_mode, 'LOOSE'),
			sd.stock_unit_id,
			sd.selling_unit_id
		FROM sale_details sd
		JOIN sales s ON s.sale_id = sd.sale_id
		JOIN locations l ON l.location_id = s.location_id
		WHERE l.company_id = $1 AND sd.sale_detail_id = ANY($2)
	`, companyID, pq.Array(ids))
	if err != nil {
		return nil, fmt.Errorf("failed to fetch sale detail snapshots: %w", err)
	}
	defer rows.Close()

	out := make(map[int]saleDetailSnapshot, len(ids))
	for rows.Next() {
		var snap saleDetailSnapshot
		var stockUnitID sql.NullInt64
		var sellingUnitID sql.NullInt64
		if err := rows.Scan(
			&snap.SaleDetailID,
			&snap.ProductID,
			&snap.Quantity,
			&snap.UnitPrice,
			&snap.TaxAmount,
			&snap.CostPrice,
			&snap.SellingToStock,
			&snap.StockQuantity,
			&snap.SellingUOMMode,
			&stockUnitID,
			&sellingUnitID,
		); err != nil {
			return nil, fmt.Errorf("failed to scan sale detail snapshot: %w", err)
		}
		snap.StockUnitID = intPtrFromNullInt64(stockUnitID)
		snap.SellingUnitID = intPtrFromNullInt64(sellingUnitID)
		out[snap.SaleDetailID] = snap
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read sale detail snapshots: %w", err)
	}
	return out, nil
}

func fetchPurchaseDetailSnapshots(q sqlQueryer, companyID int, purchaseDetailIDs []int) (map[int]purchaseDetailSnapshot, error) {
	ids := uniqueInts(purchaseDetailIDs)
	if len(ids) == 0 {
		return map[int]purchaseDetailSnapshot{}, nil
	}
	rows, err := q.Query(`
		SELECT
			pd.purchase_detail_id,
			pd.product_id,
			pd.quantity::float8,
			pd.unit_price::float8,
			COALESCE(pd.tax_amount, 0)::float8,
			COALESCE(pd.purchase_to_stock_factor, 1.0)::float8,
			COALESCE(NULLIF(pd.stock_quantity, 0), pd.quantity * COALESCE(pd.purchase_to_stock_factor, 1.0))::float8,
			COALESCE(pd.purchase_uom_mode, 'LOOSE'),
			pd.stock_unit_id,
			pd.purchase_unit_id
		FROM purchase_details pd
		JOIN purchases p ON p.purchase_id = pd.purchase_id
		JOIN locations l ON l.location_id = p.location_id
		WHERE l.company_id = $1 AND pd.purchase_detail_id = ANY($2)
	`, companyID, pq.Array(ids))
	if err != nil {
		return nil, fmt.Errorf("failed to fetch purchase detail snapshots: %w", err)
	}
	defer rows.Close()

	out := make(map[int]purchaseDetailSnapshot, len(ids))
	for rows.Next() {
		var snap purchaseDetailSnapshot
		var stockUnitID sql.NullInt64
		var purchaseUnitID sql.NullInt64
		if err := rows.Scan(
			&snap.PurchaseDetailID,
			&snap.ProductID,
			&snap.Quantity,
			&snap.UnitPrice,
			&snap.TaxAmount,
			&snap.PurchaseToStock,
			&snap.StockQuantity,
			&snap.PurchaseUOMMode,
			&stockUnitID,
			&purchaseUnitID,
		); err != nil {
			return nil, fmt.Errorf("failed to scan purchase detail snapshot: %w", err)
		}
		snap.StockUnitID = intPtrFromNullInt64(stockUnitID)
		snap.PurchaseUnitID = intPtrFromNullInt64(purchaseUnitID)
		snap.CostPricePerStock = stockUnitCost(snap.UnitPrice, snap.PurchaseToStock)
		out[snap.PurchaseDetailID] = snap
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read purchase detail snapshots: %w", err)
	}
	return out, nil
}

func saleQuantityToStock(meta productMeta, quantity float64) float64 {
	return quantityInStockUOM(quantity, meta.SellingToStock)
}

func purchaseQuantityToStock(meta productMeta, quantity float64) float64 {
	return quantityInStockUOM(quantity, meta.PurchaseToStock)
}
