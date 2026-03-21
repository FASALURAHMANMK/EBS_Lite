package models

import (
	"time"
)

type Stock struct {
	StockID          int       `json:"stock_id" db:"stock_id"`
	LocationID       int       `json:"location_id" db:"location_id"`
	ProductID        int       `json:"product_id" db:"product_id"`
	Quantity         float64   `json:"quantity" db:"quantity"`
	ReservedQuantity float64   `json:"reserved_quantity" db:"reserved_quantity"`
	LastUpdated      time.Time `json:"last_updated" db:"last_updated"`
}

type StockWithProduct struct {
	Stock
	ProductName  string  `json:"product_name"`
	ProductSKU   *string `json:"product_sku,omitempty"`
	BarcodeID    *int    `json:"barcode_id,omitempty"`
	TrackingType string  `json:"tracking_type,omitempty"`
	IsSerialized bool    `json:"is_serialized"`
	CategoryID   *int    `json:"category_id,omitempty"`
	CategoryName *string `json:"category_name,omitempty"`
	BrandName    *string `json:"brand_name,omitempty"`
	UnitSymbol   *string `json:"unit_symbol,omitempty"`
	ReorderLevel int     `json:"reorder_level"`
	IsLowStock   bool    `json:"is_low_stock"`
}

type StockVariant struct {
	StockVariantID    int       `json:"stock_variant_id" db:"stock_variant_id"`
	LocationID        int       `json:"location_id" db:"location_id"`
	ProductID         int       `json:"product_id" db:"product_id"`
	BarcodeID         int       `json:"barcode_id" db:"barcode_id"`
	Barcode           *string   `json:"barcode,omitempty"`
	VariantName       *string   `json:"variant_name,omitempty"`
	VariantAttributes JSONB     `json:"variant_attributes,omitempty"`
	Quantity          float64   `json:"quantity" db:"quantity"`
	ReservedQuantity  float64   `json:"reserved_quantity" db:"reserved_quantity"`
	AverageCost       float64   `json:"average_cost" db:"average_cost"`
	SellingPrice      *float64  `json:"selling_price,omitempty"`
	TrackingType      string    `json:"tracking_type,omitempty"`
	IsSerialized      bool      `json:"is_serialized"`
	LastUpdated       time.Time `json:"last_updated" db:"last_updated"`
}

type StockLot struct {
	LotID             int        `json:"lot_id" db:"lot_id"`
	CompanyID         int        `json:"company_id" db:"company_id"`
	ProductID         int        `json:"product_id" db:"product_id"`
	BarcodeID         int        `json:"barcode_id" db:"barcode_id"`
	LocationID        int        `json:"location_id" db:"location_id"`
	BatchNumber       *string    `json:"batch_number,omitempty" db:"batch_number"`
	ExpiryDate        *time.Time `json:"expiry_date,omitempty" db:"expiry_date"`
	ReceivedDate      time.Time  `json:"received_date" db:"received_date"`
	Quantity          float64    `json:"quantity" db:"quantity"`
	RemainingQuantity float64    `json:"remaining_quantity" db:"remaining_quantity"`
	CostPrice         float64    `json:"cost_price" db:"cost_price"`
	Barcode           *string    `json:"barcode,omitempty"`
	VariantName       *string    `json:"variant_name,omitempty"`
	VariantAttributes JSONB      `json:"variant_attributes,omitempty"`
}

type ProductSerial struct {
	ProductSerialID int        `json:"product_serial_id" db:"product_serial_id"`
	CompanyID       int        `json:"company_id" db:"company_id"`
	ProductID       int        `json:"product_id" db:"product_id"`
	BarcodeID       int        `json:"barcode_id" db:"barcode_id"`
	StockLotID      *int       `json:"stock_lot_id,omitempty" db:"stock_lot_id"`
	SerialNumber    string     `json:"serial_number" db:"serial_number"`
	LocationID      *int       `json:"location_id,omitempty" db:"location_id"`
	Status          string     `json:"status" db:"status"`
	CostPrice       float64    `json:"cost_price" db:"cost_price"`
	ReceivedAt      time.Time  `json:"received_at" db:"received_at"`
	SoldAt          *time.Time `json:"sold_at,omitempty" db:"sold_at"`
	LastMovementAt  time.Time  `json:"last_movement_at" db:"last_movement_at"`
	Barcode         *string    `json:"barcode,omitempty"`
	VariantName     *string    `json:"variant_name,omitempty"`
	TrackingType    string     `json:"tracking_type,omitempty"`
	BatchNumber     *string    `json:"batch_number,omitempty"`
	ExpiryDate      *time.Time `json:"expiry_date,omitempty"`
}

type InventoryMovement struct {
	MovementID      int       `json:"movement_id" db:"movement_id"`
	CompanyID       int       `json:"company_id" db:"company_id"`
	LocationID      int       `json:"location_id" db:"location_id"`
	ProductID       int       `json:"product_id" db:"product_id"`
	BarcodeID       int       `json:"barcode_id" db:"barcode_id"`
	StockLotID      *int      `json:"stock_lot_id,omitempty" db:"stock_lot_id"`
	ProductSerialID *int      `json:"product_serial_id,omitempty" db:"product_serial_id"`
	MovementType    string    `json:"movement_type" db:"movement_type"`
	SourceType      string    `json:"source_type" db:"source_type"`
	SourceLineID    *int      `json:"source_line_id,omitempty" db:"source_line_id"`
	SourceRef       *string   `json:"source_ref,omitempty" db:"source_ref"`
	Quantity        float64   `json:"quantity" db:"quantity"`
	UnitCost        float64   `json:"unit_cost" db:"unit_cost"`
	TotalCost       float64   `json:"total_cost" db:"total_cost"`
	Notes           *string   `json:"notes,omitempty" db:"notes"`
	CreatedBy       *int      `json:"created_by,omitempty" db:"created_by"`
	OccurredAt      time.Time `json:"occurred_at" db:"occurred_at"`
	Barcode         *string   `json:"barcode,omitempty"`
	VariantName     *string   `json:"variant_name,omitempty"`
	BatchNumber     *string   `json:"batch_number,omitempty"`
	SerialNumber    *string   `json:"serial_number,omitempty"`
}

type StockAdjustment struct {
	AdjustmentID int       `json:"adjustment_id" db:"adjustment_id"`
	LocationID   int       `json:"location_id" db:"location_id"`
	ProductID    int       `json:"product_id" db:"product_id"`
	BarcodeID    *int      `json:"barcode_id,omitempty" db:"barcode_id"`
	Adjustment   float64   `json:"adjustment" db:"adjustment"`
	Reason       string    `json:"reason" db:"reason"`
	CreatedBy    int       `json:"created_by" db:"created_by"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

type CreateStockAdjustmentRequest struct {
	ProductID        int                            `json:"product_id" validate:"required"`
	BarcodeID        *int                           `json:"barcode_id,omitempty"`
	Adjustment       float64                        `json:"adjustment" validate:"required"`
	Reason           string                         `json:"reason" validate:"required,min=2,max=255"`
	BatchNumber      *string                        `json:"batch_number,omitempty"`
	ExpiryDate       *time.Time                     `json:"expiry_date,omitempty"`
	BatchAllocations []InventoryBatchSelectionInput `json:"batch_allocations,omitempty"`
	SerialNumbers    []string                       `json:"serial_numbers,omitempty"`
	OverridePassword *string                        `json:"override_password,omitempty"`
}

// Stock adjustment document (header)
type StockAdjustmentDocument struct {
	DocumentID     int                           `json:"document_id" db:"document_id"`
	DocumentNumber string                        `json:"document_number" db:"document_number"`
	LocationID     int                           `json:"location_id" db:"location_id"`
	Reason         string                        `json:"reason" db:"reason"`
	CreatedBy      int                           `json:"created_by" db:"created_by"`
	CreatedAt      time.Time                     `json:"created_at" db:"created_at"`
	Items          []StockAdjustmentDocumentItem `json:"items,omitempty"`
}

// Stock adjustment document detail (line)
type StockAdjustmentDocumentItem struct {
	ItemID           int                            `json:"item_id" db:"item_id"`
	DocumentID       int                            `json:"document_id" db:"document_id"`
	ProductID        int                            `json:"product_id" db:"product_id"`
	BarcodeID        *int                           `json:"barcode_id,omitempty" db:"barcode_id"`
	Adjustment       float64                        `json:"adjustment" db:"adjustment"`
	BatchAllocations []InventoryBatchSelectionInput `json:"batch_allocations,omitempty" db:"-"`
	SerialNumbers    []string                       `json:"serial_numbers,omitempty" db:"-"`
}

// Create document request payload
type CreateStockAdjustmentDocumentRequest struct {
	Reason           string                                     `json:"reason" validate:"required,min=2,max=255"`
	Items            []CreateStockAdjustmentDocumentItemRequest `json:"items" validate:"required,min=1"`
	OverridePassword *string                                    `json:"override_password,omitempty"`
}

type CreateStockAdjustmentDocumentItemRequest struct {
	ProductID        int                            `json:"product_id" validate:"required"`
	BarcodeID        *int                           `json:"barcode_id,omitempty"`
	Adjustment       float64                        `json:"adjustment" validate:"required"`
	BatchNumber      *string                        `json:"batch_number,omitempty"`
	ExpiryDate       *time.Time                     `json:"expiry_date,omitempty"`
	BatchAllocations []InventoryBatchSelectionInput `json:"batch_allocations,omitempty"`
	SerialNumbers    []string                       `json:"serial_numbers,omitempty"`
}

type StockTransfer struct {
	TransferID     int                   `json:"transfer_id" db:"transfer_id"`
	TransferNumber string                `json:"transfer_number" db:"transfer_number"`
	FromLocationID int                   `json:"from_location_id" db:"from_location_id"`
	ToLocationID   int                   `json:"to_location_id" db:"to_location_id"`
	TransferDate   time.Time             `json:"transfer_date" db:"transfer_date"`
	Status         string                `json:"status" db:"status"`
	Notes          *string               `json:"notes,omitempty" db:"notes"`
	CreatedBy      int                   `json:"created_by" db:"created_by"`
	ApprovedBy     *int                  `json:"approved_by,omitempty" db:"approved_by"`
	ApprovedAt     *time.Time            `json:"approved_at,omitempty" db:"approved_at"`
	Items          []StockTransferDetail `json:"items,omitempty"`
	SyncModel
}

type StockTransferDetail struct {
	TransferDetailID int                            `json:"transfer_detail_id" db:"transfer_detail_id"`
	TransferID       int                            `json:"transfer_id" db:"transfer_id"`
	ProductID        int                            `json:"product_id" db:"product_id"`
	BarcodeID        *int                           `json:"barcode_id,omitempty" db:"barcode_id"`
	Quantity         float64                        `json:"quantity" db:"quantity"`
	ReceivedQuantity float64                        `json:"received_quantity" db:"received_quantity"`
	BatchAllocations []InventoryBatchSelectionInput `json:"batch_allocations,omitempty" db:"-"`
	SerialNumbers    []string                       `json:"serial_numbers,omitempty" db:"-"`
}

type CreateStockTransferRequest struct {
	ToLocationID int                                `json:"to_location_id" validate:"required"`
	Notes        *string                            `json:"notes,omitempty"`
	Items        []CreateStockTransferDetailRequest `json:"items" validate:"required,min=1"`
}

type ApproveStockTransferRequest struct {
	OverridePassword *string `json:"override_password,omitempty"`
}

type CreateStockTransferDetailRequest struct {
	ProductID        int                            `json:"product_id" validate:"required"`
	BarcodeID        *int                           `json:"barcode_id,omitempty"`
	Quantity         float64                        `json:"quantity" validate:"required,gt=0"`
	BatchAllocations []InventoryBatchSelectionInput `json:"batch_allocations,omitempty"`
	SerialNumbers    []string                       `json:"serial_numbers,omitempty"`
}

// StockTransferFilters for enhanced filtering
type StockTransferFilters struct {
	CompanyID             int    `json:"company_id"`
	LocationID            int    `json:"location_id"`
	SourceLocationID      int    `json:"source_location_id"`
	DestinationLocationID int    `json:"destination_location_id"`
	Status                string `json:"status"`
}

// StockTransferWithItems includes transfer details with item summary
type StockTransferWithItems struct {
	TransferID       int                        `json:"transfer_id" db:"transfer_id"`
	TransferNumber   string                     `json:"transfer_number" db:"transfer_number"`
	FromLocationID   int                        `json:"from_location_id" db:"from_location_id"`
	ToLocationID     int                        `json:"to_location_id" db:"to_location_id"`
	FromLocationName string                     `json:"from_location_name"`
	ToLocationName   string                     `json:"to_location_name"`
	TransferDate     time.Time                  `json:"transfer_date" db:"transfer_date"`
	Status           string                     `json:"status" db:"status"`
	Notes            *string                    `json:"notes,omitempty" db:"notes"`
	CreatedBy        int                        `json:"created_by" db:"created_by"`
	ApprovedBy       *int                       `json:"approved_by,omitempty" db:"approved_by"`
	ApprovedAt       *time.Time                 `json:"approved_at,omitempty" db:"approved_at"`
	Items            []StockTransferItemSummary `json:"items"`
	SyncModel
}

// StockTransferWithDetails includes full transfer details with complete item information
type StockTransferWithDetails struct {
	TransferID       int                              `json:"transfer_id" db:"transfer_id"`
	TransferNumber   string                           `json:"transfer_number" db:"transfer_number"`
	FromLocationID   int                              `json:"from_location_id" db:"from_location_id"`
	ToLocationID     int                              `json:"to_location_id" db:"to_location_id"`
	FromLocationName string                           `json:"from_location_name"`
	ToLocationName   string                           `json:"to_location_name"`
	TransferDate     time.Time                        `json:"transfer_date" db:"transfer_date"`
	Status           string                           `json:"status" db:"status"`
	Notes            *string                          `json:"notes,omitempty" db:"notes"`
	CreatedBy        int                              `json:"created_by" db:"created_by"`
	CreatedByName    string                           `json:"created_by_name"`
	ApprovedBy       *int                             `json:"approved_by,omitempty" db:"approved_by"`
	ApprovedAt       *time.Time                       `json:"approved_at,omitempty" db:"approved_at"`
	ApprovedByName   *string                          `json:"approved_by_name,omitempty"`
	Items            []StockTransferDetailWithProduct `json:"items"`
	TotalItems       int                              `json:"total_items"`
	TotalQuantity    float64                          `json:"total_quantity"`
	SyncModel
}

// StockTransferItemSummary for basic item info in transfer lists
type StockTransferItemSummary struct {
	ProductID   int     `json:"product_id" db:"product_id"`
	ProductName string  `json:"product_name"`
	Quantity    float64 `json:"quantity" db:"quantity"`
}

// StockTransferDetailWithProduct includes product information
type StockTransferDetailWithProduct struct {
	TransferDetailID int                            `json:"transfer_detail_id" db:"transfer_detail_id"`
	TransferID       int                            `json:"transfer_id" db:"transfer_id"`
	ProductID        int                            `json:"product_id" db:"product_id"`
	BarcodeID        *int                           `json:"barcode_id,omitempty" db:"barcode_id"`
	ProductName      string                         `json:"product_name"`
	ProductSKU       *string                        `json:"product_sku,omitempty"`
	UnitSymbol       *string                        `json:"unit_symbol,omitempty"`
	Barcode          *string                        `json:"barcode,omitempty"`
	VariantName      *string                        `json:"variant_name,omitempty"`
	TrackingType     string                         `json:"tracking_type,omitempty"`
	Quantity         float64                        `json:"quantity" db:"quantity"`
	ReceivedQuantity float64                        `json:"received_quantity" db:"received_quantity"`
	BatchAllocations []InventoryBatchSelectionInput `json:"batch_allocations,omitempty" db:"-"`
	SerialNumbers    []string                       `json:"serial_numbers,omitempty" db:"-"`
}

type InventoryBatchSelectionInput struct {
	LotID    int     `json:"lot_id" validate:"required"`
	Quantity float64 `json:"quantity" validate:"required,gt=0"`
}

// StockLocationSummary aggregates stock quantity per location
type StockLocationSummary struct {
	LocationID    int     `json:"location_id"`
	LocationName  string  `json:"location_name"`
	TotalQuantity float64 `json:"total_quantity"`
}

// InventorySummary provides overall stock information and recent activity
type InventorySummary struct {
	StockByLocation    []StockLocationSummary `json:"stock_by_location"`
	MovementHistory    []StockAdjustment      `json:"movement_history"`
	RecentTransactions []StockTransfer        `json:"recent_transactions"`
}

// ProductSummary provides stock and movement details for a single product
type ProductSummary struct {
	ProductID       int                              `json:"product_id"`
	StockByLocation []Stock                          `json:"stock_by_location"`
	MovementHistory []StockAdjustment                `json:"movement_history"`
	RecentTransfers []StockTransferDetailWithProduct `json:"recent_transfers"`
}

// BarcodeRequest defines the payload for generating inventory labels
type BarcodeRequest struct {
	ProductIDs []int `json:"product_ids" validate:"required,min=1"`
}

// ProductTransaction represents any stock-affecting transaction for a product
type ProductTransaction struct {
	Type         string    `json:"type"`
	OccurredAt   time.Time `json:"occurred_at"`
	Reference    string    `json:"reference"`
	Quantity     float64   `json:"quantity"`
	LocationID   int       `json:"location_id"`
	LocationName string    `json:"location_name,omitempty"`
	PartnerName  *string   `json:"partner_name,omitempty"`
	Entity       string    `json:"entity"`
	EntityID     int       `json:"entity_id"`
	Amount       *float64  `json:"amount,omitempty"`
	Notes        *string   `json:"notes,omitempty"`
}
