package services

import (
	"database/sql"
	"fmt"
	"math"
	"strings"

	"erp-backend/internal/models"
)

type preparedSaleDetail struct {
	ProductID          *int
	ComboProductID     *int
	BarcodeID          *int
	ProductName        *string
	SourceSaleDetailID *int
	Quantity           float64
	UnitPrice          float64
	DiscountPercent    float64
	DiscountAmount     float64
	TaxID              *int
	TaxAmount          float64
	LineTotal          float64
	SerialNumbers      []string
	BatchAllocations   []models.InventoryBatchSelectionInput
	Notes              *string
	Snapshot           saleLineSnapshot
}

func prepareSaleDetailsTx(tx *sql.Tx, companyID, locationID int, items []models.CreateSaleDetailRequest) ([]preparedSaleDetail, error) {
	productIDs := make([]int, 0, len(items))
	comboProductIDs := make([]int, 0, len(items))
	for _, item := range items {
		if item.ProductID != nil {
			productIDs = append(productIDs, *item.ProductID)
		}
		if item.ComboProductID != nil {
			comboProductIDs = append(comboProductIDs, *item.ComboProductID)
		}
	}

	comboMetaByID, err := fetchComboProductMeta(tx, companyID, comboProductIDs, &locationID)
	if err != nil {
		return nil, err
	}
	for _, combo := range comboMetaByID {
		for _, component := range combo.Components {
			productIDs = append(productIDs, component.ProductID)
		}
	}

	productMetaByID, err := fetchProductMeta(tx, companyID, productIDs)
	if err != nil {
		return nil, err
	}

	taxIDs := make([]int, 0, len(items))
	for _, item := range items {
		var effectiveTaxID *int
		if item.TaxID != nil {
			effectiveTaxID = item.TaxID
		} else if item.ComboProductID != nil {
			meta, ok := comboMetaByID[*item.ComboProductID]
			if !ok {
				return nil, fmt.Errorf("combo product not found")
			}
			effectiveTaxID = meta.TaxID
		} else if item.ProductID != nil {
			meta, ok := productMetaByID[*item.ProductID]
			if !ok {
				return nil, fmt.Errorf("product not found")
			}
			effectiveTaxID = meta.TaxID
		}
		if effectiveTaxID != nil {
			taxIDs = append(taxIDs, *effectiveTaxID)
		}
	}

	taxPctByID, err := fetchTaxPercentages(tx, companyID, taxIDs)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate tax: %w", err)
	}
	taxSettings, err := loadCompanyTaxSettings(tx, companyID)
	if err != nil {
		return nil, err
	}

	lines := make([]preparedSaleDetail, 0, len(items))
	for _, item := range items {
		if item.ComboProductID != nil {
			meta, ok := comboMetaByID[*item.ComboProductID]
			if !ok {
				return nil, fmt.Errorf("combo product not found")
			}
			effectiveTaxID := item.TaxID
			if effectiveTaxID == nil {
				effectiveTaxID = meta.TaxID
			}
			expanded, err := expandComboSaleItem(item, meta, effectiveTaxID, productMetaByID, taxPctByID, taxSettings.PriceMode)
			if err != nil {
				return nil, err
			}
			lines = append(lines, expanded...)
			continue
		}

		line, err := prepareStandardSaleDetail(item, productMetaByID, taxPctByID, taxSettings.PriceMode)
		if err != nil {
			return nil, err
		}
		lines = append(lines, line)
	}

	return lines, nil
}

func prepareStandardSaleDetail(item models.CreateSaleDetailRequest, productMetaByID map[int]productMeta, taxPctByID map[int]float64, taxPriceMode string) (preparedSaleDetail, error) {
	var effectiveTaxID *int
	if item.TaxID != nil {
		effectiveTaxID = item.TaxID
	} else if item.ProductID != nil {
		meta, ok := productMetaByID[*item.ProductID]
		if !ok {
			return preparedSaleDetail{}, fmt.Errorf("product not found")
		}
		effectiveTaxID = meta.TaxID
	}

	taxPercent := 0.0
	if effectiveTaxID != nil {
		pct, ok := taxPctByID[*effectiveTaxID]
		if !ok {
			return preparedSaleDetail{}, fmt.Errorf("failed to calculate tax: %w", sql.ErrNoRows)
		}
		taxPercent = pct
	}
	lineAmounts := computeTaxLine(item.Quantity, item.UnitPrice, item.DiscountPercent, taxPercent, taxPriceMode)

	lineSnapshot := saleLineSnapshot{}
	if item.ProductID != nil {
		meta, ok := productMetaByID[*item.ProductID]
		if !ok {
			return preparedSaleDetail{}, fmt.Errorf("product not found")
		}
		stockQuantity := saleQuantityToStock(meta, item.Quantity)
		if meta.IsSerialized {
			absStockQuantity := math.Abs(stockQuantity)
			if absStockQuantity != float64(int(absStockQuantity)) {
				return preparedSaleDetail{}, fmt.Errorf("quantity must be a whole number for serialized products")
			}
			if item.Quantity > 0 {
				if len(item.SerialNumbers) != int(absStockQuantity) {
					return preparedSaleDetail{}, fmt.Errorf("serial numbers count must equal quantity for serialized products")
				}
			} else if len(item.SerialNumbers) > 0 && len(item.SerialNumbers) != int(absStockQuantity) {
				return preparedSaleDetail{}, fmt.Errorf("serial numbers count must equal refund quantity for serialized products")
			}
			seen := make(map[string]struct{}, len(item.SerialNumbers))
			for _, serial := range item.SerialNumbers {
				serial = strings.TrimSpace(serial)
				if serial == "" {
					return preparedSaleDetail{}, fmt.Errorf("serial numbers cannot be empty for serialized products")
				}
				if _, ok := seen[serial]; ok {
					return preparedSaleDetail{}, fmt.Errorf("duplicate serial number '%s' in sale item", serial)
				}
				seen[serial] = struct{}{}
			}
		} else if len(item.SerialNumbers) > 0 {
			return preparedSaleDetail{}, fmt.Errorf("serial numbers provided for a non-serialized product")
		}
		lineSnapshot = newSaleLineSnapshot(meta, item.Quantity)
	}

	return preparedSaleDetail{
		ProductID:          item.ProductID,
		ComboProductID:     nil,
		BarcodeID:          item.BarcodeID,
		ProductName:        item.ProductName,
		SourceSaleDetailID: item.SourceSaleDetailID,
		Quantity:           item.Quantity,
		UnitPrice:          item.UnitPrice,
		DiscountPercent:    item.DiscountPercent,
		DiscountAmount:     lineAmounts.DiscountAmount,
		TaxID:              effectiveTaxID,
		TaxAmount:          lineAmounts.TaxAmount,
		LineTotal:          lineAmounts.NetAmount,
		SerialNumbers:      item.SerialNumbers,
		BatchAllocations:   item.BatchAllocations,
		Notes:              item.Notes,
		Snapshot:           lineSnapshot,
	}, nil
}

func expandComboSaleItem(item models.CreateSaleDetailRequest, combo comboProductMeta, effectiveTaxID *int, productMetaByID map[int]productMeta, taxPctByID map[int]float64, taxPriceMode string) ([]preparedSaleDetail, error) {
	grossTotal := item.Quantity * item.UnitPrice
	discountTotal := 0.0
	netTotal := grossTotal
	taxAmountTotal := 0.0
	if effectiveTaxID != nil {
		pct, ok := taxPctByID[*effectiveTaxID]
		if !ok {
			return nil, fmt.Errorf("failed to calculate tax: %w", sql.ErrNoRows)
		}
		lineAmounts := computeTaxLine(item.Quantity, item.UnitPrice, item.DiscountPercent, pct, taxPriceMode)
		discountTotal = lineAmounts.DiscountAmount
		netTotal = lineAmounts.NetAmount
		taxAmountTotal = lineAmounts.TaxAmount
	} else {
		lineAmounts := computeTaxLine(item.Quantity, item.UnitPrice, item.DiscountPercent, 0, taxPriceMode)
		discountTotal = lineAmounts.DiscountAmount
		netTotal = lineAmounts.NetAmount
	}

	basis := make([]float64, 0, len(combo.Components))
	totalBasis := 0.0
	componentQtys := make([]float64, 0, len(combo.Components))
	for _, component := range combo.Components {
		requiredQty := item.Quantity * component.Quantity
		componentQtys = append(componentQtys, requiredQty)
		if requiredQty <= 0 {
			basis = append(basis, 0)
			continue
		}
		componentBasis := requiredQty
		if component.SellingPrice != nil && *component.SellingPrice > 0 {
			componentBasis = requiredQty * *component.SellingPrice
		}
		basis = append(basis, componentBasis)
		totalBasis += componentBasis
	}
	if totalBasis <= 0 {
		totalBasis = float64(len(combo.Components))
		for i := range basis {
			basis[i] = 1
		}
	}

	remainingGross := grossTotal
	remainingDiscount := discountTotal
	remainingNet := netTotal
	remainingTax := taxAmountTotal
	lines := make([]preparedSaleDetail, 0, len(combo.Components))
	trackingByBarcode := make(map[int]models.ComboComponentTrackingInput, len(item.ComboComponentTracking))
	for _, tracking := range item.ComboComponentTracking {
		trackingByBarcode[tracking.BarcodeID] = tracking
	}

	for index, component := range combo.Components {
		requiredQty := componentQtys[index]
		if requiredQty <= 0 {
			continue
		}
		componentMeta, ok := productMetaByID[component.ProductID]
		if !ok {
			return nil, fmt.Errorf("product not found")
		}

		share := basis[index] / totalBasis
		componentGross := grossTotal * share
		componentDiscount := discountTotal * share
		componentNet := netTotal * share
		componentTax := taxAmountTotal * share
		if index == len(combo.Components)-1 {
			componentGross = remainingGross
			componentDiscount = remainingDiscount
			componentNet = remainingNet
			componentTax = remainingTax
		}
		remainingGross -= componentGross
		remainingDiscount -= componentDiscount
		remainingNet -= componentNet
		remainingTax -= componentTax

		unitPrice := 0.0
		if requiredQty > 0 {
			unitPrice = componentGross / requiredQty
		}
		snapshot := newSaleLineSnapshot(componentMeta, requiredQty)
		serialNumbers := []string(nil)
		batchAllocations := []models.InventoryBatchSelectionInput(nil)
		if componentMeta.IsSerialized || strings.EqualFold(component.TrackingType, trackingTypeBatch) {
			tracking, ok := trackingByBarcode[component.BarcodeID]
			if !ok {
				return nil, fmt.Errorf("tracking selection is required for %s", component.ProductName)
			}
			if tracking.ProductID != component.ProductID || tracking.BarcodeID != component.BarcodeID {
				return nil, fmt.Errorf("tracking selection does not match combo component %s", component.ProductName)
			}
			if componentMeta.IsSerialized {
				if snapshot.StockQuantity != float64(int(snapshot.StockQuantity)) {
					return nil, fmt.Errorf("quantity must be a whole number for serialized products")
				}
				if len(tracking.SerialNumbers) != int(snapshot.StockQuantity) {
					return nil, fmt.Errorf("serial numbers count must equal quantity for %s", component.ProductName)
				}
				serialNumbers = tracking.SerialNumbers
			} else {
				allocated := 0.0
				for _, alloc := range tracking.BatchAllocations {
					allocated += alloc.Quantity
				}
				if math.Abs(allocated-snapshot.StockQuantity) > 0.0001 {
					return nil, fmt.Errorf("batch allocation must equal quantity for %s", component.ProductName)
				}
				batchAllocations = tracking.BatchAllocations
			}
		}
		productName := strings.TrimSpace(component.ProductName)
		if productName == "" {
			productName = combo.Name
		}
		lines = append(lines, preparedSaleDetail{
			ProductID:        intPtr(component.ProductID),
			ComboProductID:   item.ComboProductID,
			BarcodeID:        intPtr(component.BarcodeID),
			ProductName:      &productName,
			Quantity:         requiredQty,
			UnitPrice:        unitPrice,
			DiscountPercent:  item.DiscountPercent,
			DiscountAmount:   componentDiscount,
			TaxID:            effectiveTaxID,
			TaxAmount:        componentTax,
			LineTotal:        componentNet,
			SerialNumbers:    serialNumbers,
			BatchAllocations: batchAllocations,
			Notes:            item.Notes,
			Snapshot:         snapshot,
		})
	}

	return lines, nil
}
