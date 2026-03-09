package services

import (
	"bytes"
	"fmt"

	"github.com/xuri/excelize/v2"
)

func (s *InventoryService) InventoryImportTemplateXLSX(companyID int) ([]byte, error) {
	f := excelize.NewFile()
	sheet := "Inventory"
	f.SetSheetName("Sheet1", sheet)

	for i, h := range inventoryImportHeaders {
		cellName, _ := excelize.CoordinatesToCellName(i+1, 1)
		f.SetCellValue(sheet, cellName, h)
	}
	_ = f.SetPanes(sheet, &excelize.Panes{Freeze: true, Split: true, YSplit: 1, TopLeftCell: "A2", ActivePane: "bottomLeft"})
	_ = f.AutoFilter(sheet, "A1:T1", nil)

	lookups := "Lookups"
	f.NewSheet(lookups)
	f.SetCellValue(lookups, "A1", "Valid values (use ID or Name)")

	writeLookup := func(title string, startRow int, cols []string, dataRows [][]any) int {
		f.SetCellValue(lookups, fmt.Sprintf("A%d", startRow), title)
		for i, c := range cols {
			cellName, _ := excelize.CoordinatesToCellName(i+1, startRow+1)
			f.SetCellValue(lookups, cellName, c)
		}
		r := startRow + 2
		for _, dr := range dataRows {
			for i, v := range dr {
				cellName, _ := excelize.CoordinatesToCellName(i+1, r)
				f.SetCellValue(lookups, cellName, v)
			}
			r++
		}
		return r + 1
	}

	next := 3

	// Taxes
	taxRows := make([][]any, 0)
	if rows, err := s.db.Query(`SELECT tax_id, name, percentage FROM taxes WHERE company_id=$1 AND is_active=TRUE ORDER BY name`, companyID); err == nil {
		defer rows.Close()
		for rows.Next() {
			var id int
			var name string
			var pct float64
			if err := rows.Scan(&id, &name, &pct); err == nil {
				taxRows = append(taxRows, []any{id, name, pct})
			}
		}
	}
	next = writeLookup("Taxes", next, []string{"Tax ID", "Name", "Percentage"}, taxRows)

	// Categories
	catRows := make([][]any, 0)
	if rows, err := s.db.Query(`SELECT category_id, name FROM categories WHERE company_id=$1 AND is_active=TRUE ORDER BY name`, companyID); err == nil {
		defer rows.Close()
		for rows.Next() {
			var id int
			var name string
			if err := rows.Scan(&id, &name); err == nil {
				catRows = append(catRows, []any{id, name})
			}
		}
	}
	next = writeLookup("Categories", next, []string{"Category ID", "Name"}, catRows)

	// Brands
	brandRows := make([][]any, 0)
	if rows, err := s.db.Query(`SELECT brand_id, name FROM brands WHERE company_id=$1 AND is_active=TRUE ORDER BY name`, companyID); err == nil {
		defer rows.Close()
		for rows.Next() {
			var id int
			var name string
			if err := rows.Scan(&id, &name); err == nil {
				brandRows = append(brandRows, []any{id, name})
			}
		}
	}
	next = writeLookup("Brands", next, []string{"Brand ID", "Name"}, brandRows)

	// Units (global)
	unitRows := make([][]any, 0)
	if rows, err := s.db.Query(`SELECT unit_id, name, COALESCE(symbol,'') FROM units ORDER BY name`); err == nil {
		defer rows.Close()
		for rows.Next() {
			var id int
			var name string
			var sym string
			if err := rows.Scan(&id, &name, &sym); err == nil {
				unitRows = append(unitRows, []any{id, name, sym})
			}
		}
	}
	next = writeLookup("Units", next, []string{"Unit ID", "Name", "Symbol"}, unitRows)

	// Suppliers
	supRows := make([][]any, 0)
	if rows, err := s.db.Query(`SELECT supplier_id, name FROM suppliers WHERE company_id=$1 AND is_active=TRUE ORDER BY name`, companyID); err == nil {
		defer rows.Close()
		for rows.Next() {
			var id int
			var name string
			if err := rows.Scan(&id, &name); err == nil {
				supRows = append(supRows, []any{id, name})
			}
		}
	}
	_ = writeLookup("Suppliers", next, []string{"Supplier ID", "Name"}, supRows)

	buf, err := f.WriteToBuffer()
	if err != nil {
		return nil, fmt.Errorf("failed to generate file: %w", err)
	}
	return buf.Bytes(), nil
}

func (s *InventoryService) InventoryImportExampleXLSX(companyID int) ([]byte, error) {
	b, err := s.InventoryImportTemplateXLSX(companyID)
	if err != nil {
		return nil, err
	}
	f, err := excelize.OpenReader(bytes.NewReader(b))
	if err != nil {
		return nil, err
	}

	sheet := "Inventory"
	var taxName string
	_ = s.db.QueryRow(`SELECT name FROM taxes WHERE company_id=$1 AND is_active=TRUE ORDER BY name LIMIT 1`, companyID).Scan(&taxName)
	if taxName == "" {
		taxName = "1"
	}

	f.SetCellValue(sheet, "A2", "SKU-001")
	f.SetCellValue(sheet, "B2", "Sample Product")
	f.SetCellValue(sheet, "C2", "Sample description")
	f.SetCellValue(sheet, "G2", taxName)
	f.SetCellValue(sheet, "I2", 1.25)
	f.SetCellValue(sheet, "J2", 2.5)
	f.SetCellValue(sheet, "N2", false)
	f.SetCellValue(sheet, "O2", true)
	f.SetCellValue(sheet, "P2", "1234567890123")
	f.SetCellValue(sheet, "Q2", 1)
	f.SetCellValue(sheet, "T2", true)

	buf, err := f.WriteToBuffer()
	if err != nil {
		return nil, fmt.Errorf("failed to generate file: %w", err)
	}
	return buf.Bytes(), nil
}
