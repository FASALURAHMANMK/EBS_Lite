package models

type ProductStorageAssignment struct {
	StorageAssignmentID int     `json:"storage_assignment_id" db:"storage_assignment_id"`
	ProductID           int     `json:"product_id" db:"product_id"`
	LocationID          int     `json:"location_id" db:"location_id"`
	BarcodeID           int     `json:"barcode_id" db:"barcode_id"`
	StorageType         string  `json:"storage_type" db:"storage_type"`
	StorageLabel        string  `json:"storage_label" db:"storage_label"`
	Notes               *string `json:"notes,omitempty" db:"notes"`
	IsPrimary           bool    `json:"is_primary" db:"is_primary"`
	SortOrder           int     `json:"sort_order" db:"sort_order"`
	LocationName        *string `json:"location_name,omitempty" db:"-"`
	Barcode             *string `json:"barcode,omitempty" db:"-"`
	VariantName         *string `json:"variant_name,omitempty" db:"-"`
}

type ReplaceProductStorageAssignmentsRequest struct {
	Assignments []ProductStorageAssignmentInput `json:"assignments"`
}

type ProductStorageAssignmentInput struct {
	StorageAssignmentID *int    `json:"storage_assignment_id,omitempty"`
	BarcodeID           *int    `json:"barcode_id,omitempty"`
	Barcode             *string `json:"barcode,omitempty"`
	StorageType         string  `json:"storage_type" validate:"required,min=2,max=50"`
	StorageLabel        string  `json:"storage_label" validate:"required,min=1,max=100"`
	Notes               *string `json:"notes,omitempty"`
	IsPrimary           bool    `json:"is_primary"`
	SortOrder           int     `json:"sort_order"`
}
