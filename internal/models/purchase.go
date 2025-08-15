package models

import (
	"time"
)

type Purchase struct {
	PurchaseID      int              `json:"purchase_id" db:"purchase_id"`
	PurchaseNumber  string           `json:"purchase_number" db:"purchase_number"`
	LocationID      int              `json:"location_id" db:"location_id"`
	SupplierID      int              `json:"supplier_id" db:"supplier_id"`
	PurchaseOrderID *int             `json:"purchase_order_id,omitempty" db:"purchase_order_id"`
	WorkflowStateID *int             `json:"workflow_state_id,omitempty" db:"workflow_state_id"`
	PurchaseDate    time.Time        `json:"purchase_date" db:"purchase_date"`
	Subtotal        float64          `json:"subtotal" db:"subtotal"`
	TaxAmount       float64          `json:"tax_amount" db:"tax_amount"`
	DiscountAmount  float64          `json:"discount_amount" db:"discount_amount"`
	TotalAmount     float64          `json:"total_amount" db:"total_amount"`
	PaidAmount      float64          `json:"paid_amount" db:"paid_amount"`
	PaymentTerms    int              `json:"payment_terms" db:"payment_terms"`
	DueDate         *time.Time       `json:"due_date,omitempty" db:"due_date"`
	Status          string           `json:"status" db:"status"`
	ReferenceNumber *string          `json:"reference_number,omitempty" db:"reference_number"`
	Notes           *string          `json:"notes,omitempty" db:"notes"`
	CreatedBy       int              `json:"created_by" db:"created_by"`
	UpdatedBy       *int             `json:"updated_by,omitempty" db:"updated_by"`
	Items           []PurchaseDetail `json:"items,omitempty"`
	GoodsReceipts   []GoodsReceipt   `json:"goods_receipts,omitempty"`
	Supplier        *Supplier        `json:"supplier,omitempty"`
	Location        *Location        `json:"location,omitempty"`
	SyncModel
}

type PurchaseDetail struct {
	PurchaseDetailID   int        `json:"purchase_detail_id" db:"purchase_detail_id"`
	PurchaseID         int        `json:"purchase_id" db:"purchase_id"`
	ProductID          int        `json:"product_id" db:"product_id"`
	Quantity           float64    `json:"quantity" db:"quantity"`
	UnitPrice          float64    `json:"unit_price" db:"unit_price"`
	DiscountPercentage float64    `json:"discount_percentage" db:"discount_percentage"`
	DiscountAmount     float64    `json:"discount_amount" db:"discount_amount"`
	TaxID              *int       `json:"tax_id,omitempty" db:"tax_id"`
	TaxAmount          float64    `json:"tax_amount" db:"tax_amount"`
	LineTotal          float64    `json:"line_total" db:"line_total"`
	ReceivedQuantity   float64    `json:"received_quantity" db:"received_quantity"`
	SerialNumbers      []string   `json:"serial_numbers,omitempty" db:"serial_numbers"`
	ExpiryDate         *time.Time `json:"expiry_date,omitempty" db:"expiry_date"`
	BatchNumber        *string    `json:"batch_number,omitempty" db:"batch_number"`
	Product            *Product   `json:"product,omitempty"`
}

type PurchaseWithDetails struct {
	Purchase
	Items []PurchaseDetail `json:"items"`
}

// Purchase Return Models
type PurchaseReturn struct {
	ReturnID     int                    `json:"return_id" db:"return_id"`
	ReturnNumber string                 `json:"return_number" db:"return_number"`
	PurchaseID   int                    `json:"purchase_id" db:"purchase_id"`
	LocationID   int                    `json:"location_id" db:"location_id"`
	SupplierID   int                    `json:"supplier_id" db:"supplier_id"`
	ReturnDate   time.Time              `json:"return_date" db:"return_date"`
	TotalAmount  float64                `json:"total_amount" db:"total_amount"`
	Reason       *string                `json:"reason,omitempty" db:"reason"`
	Status       string                 `json:"status" db:"status"`
	CreatedBy    int                    `json:"created_by" db:"created_by"`
	Items        []PurchaseReturnDetail `json:"items,omitempty"`
	Purchase     *Purchase              `json:"purchase,omitempty"`
	Supplier     *Supplier              `json:"supplier,omitempty"`
	SyncModel
}

type PurchaseReturnDetail struct {
	ReturnDetailID   int      `json:"return_detail_id" db:"return_detail_id"`
	ReturnID         int      `json:"return_id" db:"return_id"`
	PurchaseDetailID *int     `json:"purchase_detail_id,omitempty" db:"purchase_detail_id"`
	ProductID        int      `json:"product_id" db:"product_id"`
	Quantity         float64  `json:"quantity" db:"quantity"`
	UnitPrice        float64  `json:"unit_price" db:"unit_price"`
	LineTotal        float64  `json:"line_total" db:"line_total"`
	Product          *Product `json:"product,omitempty"`
}

// Request Models
type CreatePurchaseRequest struct {
	SupplierID      int                           `json:"supplier_id" validate:"required"`
	LocationID      *int                          `json:"location_id,omitempty"`
	PurchaseDate    *time.Time                    `json:"purchase_date,omitempty"`
	ReferenceNumber *string                       `json:"reference_number,omitempty"`
	PaymentTerms    *int                          `json:"payment_terms,omitempty"`
	Notes           *string                       `json:"notes,omitempty"`
	Items           []CreatePurchaseDetailRequest `json:"items" validate:"required,min=1"`
}

type CreatePurchaseDetailRequest struct {
	ProductID          int        `json:"product_id" validate:"required"`
	Quantity           float64    `json:"quantity" validate:"required,gt=0"`
	UnitPrice          float64    `json:"unit_price" validate:"required,gte=0"`
	DiscountPercentage *float64   `json:"discount_percentage,omitempty" validate:"omitempty,gte=0,lte=100"`
	DiscountAmount     *float64   `json:"discount_amount,omitempty" validate:"omitempty,gte=0"`
	TaxID              *int       `json:"tax_id,omitempty"`
	SerialNumbers      []string   `json:"serial_numbers,omitempty"`
	ExpiryDate         *time.Time `json:"expiry_date,omitempty"`
	BatchNumber        *string    `json:"batch_number,omitempty"`
}

type UpdatePurchaseRequest struct {
	ReferenceNumber *string                       `json:"reference_number,omitempty"`
	PaymentTerms    *int                          `json:"payment_terms,omitempty"`
	Notes           *string                       `json:"notes,omitempty"`
	Status          *string                       `json:"status,omitempty" validate:"omitempty,oneof=PENDING RECEIVED CANCELLED"`
	Items           []CreatePurchaseDetailRequest `json:"items,omitempty"`
}

type CreatePurchaseReturnRequest struct {
	PurchaseID int                                 `json:"purchase_id" validate:"required"`
	Reason     *string                             `json:"reason,omitempty"`
	Items      []CreatePurchaseReturnDetailRequest `json:"items" validate:"required,min=1"`
}

type CreatePurchaseReturnDetailRequest struct {
	PurchaseDetailID *int    `json:"purchase_detail_id,omitempty"`
	ProductID        int     `json:"product_id" validate:"required"`
	Quantity         float64 `json:"quantity" validate:"required,gt=0"`
	UnitPrice        float64 `json:"unit_price" validate:"required,gte=0"`
}

// Purchase Receiving Models
type ReceivePurchaseRequest struct {
	Items []ReceivePurchaseItemRequest `json:"items" validate:"required,min=1"`
}

type ReceivePurchaseItemRequest struct {
	PurchaseDetailID int        `json:"purchase_detail_id" validate:"required"`
	ReceivedQuantity float64    `json:"received_quantity" validate:"required,gt=0"`
	ExpiryDate       *time.Time `json:"expiry_date,omitempty"`
	BatchNumber      *string    `json:"batch_number,omitempty"`
	SerialNumbers    []string   `json:"serial_numbers,omitempty"`
}

// Purchase Order Models
type PurchaseOrder struct {
	PurchaseOrderID int                 `json:"purchase_order_id" db:"purchase_order_id"`
	OrderNumber     string              `json:"order_number" db:"order_number"`
	LocationID      int                 `json:"location_id" db:"location_id"`
	SupplierID      int                 `json:"supplier_id" db:"supplier_id"`
	OrderDate       time.Time           `json:"order_date" db:"order_date"`
	Status          string              `json:"status" db:"status"`
	TotalAmount     float64             `json:"total_amount" db:"total_amount"`
	CreatedBy       int                 `json:"created_by" db:"created_by"`
	WorkflowStateID *int                `json:"workflow_state_id,omitempty" db:"workflow_state_id"`
	Items           []PurchaseOrderItem `json:"items,omitempty"`
	Supplier        *Supplier           `json:"supplier,omitempty"`
	Location        *Location           `json:"location,omitempty"`
	SyncModel
}

type PurchaseOrderItem struct {
	PurchaseOrderItemID int      `json:"purchase_order_item_id" db:"purchase_order_item_id"`
	PurchaseOrderID     int      `json:"purchase_order_id" db:"purchase_order_id"`
	ProductID           int      `json:"product_id" db:"product_id"`
	Quantity            float64  `json:"quantity" db:"quantity"`
	UnitPrice           float64  `json:"unit_price" db:"unit_price"`
	LineTotal           float64  `json:"line_total" db:"line_total"`
	Product             *Product `json:"product,omitempty"`
}

// Goods Receipt Models
type GoodsReceipt struct {
	GoodsReceiptID  int                `json:"goods_receipt_id" db:"goods_receipt_id"`
	ReceiptNumber   string             `json:"receipt_number" db:"receipt_number"`
	PurchaseOrderID *int               `json:"purchase_order_id,omitempty" db:"purchase_order_id"`
	PurchaseID      *int               `json:"purchase_id,omitempty" db:"purchase_id"`
	LocationID      int                `json:"location_id" db:"location_id"`
	SupplierID      int                `json:"supplier_id" db:"supplier_id"`
	ReceivedDate    time.Time          `json:"received_date" db:"received_date"`
	ReceivedBy      int                `json:"received_by" db:"received_by"`
	WorkflowStateID *int               `json:"workflow_state_id,omitempty" db:"workflow_state_id"`
	Items           []GoodsReceiptItem `json:"items,omitempty"`
	Supplier        *Supplier          `json:"supplier,omitempty"`
	Location        *Location          `json:"location,omitempty"`
}

type GoodsReceiptItem struct {
	GoodsReceiptItemID  int      `json:"goods_receipt_item_id" db:"goods_receipt_item_id"`
	GoodsReceiptID      int      `json:"goods_receipt_id" db:"goods_receipt_id"`
	PurchaseOrderItemID *int     `json:"purchase_order_item_id,omitempty" db:"purchase_order_item_id"`
	ProductID           int      `json:"product_id" db:"product_id"`
	ReceivedQuantity    float64  `json:"received_quantity" db:"received_quantity"`
	UnitPrice           float64  `json:"unit_price" db:"unit_price"`
	LineTotal           float64  `json:"line_total" db:"line_total"`
	Product             *Product `json:"product,omitempty"`
	ReceiptItemID       int      `json:"receipt_item_id" db:"receipt_item_id"`
	ReceiptID           int      `json:"receipt_id" db:"receipt_id"`
	PurchaseDetailID    int      `json:"purchase_detail_id" db:"purchase_detail_id"`
}

type RecordGoodsReceiptRequest struct {
	PurchaseID    int                          `json:"purchase_id" validate:"required"`
	ReceiptNumber *string                      `json:"receipt_number,omitempty"`
	ReceiptDate   *time.Time                   `json:"receipt_date,omitempty"`
	Notes         *string                      `json:"notes,omitempty"`
	Items         []ReceivePurchaseItemRequest `json:"items" validate:"required,min=1"`
}
