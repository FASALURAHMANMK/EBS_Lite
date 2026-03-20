package services

import (
	"database/sql"
	"fmt"
	"math"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"

	"github.com/lib/pq"
)

type PurchaseCostAdjustmentService struct {
	db *sql.DB
}

type receiptLineContext struct {
	GoodsReceiptItemID int
	GoodsReceiptID     int
	PurchaseDetailID   int
	ProductID          int
	BarcodeID          *int
	ReceivedQuantity   float64
	LineTotal          float64
}

type purchaseDetailContext struct {
	PurchaseDetailID  int
	PurchaseID        int
	LocationID        int
	SupplierID        int
	ProductID         int
	BarcodeID         *int
	PurchaseToStock   float64
	BaseUnitCost      float64
	ReceivedStockQty  float64
	PriorSignedAmount float64
}

type adjustmentApplicationResult struct {
	SignedAmount     float64
	InventoryPortion float64
	ConsumedPortion  float64
}

type lotCostSnapshot struct {
	LotID             int
	BarcodeID         int
	RemainingQuantity float64
	CostPrice         float64
}

type costAdjustmentLine struct {
	SourceScope        string
	GoodsReceiptItemID *int
	PurchaseDetailID   *int
	ProductID          int
	BarcodeID          *int
	Label              string
	StockAction        string
	SignedAmount       float64
	Quantity           *float64
	SerialNumbers      []string
	BatchAllocations   []models.InventoryBatchSelectionInput
	LineNote           *string
}

func NewPurchaseCostAdjustmentService() *PurchaseCostAdjustmentService {
	return &PurchaseCostAdjustmentService{db: database.GetDB()}
}

func normalizeAdjustmentDirection(value string) string {
	switch strings.ToUpper(strings.TrimSpace(value)) {
	case models.PurchaseCostAdjustmentDirectionIncome:
		return models.PurchaseCostAdjustmentDirectionIncome
	default:
		return models.PurchaseCostAdjustmentDirectionExpense
	}
}

func signedAdjustmentAmount(amount float64, direction string) float64 {
	value := math.Abs(amount)
	if normalizeAdjustmentDirection(direction) == models.PurchaseCostAdjustmentDirectionIncome {
		return -value
	}
	return value
}

func round2(value float64) float64 {
	return math.Round(value*100) / 100
}

func round4(value float64) float64 {
	return math.Round(value*10000) / 10000
}

func distributeWeightedAmount(total float64, weights []float64) []float64 {
	allocations := make([]float64, len(weights))
	if len(weights) == 0 {
		return allocations
	}

	sumWeights := 0.0
	for _, weight := range weights {
		if weight > 0 {
			sumWeights += weight
		}
	}
	if sumWeights <= 0 {
		each := round2(total / float64(len(weights)))
		accumulated := 0.0
		for i := range weights {
			if i == len(weights)-1 {
				allocations[i] = round2(total - accumulated)
				continue
			}
			allocations[i] = each
			accumulated += each
		}
		return allocations
	}

	accumulated := 0.0
	for i, weight := range weights {
		if i == len(weights)-1 {
			allocations[i] = round2(total - accumulated)
			continue
		}
		share := round2(total * (weight / sumWeights))
		allocations[i] = share
		accumulated += share
	}
	return allocations
}

func (s *PurchaseCostAdjustmentService) CreateGoodsReceiptAddons(companyID, goodsReceiptID, userID int, req *models.CreateGoodsReceiptAddonRequest) (*models.PurchaseCostAdjustment, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	lines, purchaseID, locationID, supplierID, err := s.buildGoodsReceiptAdjustmentLinesTx(tx, companyID, goodsReceiptID, req)
	if err != nil {
		return nil, err
	}
	if len(lines) == 0 {
		return nil, fmt.Errorf("at least one add-on is required")
	}

	adjustment, err := s.createAdjustmentDocumentTx(tx, companyID, userID, models.PurchaseCostAdjustmentTypeGRNAddon, &goodsReceiptID, &purchaseID, locationID, supplierID, req.ReferenceNumber, req.Notes)
	if err != nil {
		return nil, err
	}

	trackingSvc := newInventoryTrackingService(s.db)
	totalSigned := 0.0
	for _, line := range lines {
		item, result, err := s.applyCostOnlyLineTx(tx, companyID, userID, adjustment.AdjustmentID, line)
		if err != nil {
			return nil, err
		}
		adjustment.Items = append(adjustment.Items, *item)
		totalSigned += result.SignedAmount
		if line.BarcodeID != nil && *line.BarcodeID > 0 {
			if err := s.syncVariantAverageCostTx(tx, locationID, *line.BarcodeID); err != nil {
				return nil, err
			}
		}
		if err := trackingSvc.updateProductCostSnapshotTx(tx, companyID, line.ProductID); err != nil {
			return nil, fmt.Errorf("failed to update product cost snapshot: %w", err)
		}
	}

	if err := s.finalizeAdjustmentTx(tx, adjustment.AdjustmentID, userID, round2(totalSigned)); err != nil {
		return nil, err
	}
	if err := s.updatePurchaseTotalsTx(tx, purchaseID, companyID, round2(totalSigned)); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit adjustment: %w", err)
	}

	adjustment.TotalAmount = round2(totalSigned)
	_ = (&LedgerService{db: s.db}).RecordPurchaseCostAdjustment(companyID, adjustment.AdjustmentID, userID)
	return adjustment, nil
}

func (s *PurchaseCostAdjustmentService) GetGoodsReceiptAddons(companyID, goodsReceiptID int) ([]models.PurchaseCostAdjustment, error) {
	return s.listAdjustments(companyID, map[string]string{
		"adjustment_type":  models.PurchaseCostAdjustmentTypeGRNAddon,
		"goods_receipt_id": fmt.Sprintf("%d", goodsReceiptID),
	}, true)
}

func (s *PurchaseCostAdjustmentService) ListSupplierDebitNotes(companyID, locationID int, filters map[string]string) ([]models.PurchaseCostAdjustment, error) {
	if filters == nil {
		filters = map[string]string{}
	}
	filters["adjustment_type"] = models.PurchaseCostAdjustmentTypeSupplierDebitNote
	filters["location_id"] = fmt.Sprintf("%d", locationID)
	return s.listAdjustments(companyID, filters, false)
}

func (s *PurchaseCostAdjustmentService) GetSupplierDebitNoteByID(companyID, id int) (*models.PurchaseCostAdjustment, error) {
	return s.getAdjustmentByID(companyID, id, models.PurchaseCostAdjustmentTypeSupplierDebitNote)
}

func (s *PurchaseCostAdjustmentService) CreateSupplierDebitNote(companyID, locationID, userID int, req *models.CreateSupplierDebitNoteRequest) (*models.PurchaseCostAdjustment, error) {
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback()

	var purchaseLocationID int
	var supplierID int
	if err := tx.QueryRow(`
		SELECT p.location_id, p.supplier_id
		FROM purchases p
		JOIN suppliers s ON s.supplier_id = p.supplier_id
		WHERE p.purchase_id = $1 AND s.company_id = $2 AND p.is_deleted = FALSE
	`, req.PurchaseID, companyID).Scan(&purchaseLocationID, &supplierID); err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("purchase not found")
		}
		return nil, fmt.Errorf("failed to verify purchase: %w", err)
	}
	if supplierID != req.SupplierID {
		return nil, fmt.Errorf("supplier does not match purchase")
	}
	if locationID == 0 {
		locationID = purchaseLocationID
	}
	if purchaseLocationID != locationID {
		return nil, fmt.Errorf("invalid location for purchase")
	}

	adjustment, err := s.createAdjustmentDocumentTx(tx, companyID, userID, models.PurchaseCostAdjustmentTypeSupplierDebitNote, nil, &req.PurchaseID, locationID, supplierID, req.ReferenceNumber, req.Notes)
	if err != nil {
		return nil, err
	}

	trackingSvc := newInventoryTrackingService(s.db)
	totalSigned := 0.0
	for _, input := range req.Items {
		if input.PurchaseDetailID == nil || *input.PurchaseDetailID <= 0 {
			return nil, fmt.Errorf("purchase_detail_id is required for supplier debit notes")
		}
		ctx, err := s.loadPurchaseDetailContextTx(tx, companyID, *input.PurchaseDetailID)
		if err != nil {
			return nil, err
		}
		if ctx.PurchaseID != req.PurchaseID {
			return nil, fmt.Errorf("purchase detail does not belong to purchase")
		}
		barcodeID := firstNonNilInt(input.BarcodeID, ctx.BarcodeID)
		line := costAdjustmentLine{
			SourceScope:      models.PurchaseCostAdjustmentScopeItem,
			PurchaseDetailID: input.PurchaseDetailID,
			ProductID:        input.ProductID,
			BarcodeID:        barcodeID,
			Label:            strings.TrimSpace(input.Label),
			StockAction:      input.StockAction,
			Quantity:         input.Quantity,
			SerialNumbers:    input.SerialNumbers,
			BatchAllocations: input.BatchAllocations,
			LineNote:         input.LineNote,
		}

		if input.StockAction == models.PurchaseCostAdjustmentStockActionCostOnly {
			if input.Amount == nil || *input.Amount <= 0 {
				return nil, fmt.Errorf("amount is required for cost-only supplier debit note lines")
			}
			line.SignedAmount = -math.Abs(*input.Amount)
			item, result, err := s.applyCostOnlyLineTx(tx, companyID, userID, adjustment.AdjustmentID, line)
			if err != nil {
				return nil, err
			}
			adjustment.Items = append(adjustment.Items, *item)
			totalSigned += result.SignedAmount
			if barcodeID != nil && *barcodeID > 0 {
				if err := s.syncVariantAverageCostTx(tx, locationID, *barcodeID); err != nil {
					return nil, err
				}
			}
			if err := trackingSvc.updateProductCostSnapshotTx(tx, companyID, line.ProductID); err != nil {
				return nil, fmt.Errorf("failed to update product cost snapshot: %w", err)
			}
			continue
		}

		item, result, err := s.applyStockReductionLineTx(tx, companyID, userID, adjustment.AdjustmentID, ctx, line, input.Amount)
		if err != nil {
			return nil, err
		}
		adjustment.Items = append(adjustment.Items, *item)
		totalSigned += result.SignedAmount
		if barcodeID != nil && *barcodeID > 0 {
			if err := s.syncVariantAverageCostTx(tx, locationID, *barcodeID); err != nil {
				return nil, err
			}
		}
		if err := trackingSvc.updateProductCostSnapshotTx(tx, companyID, line.ProductID); err != nil {
			return nil, fmt.Errorf("failed to update product cost snapshot: %w", err)
		}
	}

	if err := s.finalizeAdjustmentTx(tx, adjustment.AdjustmentID, userID, round2(totalSigned)); err != nil {
		return nil, err
	}
	if err := s.updatePurchaseTotalsTx(tx, req.PurchaseID, companyID, round2(totalSigned)); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit supplier debit note: %w", err)
	}

	adjustment.TotalAmount = round2(totalSigned)
	_ = (&LedgerService{db: s.db}).RecordPurchaseCostAdjustment(companyID, adjustment.AdjustmentID, userID)
	return adjustment, nil
}

func (s *PurchaseCostAdjustmentService) buildGoodsReceiptAdjustmentLinesTx(tx *sql.Tx, companyID, goodsReceiptID int, req *models.CreateGoodsReceiptAddonRequest) ([]costAdjustmentLine, int, int, int, error) {
	lines, purchaseID, locationID, supplierID, err := s.loadReceiptLineContextsTx(tx, companyID, goodsReceiptID)
	if err != nil {
		return nil, 0, 0, 0, err
	}
	if len(lines) == 0 {
		return nil, 0, 0, 0, fmt.Errorf("goods receipt has no items")
	}

	byPurchaseDetail := make(map[int]receiptLineContext, len(lines))
	weights := make([]float64, 0, len(lines))
	for _, line := range lines {
		byPurchaseDetail[line.PurchaseDetailID] = line
		weights = append(weights, math.Max(line.LineTotal, 0))
	}

	derived := make([]costAdjustmentLine, 0, len(req.HeaderAdjustments)+len(req.ItemAdjustments))
	for _, header := range req.HeaderAdjustments {
		allocated := distributeWeightedAmount(header.Amount, weights)
		for idx, line := range lines {
			signed := signedAdjustmentAmount(allocated[idx], header.Direction)
			if math.Abs(signed) < 0.0001 {
				continue
			}
			gri := line.GoodsReceiptItemID
			pd := line.PurchaseDetailID
			derived = append(derived, costAdjustmentLine{
				SourceScope:        models.PurchaseCostAdjustmentScopeHeader,
				GoodsReceiptItemID: &gri,
				PurchaseDetailID:   &pd,
				ProductID:          line.ProductID,
				BarcodeID:          line.BarcodeID,
				Label:              strings.TrimSpace(header.Label),
				StockAction:        models.PurchaseCostAdjustmentStockActionCostOnly,
				SignedAmount:       round2(signed),
			})
		}
	}

	for _, item := range req.ItemAdjustments {
		line, ok := byPurchaseDetail[item.PurchaseDetailID]
		if !ok {
			return nil, 0, 0, 0, fmt.Errorf("purchase detail %d not found on this goods receipt", item.PurchaseDetailID)
		}
		gri := line.GoodsReceiptItemID
		pd := line.PurchaseDetailID
		derived = append(derived, costAdjustmentLine{
			SourceScope:        models.PurchaseCostAdjustmentScopeItem,
			GoodsReceiptItemID: &gri,
			PurchaseDetailID:   &pd,
			ProductID:          line.ProductID,
			BarcodeID:          line.BarcodeID,
			Label:              strings.TrimSpace(item.Label),
			StockAction:        models.PurchaseCostAdjustmentStockActionCostOnly,
			SignedAmount:       round2(signedAdjustmentAmount(item.Amount, item.Direction)),
		})
	}

	return derived, purchaseID, locationID, supplierID, nil
}

func (s *PurchaseCostAdjustmentService) createAdjustmentDocumentTx(tx *sql.Tx, companyID, userID int, adjustmentType string, goodsReceiptID, purchaseID *int, locationID, supplierID int, referenceNumber, notes *string) (*models.PurchaseCostAdjustment, error) {
	ns := NewNumberingSequenceService()
	sequenceName := "purchase_cost_adjustment"
	if adjustmentType == models.PurchaseCostAdjustmentTypeSupplierDebitNote {
		sequenceName = "supplier_debit_note"
	}
	adjustmentNumber, err := ns.NextNumber(tx, sequenceName, companyID, &locationID)
	if err != nil {
		return nil, fmt.Errorf("failed to generate adjustment number: %w", err)
	}

	var adjustment models.PurchaseCostAdjustment
	if err := tx.QueryRow(`
		INSERT INTO purchase_cost_adjustments (
			adjustment_number, adjustment_type, goods_receipt_id, purchase_id, location_id,
			supplier_id, adjustment_date, reference_number, notes, total_amount, created_by, updated_by
		)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,0,$10,$10)
		RETURNING adjustment_id, created_at, updated_at
	`, adjustmentNumber, adjustmentType, goodsReceiptID, purchaseID, locationID, supplierID, time.Now(), referenceNumber, notes, userID).Scan(
		&adjustment.AdjustmentID, &adjustment.CreatedAt, &adjustment.UpdatedAt,
	); err != nil {
		return nil, fmt.Errorf("failed to create purchase cost adjustment: %w", err)
	}

	adjustment.AdjustmentNumber = adjustmentNumber
	adjustment.AdjustmentType = adjustmentType
	adjustment.GoodsReceiptID = goodsReceiptID
	adjustment.PurchaseID = purchaseID
	adjustment.LocationID = locationID
	adjustment.SupplierID = supplierID
	adjustment.AdjustmentDate = time.Now()
	adjustment.ReferenceNumber = referenceNumber
	adjustment.Notes = notes
	adjustment.CreatedBy = userID
	return &adjustment, nil
}

func (s *PurchaseCostAdjustmentService) finalizeAdjustmentTx(tx *sql.Tx, adjustmentID, userID int, totalSigned float64) error {
	if _, err := tx.Exec(`
		UPDATE purchase_cost_adjustments
		SET total_amount = $1,
		    updated_by = $2,
		    updated_at = CURRENT_TIMESTAMP
		WHERE adjustment_id = $3
	`, totalSigned, userID, adjustmentID); err != nil {
		return fmt.Errorf("failed to finalize adjustment: %w", err)
	}
	return nil
}

func (s *PurchaseCostAdjustmentService) updatePurchaseTotalsTx(tx *sql.Tx, purchaseID, companyID int, totalSigned float64) error {
	var currentTotal float64
	if err := tx.QueryRow(`
		SELECT p.total_amount::float8
		FROM purchases p
		JOIN suppliers s ON s.supplier_id = p.supplier_id
		WHERE p.purchase_id = $1 AND s.company_id = $2 AND p.is_deleted = FALSE
	`, purchaseID, companyID).Scan(&currentTotal); err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("purchase not found")
		}
		return fmt.Errorf("failed to load purchase totals: %w", err)
	}
	if currentTotal+totalSigned < -0.0001 {
		return fmt.Errorf("purchase total cannot be reduced below zero")
	}
	if _, err := tx.Exec(`
		UPDATE purchases p
		SET subtotal = subtotal + $1,
		    total_amount = total_amount + $1,
		    updated_at = CURRENT_TIMESTAMP
		FROM suppliers s
		WHERE p.purchase_id = $2 AND p.supplier_id = s.supplier_id AND s.company_id = $3
	`, totalSigned, purchaseID, companyID); err != nil {
		return fmt.Errorf("failed to update purchase totals: %w", err)
	}
	return nil
}

func (s *PurchaseCostAdjustmentService) applyCostOnlyLineTx(tx *sql.Tx, companyID, userID, adjustmentID int, line costAdjustmentLine) (*models.PurchaseCostAdjustmentItem, *adjustmentApplicationResult, error) {
	if line.PurchaseDetailID == nil || *line.PurchaseDetailID <= 0 {
		return nil, nil, fmt.Errorf("purchase detail is required")
	}
	ctx, err := s.loadPurchaseDetailContextTx(tx, companyID, *line.PurchaseDetailID)
	if err != nil {
		return nil, nil, err
	}
	receiptScope := 0
	if line.GoodsReceiptItemID != nil && *line.GoodsReceiptItemID > 0 {
		receiptScope = *line.GoodsReceiptItemID
	}
	result, err := s.revaluePurchaseDetailTx(tx, companyID, ctx, line.BarcodeID, receiptScope, line.SignedAmount)
	if err != nil {
		return nil, nil, err
	}
	item, err := s.insertAdjustmentItemTx(tx, adjustmentID, line, result.SignedAmount, nil, nil)
	if err != nil {
		return nil, nil, err
	}
	return item, result, nil
}

func (s *PurchaseCostAdjustmentService) applyStockReductionLineTx(tx *sql.Tx, companyID, userID, adjustmentID int, ctx *purchaseDetailContext, line costAdjustmentLine, requestedAmount *float64) (*models.PurchaseCostAdjustmentItem, *adjustmentApplicationResult, error) {
	if line.Quantity == nil || *line.Quantity <= 0 {
		return nil, nil, fmt.Errorf("quantity is required for stock reduction")
	}
	item, err := s.insertAdjustmentItemTx(tx, adjustmentID, line, 0, line.Quantity, nil)
	if err != nil {
		return nil, nil, err
	}

	stockQuantity := quantityInStockUOM(*line.Quantity, ctx.PurchaseToStock)
	trackingSvc := newInventoryTrackingService(s.db)
	issue, err := trackingSvc.IssueStockTx(tx, companyID, ctx.LocationID, userID, "SUPPLIER_DEBIT_NOTE", "purchase_cost_adjustment_item", &item.AdjustmentItemID, nil, inventorySelection{
		ProductID:        ctx.ProductID,
		BarcodeID:        line.BarcodeID,
		Quantity:         stockQuantity,
		SerialNumbers:    line.SerialNumbers,
		BatchAllocations: line.BatchAllocations,
		Notes:            line.LineNote,
	})
	if err != nil {
		return nil, nil, fmt.Errorf("failed to reduce stock: %w", err)
	}

	derivedAmount := round2(-issue.TotalCost)
	if requestedAmount != nil && math.Abs(math.Abs(*requestedAmount)-math.Abs(derivedAmount)) > 0.01 {
		return nil, nil, fmt.Errorf("supplier debit note amount must match current inventory cost for stock reduction")
	}
	if _, err := tx.Exec(`
		UPDATE purchase_cost_adjustment_items
		SET barcode_id = $1,
		    signed_amount = $2,
		    stock_quantity = $3
		WHERE adjustment_item_id = $4
	`, issue.BarcodeID, derivedAmount, stockQuantity, item.AdjustmentItemID); err != nil {
		return nil, nil, fmt.Errorf("failed to update stock reduction line: %w", err)
	}
	barcodeID := issue.BarcodeID
	item.BarcodeID = &barcodeID
	item.SignedAmount = derivedAmount
	item.StockQuantity = &stockQuantity
	return item, &adjustmentApplicationResult{
		SignedAmount:     derivedAmount,
		InventoryPortion: derivedAmount,
		ConsumedPortion:  0,
	}, nil
}

func (s *PurchaseCostAdjustmentService) insertAdjustmentItemTx(tx *sql.Tx, adjustmentID int, line costAdjustmentLine, signedAmount float64, quantity, stockQuantity *float64) (*models.PurchaseCostAdjustmentItem, error) {
	var item models.PurchaseCostAdjustmentItem
	rawBatch := []byte("[]")
	if len(line.BatchAllocations) > 0 {
		rawBatch = encodeBatchAllocations(line.BatchAllocations)
	}
	if err := tx.QueryRow(`
		INSERT INTO purchase_cost_adjustment_items (
			adjustment_id, source_scope, goods_receipt_item_id, purchase_detail_id,
			product_id, barcode_id, adjustment_label, stock_action, signed_amount,
			quantity, stock_quantity, serial_numbers, batch_allocations, line_note
		)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
		RETURNING adjustment_item_id
	`, adjustmentID, line.SourceScope, line.GoodsReceiptItemID, line.PurchaseDetailID,
		line.ProductID, line.BarcodeID, line.Label, line.StockAction, signedAmount,
		quantity, stockQuantity, pq.Array(line.SerialNumbers), rawBatch, line.LineNote,
	).Scan(&item.AdjustmentItemID); err != nil {
		return nil, fmt.Errorf("failed to create adjustment line: %w", err)
	}
	item.AdjustmentID = adjustmentID
	item.SourceScope = line.SourceScope
	item.GoodsReceiptItemID = line.GoodsReceiptItemID
	item.PurchaseDetailID = line.PurchaseDetailID
	item.ProductID = line.ProductID
	item.BarcodeID = line.BarcodeID
	item.AdjustmentLabel = line.Label
	item.StockAction = line.StockAction
	item.SignedAmount = signedAmount
	item.Quantity = quantity
	item.StockQuantity = stockQuantity
	item.SerialNumbers = line.SerialNumbers
	item.BatchAllocations = line.BatchAllocations
	item.LineNote = line.LineNote
	return &item, nil
}

func (s *PurchaseCostAdjustmentService) loadReceiptLineContextsTx(tx *sql.Tx, companyID, goodsReceiptID int) ([]receiptLineContext, int, int, int, error) {
	var purchaseID int
	var locationID int
	var supplierID int
	if err := tx.QueryRow(`
		SELECT gr.purchase_id, gr.location_id, gr.supplier_id
		FROM goods_receipts gr
		JOIN suppliers s ON s.supplier_id = gr.supplier_id
		WHERE gr.goods_receipt_id = $1 AND s.company_id = $2 AND gr.is_deleted = FALSE
	`, goodsReceiptID, companyID).Scan(&purchaseID, &locationID, &supplierID); err != nil {
		if err == sql.ErrNoRows {
			return nil, 0, 0, 0, fmt.Errorf("goods receipt not found")
		}
		return nil, 0, 0, 0, fmt.Errorf("failed to load goods receipt: %w", err)
	}

	rows, err := tx.Query(`
		SELECT
			gri.goods_receipt_item_id,
			gri.goods_receipt_id,
			gri.purchase_detail_id,
			gri.product_id,
			gri.barcode_id,
			gri.received_quantity::float8,
			gri.line_total::float8
		FROM goods_receipt_items gri
		WHERE gri.goods_receipt_id = $1
		ORDER BY gri.goods_receipt_item_id
	`, goodsReceiptID)
	if err != nil {
		return nil, 0, 0, 0, fmt.Errorf("failed to load goods receipt items: %w", err)
	}
	defer rows.Close()

	lines := make([]receiptLineContext, 0)
	for rows.Next() {
		var line receiptLineContext
		var barcodeID sql.NullInt64
		if err := rows.Scan(
			&line.GoodsReceiptItemID,
			&line.GoodsReceiptID,
			&line.PurchaseDetailID,
			&line.ProductID,
			&barcodeID,
			&line.ReceivedQuantity,
			&line.LineTotal,
		); err != nil {
			return nil, 0, 0, 0, fmt.Errorf("failed to scan goods receipt item: %w", err)
		}
		line.BarcodeID = intPtrFromNullInt64(barcodeID)
		lines = append(lines, line)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, 0, 0, fmt.Errorf("failed to read goods receipt items: %w", err)
	}
	return lines, purchaseID, locationID, supplierID, nil
}

func (s *PurchaseCostAdjustmentService) loadPurchaseDetailContextTx(tx *sql.Tx, companyID, purchaseDetailID int) (*purchaseDetailContext, error) {
	var ctx purchaseDetailContext
	var barcodeID sql.NullInt64
	if err := tx.QueryRow(`
		SELECT
			pd.purchase_detail_id,
			pd.purchase_id,
			p.location_id,
			p.supplier_id,
			pd.product_id,
			pd.barcode_id,
			COALESCE(pd.purchase_to_stock_factor, 1.0)::float8,
			COALESCE(pd.unit_price, 0)::float8,
			COALESCE((
				SELECT SUM(im.quantity)::float8
				FROM inventory_movements im
				WHERE im.source_type = 'purchase_detail'
				  AND im.source_line_id = pd.purchase_detail_id
				  AND im.movement_type = 'PURCHASE_RECEIPT'
			), 0)::float8 AS received_stock_qty,
			COALESCE((
				SELECT SUM(pcai.signed_amount)::float8
				FROM purchase_cost_adjustment_items pcai
				JOIN purchase_cost_adjustments pca ON pca.adjustment_id = pcai.adjustment_id
				WHERE pcai.purchase_detail_id = pd.purchase_detail_id
				  AND pcai.stock_action = 'COST_ONLY'
				  AND pca.is_deleted = FALSE
			), 0)::float8 AS prior_signed_amount
		FROM purchase_details pd
		JOIN purchases p ON p.purchase_id = pd.purchase_id
		JOIN suppliers s ON s.supplier_id = p.supplier_id
		WHERE pd.purchase_detail_id = $1 AND s.company_id = $2 AND p.is_deleted = FALSE
	`, purchaseDetailID, companyID).Scan(
		&ctx.PurchaseDetailID,
		&ctx.PurchaseID,
		&ctx.LocationID,
		&ctx.SupplierID,
		&ctx.ProductID,
		&barcodeID,
		&ctx.PurchaseToStock,
		&ctx.BaseUnitCost,
		&ctx.ReceivedStockQty,
		&ctx.PriorSignedAmount,
	); err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("purchase detail not found")
		}
		return nil, fmt.Errorf("failed to load purchase detail: %w", err)
	}
	ctx.BarcodeID = intPtrFromNullInt64(barcodeID)
	ctx.BaseUnitCost = stockUnitCost(ctx.BaseUnitCost, ctx.PurchaseToStock)
	return &ctx, nil
}

func (s *PurchaseCostAdjustmentService) revaluePurchaseDetailTx(tx *sql.Tx, companyID int, ctx *purchaseDetailContext, barcodeID *int, goodsReceiptItemID int, signedAmount float64) (*adjustmentApplicationResult, error) {
	if ctx.ReceivedStockQty <= 0 {
		return nil, fmt.Errorf("cannot adjust cost before goods are received")
	}
	currentUnitCost := ctx.BaseUnitCost + (ctx.PriorSignedAmount / ctx.ReceivedStockQty)
	newUnitCost := currentUnitCost + (signedAmount / ctx.ReceivedStockQty)
	if newUnitCost < -0.0001 {
		return nil, fmt.Errorf("cost adjustment would reduce item cost below zero")
	}

	lots, err := s.loadLotsForRevaluationTx(tx, ctx.LocationID, ctx.PurchaseDetailID, barcodeID, goodsReceiptItemID)
	if err != nil {
		return nil, err
	}
	unitDelta := signedAmount / ctx.ReceivedStockQty
	remainingQty := 0.0
	for _, lot := range lots {
		nextCost := round2(lot.CostPrice + unitDelta)
		if nextCost < -0.0001 {
			return nil, fmt.Errorf("cost adjustment would reduce remaining lot below zero")
		}
		if _, err := tx.Exec(`
			UPDATE stock_lots
			SET cost_price = $1
			WHERE lot_id = $2
		`, nextCost, lot.LotID); err != nil {
			return nil, fmt.Errorf("failed to update stock lot cost: %w", err)
		}
		if _, err := tx.Exec(`
			UPDATE product_serials
			SET cost_price = $1
			WHERE stock_lot_id = $2 AND status = 'IN_STOCK'
		`, round4(nextCost), lot.LotID); err != nil {
			return nil, fmt.Errorf("failed to update serial cost: %w", err)
		}
		remainingQty += lot.RemainingQuantity
	}

	inventoryPortion := round2(unitDelta * remainingQty)
	consumedPortion := round2(signedAmount - inventoryPortion)
	return &adjustmentApplicationResult{
		SignedAmount:     round2(signedAmount),
		InventoryPortion: inventoryPortion,
		ConsumedPortion:  consumedPortion,
	}, nil
}

func (s *PurchaseCostAdjustmentService) loadLotsForRevaluationTx(tx *sql.Tx, locationID, purchaseDetailID int, barcodeID *int, goodsReceiptItemID int) ([]lotCostSnapshot, error) {
	query := `
		SELECT sl.lot_id, sl.barcode_id, sl.remaining_quantity::float8, sl.cost_price::float8
		FROM stock_lots sl
		WHERE sl.location_id = $1
		  AND sl.remaining_quantity > 0
		  AND sl.lot_id IN (
		    SELECT DISTINCT im.stock_lot_id
		    FROM inventory_movements im
		    WHERE im.source_type = 'purchase_detail'
		      AND im.source_line_id = $2
		      AND im.movement_type = 'PURCHASE_RECEIPT'
		      AND im.stock_lot_id IS NOT NULL
		  )
	`
	args := []interface{}{locationID, purchaseDetailID}
	next := 3
	if goodsReceiptItemID > 0 {
		query += fmt.Sprintf(" AND sl.goods_receipt_id = (SELECT goods_receipt_id FROM goods_receipt_items WHERE goods_receipt_item_id = $%d)", next)
		args = append(args, goodsReceiptItemID)
		next++
	}
	if barcodeID != nil && *barcodeID > 0 {
		query += fmt.Sprintf(" AND sl.barcode_id = $%d", next)
		args = append(args, *barcodeID)
	}
	query += " ORDER BY sl.lot_id FOR UPDATE"

	rows, err := tx.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to load lots for revaluation: %w", err)
	}
	defer rows.Close()

	lots := make([]lotCostSnapshot, 0)
	for rows.Next() {
		var lot lotCostSnapshot
		if err := rows.Scan(&lot.LotID, &lot.BarcodeID, &lot.RemainingQuantity, &lot.CostPrice); err != nil {
			return nil, fmt.Errorf("failed to scan revaluation lot: %w", err)
		}
		lots = append(lots, lot)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("failed to read revaluation lots: %w", err)
	}
	return lots, nil
}

func (s *PurchaseCostAdjustmentService) syncVariantAverageCostTx(tx *sql.Tx, locationID, barcodeID int) error {
	var averageCost float64
	if err := tx.QueryRow(`
		SELECT COALESCE(
			CASE
				WHEN SUM(remaining_quantity) > 0
					THEN SUM(remaining_quantity * cost_price) / SUM(remaining_quantity)
				ELSE 0
			END,
			0
		)::float8
		FROM stock_lots
		WHERE location_id = $1 AND barcode_id = $2
	`, locationID, barcodeID).Scan(&averageCost); err != nil {
		return fmt.Errorf("failed to calculate average cost: %w", err)
	}
	if _, err := tx.Exec(`
		UPDATE stock_variants
		SET average_cost = $1,
		    last_updated = CURRENT_TIMESTAMP
		WHERE location_id = $2 AND barcode_id = $3
	`, round4(averageCost), locationID, barcodeID); err != nil {
		return fmt.Errorf("failed to sync variant average cost: %w", err)
	}
	return nil
}

func (s *PurchaseCostAdjustmentService) listAdjustments(companyID int, filters map[string]string, includeItems bool) ([]models.PurchaseCostAdjustment, error) {
	query := `
		SELECT
			pca.adjustment_id,
			pca.adjustment_number,
			pca.adjustment_type,
			pca.goods_receipt_id,
			pca.purchase_id,
			pca.location_id,
			pca.supplier_id,
			pca.adjustment_date,
			pca.reference_number,
			pca.notes,
			pca.total_amount::float8,
			pca.created_by,
			pca.updated_by,
			pca.sync_status,
			pca.created_at,
			pca.updated_at,
			s.name
		FROM purchase_cost_adjustments pca
		JOIN suppliers s ON s.supplier_id = pca.supplier_id
		WHERE s.company_id = $1
		  AND pca.is_deleted = FALSE
	`
	args := []interface{}{companyID}
	arg := 2
	if v := strings.TrimSpace(filters["adjustment_type"]); v != "" {
		query += fmt.Sprintf(" AND pca.adjustment_type = $%d", arg)
		args = append(args, v)
		arg++
	}
	if v := strings.TrimSpace(filters["goods_receipt_id"]); v != "" {
		query += fmt.Sprintf(" AND pca.goods_receipt_id = $%d", arg)
		args = append(args, v)
		arg++
	}
	if v := strings.TrimSpace(filters["supplier_id"]); v != "" {
		query += fmt.Sprintf(" AND pca.supplier_id = $%d", arg)
		args = append(args, v)
		arg++
	}
	if v := strings.TrimSpace(filters["purchase_id"]); v != "" {
		query += fmt.Sprintf(" AND pca.purchase_id = $%d", arg)
		args = append(args, v)
		arg++
	}
	if v := strings.TrimSpace(filters["location_id"]); v != "" {
		query += fmt.Sprintf(" AND pca.location_id = $%d", arg)
		args = append(args, v)
		arg++
	}
	query += " ORDER BY pca.adjustment_date DESC, pca.adjustment_id DESC"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to get purchase cost adjustments: %w", err)
	}
	defer rows.Close()

	items := make([]models.PurchaseCostAdjustment, 0)
	for rows.Next() {
		var adjustment models.PurchaseCostAdjustment
		var goodsReceiptID sql.NullInt64
		var purchaseID sql.NullInt64
		var referenceNumber sql.NullString
		var notes sql.NullString
		var updatedBy sql.NullInt64
		var supplierName string
		if err := rows.Scan(
			&adjustment.AdjustmentID,
			&adjustment.AdjustmentNumber,
			&adjustment.AdjustmentType,
			&goodsReceiptID,
			&purchaseID,
			&adjustment.LocationID,
			&adjustment.SupplierID,
			&adjustment.AdjustmentDate,
			&referenceNumber,
			&notes,
			&adjustment.TotalAmount,
			&adjustment.CreatedBy,
			&updatedBy,
			&adjustment.SyncStatus,
			&adjustment.CreatedAt,
			&adjustment.UpdatedAt,
			&supplierName,
		); err != nil {
			return nil, fmt.Errorf("failed to scan adjustment: %w", err)
		}
		if goodsReceiptID.Valid {
			id := int(goodsReceiptID.Int64)
			adjustment.GoodsReceiptID = &id
		}
		if purchaseID.Valid {
			id := int(purchaseID.Int64)
			adjustment.PurchaseID = &id
		}
		if referenceNumber.Valid {
			adjustment.ReferenceNumber = &referenceNumber.String
		}
		if notes.Valid {
			adjustment.Notes = &notes.String
		}
		if updatedBy.Valid {
			id := int(updatedBy.Int64)
			adjustment.UpdatedBy = &id
		}
		adjustment.Supplier = &models.Supplier{Name: supplierName}
		if includeItems {
			detail, err := s.getAdjustmentByID(companyID, adjustment.AdjustmentID, adjustment.AdjustmentType)
			if err != nil {
				return nil, err
			}
			adjustment.Items = detail.Items
		}
		items = append(items, adjustment)
	}
	return items, nil
}

func (s *PurchaseCostAdjustmentService) getAdjustmentByID(companyID, id int, requiredType string) (*models.PurchaseCostAdjustment, error) {
	var adjustment models.PurchaseCostAdjustment
	var goodsReceiptID sql.NullInt64
	var purchaseID sql.NullInt64
	var referenceNumber sql.NullString
	var notes sql.NullString
	var updatedBy sql.NullInt64
	var supplierName string
	if err := s.db.QueryRow(`
		SELECT
			pca.adjustment_id,
			pca.adjustment_number,
			pca.adjustment_type,
			pca.goods_receipt_id,
			pca.purchase_id,
			pca.location_id,
			pca.supplier_id,
			pca.adjustment_date,
			pca.reference_number,
			pca.notes,
			pca.total_amount::float8,
			pca.created_by,
			pca.updated_by,
			pca.sync_status,
			pca.created_at,
			pca.updated_at,
			s.name
		FROM purchase_cost_adjustments pca
		JOIN suppliers s ON s.supplier_id = pca.supplier_id
		WHERE pca.adjustment_id = $1
		  AND pca.adjustment_type = $2
		  AND s.company_id = $3
		  AND pca.is_deleted = FALSE
	`, id, requiredType, companyID).Scan(
		&adjustment.AdjustmentID,
		&adjustment.AdjustmentNumber,
		&adjustment.AdjustmentType,
		&goodsReceiptID,
		&purchaseID,
		&adjustment.LocationID,
		&adjustment.SupplierID,
		&adjustment.AdjustmentDate,
		&referenceNumber,
		&notes,
		&adjustment.TotalAmount,
		&adjustment.CreatedBy,
		&updatedBy,
		&adjustment.SyncStatus,
		&adjustment.CreatedAt,
		&adjustment.UpdatedAt,
		&supplierName,
	); err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("purchase cost adjustment not found")
		}
		return nil, fmt.Errorf("failed to get purchase cost adjustment: %w", err)
	}
	if goodsReceiptID.Valid {
		value := int(goodsReceiptID.Int64)
		adjustment.GoodsReceiptID = &value
	}
	if purchaseID.Valid {
		value := int(purchaseID.Int64)
		adjustment.PurchaseID = &value
	}
	if referenceNumber.Valid {
		adjustment.ReferenceNumber = &referenceNumber.String
	}
	if notes.Valid {
		adjustment.Notes = &notes.String
	}
	if updatedBy.Valid {
		value := int(updatedBy.Int64)
		adjustment.UpdatedBy = &value
	}
	adjustment.Supplier = &models.Supplier{Name: supplierName}

	rows, err := s.db.Query(`
		SELECT
			pcai.adjustment_item_id,
			pcai.adjustment_id,
			pcai.source_scope,
			pcai.goods_receipt_item_id,
			pcai.purchase_detail_id,
			pcai.product_id,
			pcai.barcode_id,
			pcai.adjustment_label,
			pcai.stock_action,
			pcai.signed_amount::float8,
			pcai.quantity::float8,
			pcai.stock_quantity::float8,
			pcai.serial_numbers,
			COALESCE(pcai.batch_allocations, '[]'::jsonb),
			pcai.line_note,
			p.name,
			p.sku
		FROM purchase_cost_adjustment_items pcai
		JOIN products p ON p.product_id = pcai.product_id
		WHERE pcai.adjustment_id = $1
		ORDER BY pcai.adjustment_item_id
	`, id)
	if err != nil {
		return nil, fmt.Errorf("failed to get adjustment lines: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var item models.PurchaseCostAdjustmentItem
		var goodsReceiptItemID sql.NullInt64
		var purchaseDetailID sql.NullInt64
		var barcodeID sql.NullInt64
		var quantity sql.NullFloat64
		var stockQuantity sql.NullFloat64
		var rawBatch []byte
		var lineNote sql.NullString
		var productName string
		var sku sql.NullString
		if err := rows.Scan(
			&item.AdjustmentItemID,
			&item.AdjustmentID,
			&item.SourceScope,
			&goodsReceiptItemID,
			&purchaseDetailID,
			&item.ProductID,
			&barcodeID,
			&item.AdjustmentLabel,
			&item.StockAction,
			&item.SignedAmount,
			&quantity,
			&stockQuantity,
			pq.Array(&item.SerialNumbers),
			&rawBatch,
			&lineNote,
			&productName,
			&sku,
		); err != nil {
			return nil, fmt.Errorf("failed to scan adjustment item: %w", err)
		}
		item.GoodsReceiptItemID = intPtrFromNullInt64(goodsReceiptItemID)
		item.PurchaseDetailID = intPtrFromNullInt64(purchaseDetailID)
		item.BarcodeID = intPtrFromNullInt64(barcodeID)
		if quantity.Valid {
			value := quantity.Float64
			item.Quantity = &value
		}
		if stockQuantity.Valid {
			value := stockQuantity.Float64
			item.StockQuantity = &value
		}
		item.BatchAllocations = decodeBatchAllocations(rawBatch)
		if lineNote.Valid {
			item.LineNote = &lineNote.String
		}
		item.Product = &models.Product{
			ProductID: item.ProductID,
			Name:      productName,
			SKU:       nullStringToStringPtr(sku),
		}
		adjustment.Items = append(adjustment.Items, item)
	}
	return &adjustment, nil
}
