package utils

import (
	"bytes"
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	"github.com/xuri/excelize/v2"
)

// GenerateExcel creates an Excel file from the provided data.
func GenerateExcel(data interface{}) ([]byte, error) {
	file := excelize.NewFile()

	sheet := "Sheet1"
	_ = file.SetSheetName(file.GetSheetName(0), sheet)

	normalized, err := normalizeForTabular(data)
	if err != nil {
		return nil, err
	}

	switch v := normalized.(type) {
	case []interface{}:
		if err := writeListAsTable(file, sheet, v); err != nil {
			return nil, err
		}
	case map[string]interface{}:
		if err := writeMapAsPairs(file, sheet, v); err != nil {
			return nil, err
		}
	default:
		// Fallback: write pretty JSON into a single cell so exports never fail.
		jsonData, err := json.MarshalIndent(normalized, "", "  ")
		if err != nil {
			return nil, err
		}
		file.SetCellValue(sheet, "A1", string(jsonData))
	}

	var buf bytes.Buffer
	if err := file.Write(&buf); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func normalizeForTabular(data interface{}) (interface{}, error) {
	// Use JSON round-trip to normalize structs/sql types into plain maps/slices.
	b, err := json.Marshal(data)
	if err != nil {
		return nil, err
	}
	var out interface{}
	if err := json.Unmarshal(b, &out); err != nil {
		return nil, err
	}
	return out, nil
}

func writeMapAsPairs(file *excelize.File, sheet string, m map[string]interface{}) error {
	file.SetCellValue(sheet, "A1", "Field")
	file.SetCellValue(sheet, "B1", "Value")

	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	row := 2
	for _, k := range keys {
		file.SetCellValue(sheet, fmt.Sprintf("A%d", row), k)
		file.SetCellValue(sheet, fmt.Sprintf("B%d", row), formatCellValue(m[k]))
		row++
	}

	if err := styleHeaderRow(file, sheet, 2); err != nil {
		return err
	}
	_, _ = file.NewStyle(&excelize.Style{Alignment: &excelize.Alignment{WrapText: true}})
	_ = file.AutoFilter(sheet, fmt.Sprintf("A1:B%d", row-1), []excelize.AutoFilterOptions{})
	_ = file.SetPanes(sheet, &excelize.Panes{Freeze: true, Split: true, XSplit: 0, YSplit: 1})
	_ = file.SetColWidth(sheet, "A", "A", 28)
	_ = file.SetColWidth(sheet, "B", "B", 60)
	return nil
}

func writeListAsTable(file *excelize.File, sheet string, list []interface{}) error {
	if len(list) == 0 {
		file.SetCellValue(sheet, "A1", "No data")
		return nil
	}

	// Determine columns from maps; fallback to JSON column.
	columnSet := map[string]struct{}{}
	ordered := []string{}
	addCol := func(k string) {
		if _, ok := columnSet[k]; ok {
			return
		}
		columnSet[k] = struct{}{}
		ordered = append(ordered, k)
	}

	for i := 0; i < len(list) && i < 200; i++ {
		if rowMap, ok := list[i].(map[string]interface{}); ok {
			// stable: first row keys alphabetical, then any new keys appended alphabetical
			keys := make([]string, 0, len(rowMap))
			for k := range rowMap {
				keys = append(keys, k)
			}
			sort.Strings(keys)
			for _, k := range keys {
				addCol(k)
			}
		} else {
			addCol("value")
		}
	}
	if len(ordered) == 0 {
		ordered = []string{"value"}
	}

	// Header row
	for i, col := range ordered {
		cell, _ := excelize.CoordinatesToCellName(i+1, 1)
		file.SetCellValue(sheet, cell, col)
	}
	if err := styleHeaderRow(file, sheet, len(ordered)); err != nil {
		return err
	}
	_ = file.SetPanes(sheet, &excelize.Panes{Freeze: true, Split: true, XSplit: 0, YSplit: 1})

	// Data rows
	for r, raw := range list {
		rowIdx := r + 2
		rowMap, isMap := raw.(map[string]interface{})
		for c, col := range ordered {
			cell, _ := excelize.CoordinatesToCellName(c+1, rowIdx)
			if isMap {
				file.SetCellValue(sheet, cell, formatCellValue(rowMap[col]))
			} else if col == "value" {
				file.SetCellValue(sheet, cell, formatCellValue(raw))
			}
		}
	}

	lastCol, _ := excelize.ColumnNumberToName(len(ordered))
	lastRow := len(list) + 1
	_ = file.AutoFilter(
		sheet,
		fmt.Sprintf("A1:%s%d", lastCol, lastRow),
		[]excelize.AutoFilterOptions{},
	)

	// Basic column widths
	for i := 1; i <= len(ordered); i++ {
		colName, _ := excelize.ColumnNumberToName(i)
		_ = file.SetColWidth(sheet, colName, colName, 18)
	}
	return nil
}

func styleHeaderRow(file *excelize.File, sheet string, columnCount int) error {
	styleID, err := file.NewStyle(&excelize.Style{
		Font:      &excelize.Font{Bold: true},
		Fill:      excelize.Fill{Type: "pattern", Color: []string{"#EEEEEE"}, Pattern: 1},
		Alignment: &excelize.Alignment{Horizontal: "left", Vertical: "center", WrapText: true},
	})
	if err != nil {
		return err
	}
	lastCol, _ := excelize.ColumnNumberToName(columnCount)
	return file.SetCellStyle(sheet, "A1", fmt.Sprintf("%s1", lastCol), styleID)
}

func formatCellValue(v interface{}) interface{} {
	if v == nil {
		return ""
	}
	switch t := v.(type) {
	case string:
		return t
	case float64, float32, int, int64, int32, uint, uint64, bool:
		return v
	default:
		b, err := json.Marshal(t)
		if err != nil {
			return fmt.Sprintf("%v", t)
		}
		return string(b)
	}
}

// GeneratePDF creates a minimal PDF file containing the JSON representation
// of the provided data. This implementation avoids external dependencies and
// writes a simple single-page PDF with the text content.
func GeneratePDF(data interface{}) ([]byte, error) {
	jsonData, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return nil, err
	}

	// Escape characters that are special in PDF syntax
	text := string(jsonData)
	text = strings.ReplaceAll(text, "\\", "\\\\")
	text = strings.ReplaceAll(text, "(", "\\(")
	text = strings.ReplaceAll(text, ")", "\\)")

	lines := splitPdfLines(text, 96, 1200)
	var sb strings.Builder
	sb.WriteString("BT /F1 9 Tf 36 756 Td ")
	for i, line := range lines {
		if i > 0 {
			sb.WriteString(" T* ")
		}
		sb.WriteString("(")
		sb.WriteString(line)
		sb.WriteString(") Tj")
	}
	sb.WriteString(" ET")
	content := sb.String()

	var buf bytes.Buffer
	offsets := []int{}

	write := func(format string, a ...interface{}) {
		fmt.Fprintf(&buf, format, a...)
	}
	writeObj := func(format string, a ...interface{}) {
		offsets = append(offsets, buf.Len())
		write(format, a...)
	}

	write("%PDF-1.4\n")
	writeObj("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
	writeObj("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
	writeObj("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n")
	writeObj("4 0 obj\n<< /Length %d >>\nstream\n%s\nendstream\nendobj\n", len(content), content)
	writeObj("5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n")

	xrefOffset := buf.Len()
	write("xref\n0 %d\n", len(offsets)+1)
	write("0000000000 65535 f \n")
	for _, off := range offsets {
		write("%010d 00000 n \n", off)
	}
	write("trailer << /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%EOF\n", len(offsets)+1, xrefOffset)

	return buf.Bytes(), nil
}

func splitPdfLines(s string, maxWidth int, maxLines int) []string {
	if maxWidth <= 0 {
		maxWidth = 80
	}
	if maxLines <= 0 {
		maxLines = 800
	}
	raw := strings.Split(s, "\n")
	out := make([]string, 0, len(raw))
	for _, line := range raw {
		trimmed := strings.TrimRight(line, "\r")
		for len(trimmed) > maxWidth {
			out = append(out, trimmed[:maxWidth])
			trimmed = trimmed[maxWidth:]
			if len(out) >= maxLines {
				return append(out, "... (truncated)")
			}
		}
		out = append(out, trimmed)
		if len(out) >= maxLines {
			return append(out, "... (truncated)")
		}
	}
	return out
}
