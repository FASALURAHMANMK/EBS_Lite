package models

import "time"

type AssetCategory struct {
	CategoryID      int        `json:"category_id" db:"category_id"`
	CompanyID       int        `json:"company_id" db:"company_id"`
	Name            string     `json:"name" db:"name"`
	Description     *string    `json:"description,omitempty" db:"description"`
	LedgerAccountID *int       `json:"ledger_account_id,omitempty" db:"ledger_account_id"`
	LedgerCode      *string    `json:"ledger_code,omitempty"`
	LedgerName      *string    `json:"ledger_name,omitempty"`
	IsActive        bool       `json:"is_active" db:"is_active"`
	CreatedBy       int        `json:"created_by" db:"created_by"`
	UpdatedBy       *int       `json:"updated_by,omitempty" db:"updated_by"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt       *time.Time `json:"updated_at,omitempty" db:"updated_at"`
}

type CreateAssetCategoryRequest struct {
	Name            string  `json:"name" validate:"required,min=2,max=255"`
	Description     *string `json:"description,omitempty"`
	LedgerAccountID *int    `json:"ledger_account_id,omitempty"`
}

type UpdateAssetCategoryRequest struct {
	Name            *string `json:"name,omitempty" validate:"omitempty,min=2,max=255"`
	Description     *string `json:"description,omitempty"`
	LedgerAccountID *int    `json:"ledger_account_id,omitempty"`
	IsActive        *bool   `json:"is_active,omitempty"`
}

type ConsumableCategory struct {
	CategoryID      int        `json:"category_id" db:"category_id"`
	CompanyID       int        `json:"company_id" db:"company_id"`
	Name            string     `json:"name" db:"name"`
	Description     *string    `json:"description,omitempty" db:"description"`
	LedgerAccountID *int       `json:"ledger_account_id,omitempty" db:"ledger_account_id"`
	LedgerCode      *string    `json:"ledger_code,omitempty"`
	LedgerName      *string    `json:"ledger_name,omitempty"`
	IsActive        bool       `json:"is_active" db:"is_active"`
	CreatedBy       int        `json:"created_by" db:"created_by"`
	UpdatedBy       *int       `json:"updated_by,omitempty" db:"updated_by"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt       *time.Time `json:"updated_at,omitempty" db:"updated_at"`
}

type CreateConsumableCategoryRequest struct {
	Name            string  `json:"name" validate:"required,min=2,max=255"`
	Description     *string `json:"description,omitempty"`
	LedgerAccountID *int    `json:"ledger_account_id,omitempty"`
}

type UpdateConsumableCategoryRequest struct {
	Name            *string `json:"name,omitempty" validate:"omitempty,min=2,max=255"`
	Description     *string `json:"description,omitempty"`
	LedgerAccountID *int    `json:"ledger_account_id,omitempty"`
	IsActive        *bool   `json:"is_active,omitempty"`
}

type AssetRegisterEntry struct {
	AssetEntryID      int                            `json:"asset_entry_id" db:"asset_entry_id"`
	CompanyID         int                            `json:"company_id" db:"company_id"`
	LocationID        int                            `json:"location_id" db:"location_id"`
	AssetTag          string                         `json:"asset_tag" db:"asset_tag"`
	ProductID         *int                           `json:"product_id,omitempty" db:"product_id"`
	BarcodeID         *int                           `json:"barcode_id,omitempty" db:"barcode_id"`
	CategoryID        *int                           `json:"category_id,omitempty" db:"category_id"`
	SupplierID        *int                           `json:"supplier_id,omitempty" db:"supplier_id"`
	ItemName          string                         `json:"item_name" db:"item_name"`
	SourceMode        string                         `json:"source_mode" db:"source_mode"`
	Quantity          float64                        `json:"quantity" db:"quantity"`
	UnitCost          float64                        `json:"unit_cost" db:"unit_cost"`
	TotalValue        float64                        `json:"total_value" db:"total_value"`
	AcquisitionDate   time.Time                      `json:"acquisition_date" db:"acquisition_date"`
	InServiceDate     *time.Time                     `json:"in_service_date,omitempty" db:"in_service_date"`
	Status            string                         `json:"status" db:"status"`
	OffsetAccountID   *int                           `json:"offset_account_id,omitempty" db:"offset_account_id"`
	OffsetAccountCode *string                        `json:"offset_account_code,omitempty"`
	OffsetAccountName *string                        `json:"offset_account_name,omitempty"`
	Notes             *string                        `json:"notes,omitempty" db:"notes"`
	SerialNumbers     []string                       `json:"serial_numbers,omitempty"`
	BatchAllocations  []InventoryBatchSelectionInput `json:"batch_allocations,omitempty"`
	CategoryName      *string                        `json:"category_name,omitempty"`
	ProductName       *string                        `json:"product_name,omitempty"`
	SupplierName      *string                        `json:"supplier_name,omitempty"`
	CreatedBy         int                            `json:"created_by" db:"created_by"`
	CreatedAt         time.Time                      `json:"created_at" db:"created_at"`
}

type AssetRegisterSummary struct {
	TotalItems      int     `json:"total_items"`
	ActiveItems     int     `json:"active_items"`
	TotalValue      float64 `json:"total_value"`
	AverageItemCost float64 `json:"average_item_cost"`
}

type CreateAssetRegisterEntryRequest struct {
	CategoryID       *int                           `json:"category_id,omitempty"`
	ProductID        *int                           `json:"product_id,omitempty"`
	BarcodeID        *int                           `json:"barcode_id,omitempty"`
	SupplierID       *int                           `json:"supplier_id,omitempty"`
	ItemName         *string                        `json:"item_name,omitempty"`
	AssetTag         *string                        `json:"asset_tag,omitempty"`
	SourceMode       string                         `json:"source_mode" validate:"required,oneof=STOCK DIRECT"`
	Quantity         float64                        `json:"quantity" validate:"required,gt=0"`
	UnitCost         *float64                       `json:"unit_cost,omitempty"`
	AcquisitionDate  string                         `json:"acquisition_date" validate:"required"`
	InServiceDate    *string                        `json:"in_service_date,omitempty"`
	Status           *string                        `json:"status,omitempty"`
	OffsetAccountID  *int                           `json:"offset_account_id,omitempty"`
	Notes            *string                        `json:"notes,omitempty"`
	SerialNumbers    []string                       `json:"serial_numbers,omitempty"`
	BatchAllocations []InventoryBatchSelectionInput `json:"batch_allocations,omitempty"`
}

type ConsumableEntry struct {
	ConsumptionID     int                            `json:"consumption_id" db:"consumption_id"`
	CompanyID         int                            `json:"company_id" db:"company_id"`
	LocationID        int                            `json:"location_id" db:"location_id"`
	EntryNumber       string                         `json:"entry_number" db:"entry_number"`
	CategoryID        *int                           `json:"category_id,omitempty" db:"category_id"`
	ProductID         *int                           `json:"product_id,omitempty" db:"product_id"`
	BarcodeID         *int                           `json:"barcode_id,omitempty" db:"barcode_id"`
	SupplierID        *int                           `json:"supplier_id,omitempty" db:"supplier_id"`
	ItemName          string                         `json:"item_name" db:"item_name"`
	SourceMode        string                         `json:"source_mode" db:"source_mode"`
	Quantity          float64                        `json:"quantity" db:"quantity"`
	UnitCost          float64                        `json:"unit_cost" db:"unit_cost"`
	TotalCost         float64                        `json:"total_cost" db:"total_cost"`
	ConsumedAt        time.Time                      `json:"consumed_at" db:"consumed_at"`
	OffsetAccountID   *int                           `json:"offset_account_id,omitempty" db:"offset_account_id"`
	OffsetAccountCode *string                        `json:"offset_account_code,omitempty"`
	OffsetAccountName *string                        `json:"offset_account_name,omitempty"`
	Notes             *string                        `json:"notes,omitempty" db:"notes"`
	SerialNumbers     []string                       `json:"serial_numbers,omitempty"`
	BatchAllocations  []InventoryBatchSelectionInput `json:"batch_allocations,omitempty"`
	CategoryName      *string                        `json:"category_name,omitempty"`
	ProductName       *string                        `json:"product_name,omitempty"`
	SupplierName      *string                        `json:"supplier_name,omitempty"`
	CreatedBy         int                            `json:"created_by" db:"created_by"`
	CreatedAt         time.Time                      `json:"created_at" db:"created_at"`
}

type ConsumableSummary struct {
	TotalEntries    int     `json:"total_entries"`
	TotalQuantity   float64 `json:"total_quantity"`
	TotalCost       float64 `json:"total_cost"`
	AverageUnitCost float64 `json:"average_unit_cost"`
}

type CreateConsumableEntryRequest struct {
	CategoryID       *int                           `json:"category_id,omitempty"`
	ProductID        *int                           `json:"product_id,omitempty"`
	BarcodeID        *int                           `json:"barcode_id,omitempty"`
	SupplierID       *int                           `json:"supplier_id,omitempty"`
	ItemName         *string                        `json:"item_name,omitempty"`
	SourceMode       string                         `json:"source_mode" validate:"required,oneof=STOCK DIRECT"`
	Quantity         float64                        `json:"quantity" validate:"required,gt=0"`
	UnitCost         *float64                       `json:"unit_cost,omitempty"`
	ConsumedAt       string                         `json:"consumed_at" validate:"required"`
	OffsetAccountID  *int                           `json:"offset_account_id,omitempty"`
	Notes            *string                        `json:"notes,omitempty"`
	SerialNumbers    []string                       `json:"serial_numbers,omitempty"`
	BatchAllocations []InventoryBatchSelectionInput `json:"batch_allocations,omitempty"`
}
