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
    CategoryID   *int    `json:"category_id,omitempty"`
    CategoryName *string `json:"category_name,omitempty"`
    BrandName    *string `json:"brand_name,omitempty"`
    UnitSymbol   *string `json:"unit_symbol,omitempty"`
    ReorderLevel int     `json:"reorder_level"`
    IsLowStock   bool    `json:"is_low_stock"`
}

type StockAdjustment struct {
	AdjustmentID int       `json:"adjustment_id" db:"adjustment_id"`
	LocationID   int       `json:"location_id" db:"location_id"`
	ProductID    int       `json:"product_id" db:"product_id"`
	Adjustment   float64   `json:"adjustment" db:"adjustment"`
	Reason       string    `json:"reason" db:"reason"`
	CreatedBy    int       `json:"created_by" db:"created_by"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

type CreateStockAdjustmentRequest struct {
    ProductID  int     `json:"product_id" validate:"required"`
    Adjustment float64 `json:"adjustment" validate:"required"`
    Reason     string  `json:"reason" validate:"required,min=2,max=255"`
}

// Stock adjustment document (header)
type StockAdjustmentDocument struct {
    DocumentID     int       `json:"document_id" db:"document_id"`
    DocumentNumber string    `json:"document_number" db:"document_number"`
    LocationID     int       `json:"location_id" db:"location_id"`
    Reason         string    `json:"reason" db:"reason"`
    CreatedBy      int       `json:"created_by" db:"created_by"`
    CreatedAt      time.Time `json:"created_at" db:"created_at"`
    Items          []StockAdjustmentDocumentItem `json:"items,omitempty"`
}

// Stock adjustment document detail (line)
type StockAdjustmentDocumentItem struct {
    ItemID     int     `json:"item_id" db:"item_id"`
    DocumentID int     `json:"document_id" db:"document_id"`
    ProductID  int     `json:"product_id" db:"product_id"`
    Adjustment float64 `json:"adjustment" db:"adjustment"`
}

// Create document request payload
type CreateStockAdjustmentDocumentRequest struct {
    Reason string                                      `json:"reason" validate:"required,min=2,max=255"`
    Items  []CreateStockAdjustmentDocumentItemRequest `json:"items" validate:"required,min=1"`
}

type CreateStockAdjustmentDocumentItemRequest struct {
    ProductID  int     `json:"product_id" validate:"required"`
    Adjustment float64 `json:"adjustment" validate:"required"`
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
	TransferDetailID int     `json:"transfer_detail_id" db:"transfer_detail_id"`
	TransferID       int     `json:"transfer_id" db:"transfer_id"`
	ProductID        int     `json:"product_id" db:"product_id"`
	Quantity         float64 `json:"quantity" db:"quantity"`
	ReceivedQuantity float64 `json:"received_quantity" db:"received_quantity"`
}

type CreateStockTransferRequest struct {
	ToLocationID int                                `json:"to_location_id" validate:"required"`
	Notes        *string                            `json:"notes,omitempty"`
	Items        []CreateStockTransferDetailRequest `json:"items" validate:"required,min=1"`
}

type CreateStockTransferDetailRequest struct {
	ProductID int     `json:"product_id" validate:"required"`
	Quantity  float64 `json:"quantity" validate:"required,gt=0"`
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
	TransferDetailID int     `json:"transfer_detail_id" db:"transfer_detail_id"`
	TransferID       int     `json:"transfer_id" db:"transfer_id"`
	ProductID        int     `json:"product_id" db:"product_id"`
	ProductName      string  `json:"product_name"`
	ProductSKU       *string `json:"product_sku,omitempty"`
	UnitSymbol       *string `json:"unit_symbol,omitempty"`
	Quantity         float64 `json:"quantity" db:"quantity"`
	ReceivedQuantity float64 `json:"received_quantity" db:"received_quantity"`
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
