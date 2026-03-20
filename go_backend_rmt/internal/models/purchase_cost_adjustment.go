package models

import "time"

const (
	PurchaseCostAdjustmentTypeGRNAddon          = "GRN_ADDON"
	PurchaseCostAdjustmentTypeSupplierDebitNote = "SUPPLIER_DEBIT_NOTE"

	PurchaseCostAdjustmentScopeHeader = "HEADER"
	PurchaseCostAdjustmentScopeItem   = "ITEM"

	PurchaseCostAdjustmentStockActionCostOnly    = "COST_ONLY"
	PurchaseCostAdjustmentStockActionReduceStock = "REDUCE_STOCK"

	PurchaseCostAdjustmentDirectionExpense = "EXPENSE"
	PurchaseCostAdjustmentDirectionIncome  = "INCOME"
)

type PurchaseCostAdjustment struct {
	AdjustmentID     int                          `json:"adjustment_id" db:"adjustment_id"`
	AdjustmentNumber string                       `json:"adjustment_number" db:"adjustment_number"`
	AdjustmentType   string                       `json:"adjustment_type" db:"adjustment_type"`
	GoodsReceiptID   *int                         `json:"goods_receipt_id,omitempty" db:"goods_receipt_id"`
	PurchaseID       *int                         `json:"purchase_id,omitempty" db:"purchase_id"`
	LocationID       int                          `json:"location_id" db:"location_id"`
	SupplierID       int                          `json:"supplier_id" db:"supplier_id"`
	AdjustmentDate   time.Time                    `json:"adjustment_date" db:"adjustment_date"`
	ReferenceNumber  *string                      `json:"reference_number,omitempty" db:"reference_number"`
	Notes            *string                      `json:"notes,omitempty" db:"notes"`
	TotalAmount      float64                      `json:"total_amount" db:"total_amount"`
	CreatedBy        int                          `json:"created_by" db:"created_by"`
	UpdatedBy        *int                         `json:"updated_by,omitempty" db:"updated_by"`
	Items            []PurchaseCostAdjustmentItem `json:"items,omitempty"`
	Supplier         *Supplier                    `json:"supplier,omitempty"`
	SyncModel
}

type PurchaseCostAdjustmentItem struct {
	AdjustmentItemID   int                            `json:"adjustment_item_id" db:"adjustment_item_id"`
	AdjustmentID       int                            `json:"adjustment_id" db:"adjustment_id"`
	SourceScope        string                         `json:"source_scope" db:"source_scope"`
	GoodsReceiptItemID *int                           `json:"goods_receipt_item_id,omitempty" db:"goods_receipt_item_id"`
	PurchaseDetailID   *int                           `json:"purchase_detail_id,omitempty" db:"purchase_detail_id"`
	ProductID          int                            `json:"product_id" db:"product_id"`
	BarcodeID          *int                           `json:"barcode_id,omitempty" db:"barcode_id"`
	AdjustmentLabel    string                         `json:"adjustment_label" db:"adjustment_label"`
	StockAction        string                         `json:"stock_action" db:"stock_action"`
	SignedAmount       float64                        `json:"signed_amount" db:"signed_amount"`
	Quantity           *float64                       `json:"quantity,omitempty" db:"quantity"`
	StockQuantity      *float64                       `json:"stock_quantity,omitempty" db:"stock_quantity"`
	SerialNumbers      []string                       `json:"serial_numbers,omitempty" db:"-"`
	BatchAllocations   []InventoryBatchSelectionInput `json:"batch_allocations,omitempty" db:"-"`
	LineNote           *string                        `json:"line_note,omitempty" db:"line_note"`
	Product            *Product                       `json:"product,omitempty"`
}

type CreateCostAdjustmentComponentRequest struct {
	Label     string  `json:"label" validate:"required,min=2,max=255"`
	Amount    float64 `json:"amount" validate:"required,gt=0"`
	Direction string  `json:"direction" validate:"required,oneof=EXPENSE INCOME"`
}

type CreateGoodsReceiptItemAdjustmentRequest struct {
	PurchaseDetailID int     `json:"purchase_detail_id" validate:"required"`
	Label            string  `json:"label" validate:"required,min=2,max=255"`
	Amount           float64 `json:"amount" validate:"required,gt=0"`
	Direction        string  `json:"direction" validate:"required,oneof=EXPENSE INCOME"`
}

type CreateGoodsReceiptAddonRequest struct {
	ReferenceNumber   *string                                   `json:"reference_number,omitempty"`
	Notes             *string                                   `json:"notes,omitempty"`
	HeaderAdjustments []CreateCostAdjustmentComponentRequest    `json:"header_adjustments,omitempty"`
	ItemAdjustments   []CreateGoodsReceiptItemAdjustmentRequest `json:"item_adjustments,omitempty"`
}

type CreateSupplierDebitNoteRequest struct {
	SupplierID      int                                  `json:"supplier_id" validate:"required"`
	PurchaseID      int                                  `json:"purchase_id" validate:"required"`
	ReferenceNumber *string                              `json:"reference_number,omitempty"`
	Notes           *string                              `json:"notes,omitempty"`
	Items           []CreateSupplierDebitNoteItemRequest `json:"items" validate:"required,min=1"`
}

type CreateSupplierDebitNoteItemRequest struct {
	PurchaseDetailID *int                           `json:"purchase_detail_id,omitempty"`
	ProductID        int                            `json:"product_id" validate:"required"`
	BarcodeID        *int                           `json:"barcode_id,omitempty"`
	Label            string                         `json:"label" validate:"required,min=2,max=255"`
	StockAction      string                         `json:"stock_action" validate:"required,oneof=COST_ONLY REDUCE_STOCK"`
	Amount           *float64                       `json:"amount,omitempty" validate:"omitempty,gt=0"`
	Quantity         *float64                       `json:"quantity,omitempty" validate:"omitempty,gt=0"`
	SerialNumbers    []string                       `json:"serial_numbers,omitempty"`
	BatchAllocations []InventoryBatchSelectionInput `json:"batch_allocations,omitempty"`
	LineNote         *string                        `json:"line_note,omitempty"`
}
