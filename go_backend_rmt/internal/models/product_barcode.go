package models

// ProductBarcode represents barcode information for a product
// including optional pack size and pricing.
type ProductBarcode struct {
	BarcodeID    int      `json:"barcode_id,omitempty" db:"barcode_id"`
	ProductID    int      `json:"product_id" db:"product_id"`
	Barcode      string   `json:"barcode" db:"barcode" validate:"required"`
	PackSize     int      `json:"pack_size" db:"pack_size" validate:"gte=1"`
	CostPrice    *float64 `json:"cost_price,omitempty" db:"cost_price"`
	SellingPrice *float64 `json:"selling_price,omitempty" db:"selling_price"`
	IsPrimary    bool     `json:"is_primary" db:"is_primary"`
}
