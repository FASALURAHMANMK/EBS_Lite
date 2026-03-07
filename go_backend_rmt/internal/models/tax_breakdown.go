package models

// TaxBreakdownLine is a computed view of tax totals broken down into components
// (e.g., GST -> CGST/SGST) for printing and UI display.
type TaxBreakdownLine struct {
	TaxID         int     `json:"tax_id"`
	TaxName       string  `json:"tax_name"`
	ComponentName string  `json:"component_name"`
	Percentage    float64 `json:"percentage"`
	Amount        float64 `json:"amount"`
}
