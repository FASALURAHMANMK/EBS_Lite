package utils

import (
	"bytes"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/xuri/excelize/v2"
)

type reportExportSchema struct {
	Title         string
	PreferredCols []string
}

var reportExportSchemas = map[string]reportExportSchema{
	"/reports/sales-summary": {
		Title:         "Sales Summary",
		PreferredCols: []string{"period", "transactions", "total_sales", "outstanding"},
	},
	"/reports/top-products": {
		Title:         "Top-Selling Products",
		PreferredCols: []string{"product_id", "product_name", "quantity_sold", "revenue"},
	},
	"/reports/customer-balances": {
		Title:         "Customer Outstanding Balances",
		PreferredCols: []string{"customer_id", "name", "total_due"},
	},
	"/reports/tax": {
		Title:         "Tax Report",
		PreferredCols: []string{"tax_name", "tax_rate", "taxable_amount", "tax_amount"},
	},
	"/reports/purchase-vs-returns": {
		Title:         "Purchases and Purchase Returns",
		PreferredCols: []string{"purchases_total", "returns_total", "net_purchases", "purchases_outstanding"},
	},
	"/reports/supplier": {
		Title:         "Supplier Purchases and Balances",
		PreferredCols: []string{"supplier_id", "supplier_name", "purchases_total", "purchases_paid", "purchases_outstanding", "returns_total"},
	},
	"/reports/daily-cash": {
		Title:         "Cash Register Summary",
		PreferredCols: []string{"date", "location_id", "status", "opening_balance", "cash_in", "cash_out", "expected_balance", "closing_balance", "variance"},
	},
	"/reports/cash-book": {
		Title:         "Cash Book",
		PreferredCols: []string{"date", "account_code", "account_name", "debit", "credit", "running_balance", "transaction_type", "transaction_id", "reference", "description"},
	},
	"/reports/bank-book": {
		Title:         "Bank Book",
		PreferredCols: []string{"bank_account_name", "bank_name", "date", "account_code", "account_name", "debit", "credit", "running_balance", "transaction_type", "transaction_id", "reference", "description"},
	},
	"/reports/reconciliation-summary": {
		Title:         "Reconciliation Summary",
		PreferredCols: []string{"bank_account_name", "bank_name", "statement_entries", "matched_entries", "unmatched_entries", "review_entries", "net_statement_amount", "open_amount"},
	},
	"/reports/income-expense": {
		Title:         "Income and Expense Summary",
		PreferredCols: []string{"day", "sales_total", "expenses_total", "net_income"},
	},
	"/reports/general-ledger": {
		Title:         "General Ledger",
		PreferredCols: []string{"date", "account_code", "account_name", "debit", "credit", "transaction_type", "transaction_id", "source_number", "reference", "description", "voucher_id", "entry_id", "account_id"},
	},
	"/reports/trial-balance": {
		Title:         "Trial Balance",
		PreferredCols: []string{"account_code", "account_name", "account_type", "total_debit", "total_credit", "balance"},
	},
	"/reports/profit-loss": {
		Title:         "Profit & Loss",
		PreferredCols: []string{"section", "account_code", "account_name", "amount"},
	},
	"/reports/balance-sheet": {
		Title:         "Balance Sheet",
		PreferredCols: []string{"section", "account_code", "account_name", "amount"},
	},
	"/reports/outstanding": {
		Title:         "Receivables and Payables Summary",
		PreferredCols: []string{"type", "amount"},
	},
	"/reports/tax-review": {
		Title:         "Tax Review",
		PreferredCols: []string{"tax_side", "tax_name", "tax_rate", "taxable_amount", "tax_amount"},
	},
	"/reports/top-performers": {
		Title:         "Top Performers",
		PreferredCols: []string{"category", "name", "total_sales", "transactions"},
	},
	"/reports/stock-summary": {
		Title:         "Stock on Hand Summary",
		PreferredCols: []string{"product_id", "location_id", "quantity", "stock_value"},
	},
	"/reports/item-movement": {
		Title:         "Item Movement",
		PreferredCols: []string{"product_id", "product_name", "purchased_qty", "purchase_return_qty", "sold_qty", "sale_return_qty", "adjustment_qty", "net_movement"},
	},
	"/reports/valuation": {
		Title:         "Inventory Valuation",
		PreferredCols: []string{"product_id", "product_name", "quantity", "stock_value"},
	},
	"/reports/asset-register": {
		Title:         "Asset Register",
		PreferredCols: []string{"asset_tag", "item_name", "category_name", "supplier_name", "location_id", "acquisition_date", "in_service_date", "status", "source_mode", "quantity", "unit_cost", "total_value"},
	},
	"/reports/asset-value-summary": {
		Title:         "Asset Value Summary",
		PreferredCols: []string{"category_name", "status", "item_count", "total_value"},
	},
	"/reports/consumable-consumption": {
		Title:         "Consumable Consumption",
		PreferredCols: []string{"entry_number", "item_name", "category_name", "supplier_name", "location_id", "consumed_at", "source_mode", "quantity", "unit_cost", "total_cost"},
	},
	"/reports/consumable-balance": {
		Title:         "Consumable Balance",
		PreferredCols: []string{"product_id", "product_name", "location_id", "quantity", "stock_value"},
	},
}

var reportExportLabels = map[string]string{
	"account_id":            "Account ID",
	"account_code":          "Account Code",
	"account_name":          "Account Name",
	"account_type":          "Account Type",
	"amount":                "Amount",
	"asset_tag":             "Asset Tag",
	"bank_account_name":     "Bank Account",
	"bank_name":             "Bank",
	"balance":               "Balance",
	"cash_in":               "Cash In",
	"cash_out":              "Cash Out",
	"category":              "Category",
	"category_name":         "Category",
	"closing_balance":       "Closing Balance",
	"consumed_at":           "Consumed At",
	"credit":                "Credit",
	"customer_id":           "Customer ID",
	"date":                  "Date",
	"day":                   "Day",
	"debit":                 "Debit",
	"description":           "Description",
	"entry_number":          "Entry Number",
	"entry_id":              "Entry ID",
	"expected_balance":      "Expected Balance",
	"expenses_total":        "Expenses",
	"field":                 "Field",
	"in_service_date":       "In Service Date",
	"item_count":            "Item Count",
	"item_name":             "Item Name",
	"location_id":           "Location ID",
	"name":                  "Name",
	"net_income":            "Net Income",
	"net_movement":          "Net Movement",
	"net_purchases":         "Net Purchases",
	"net_statement_amount":  "Net Statement Amount",
	"open_amount":           "Open Amount",
	"opening_balance":       "Opening Balance",
	"outstanding":           "Outstanding Balance",
	"period":                "Period",
	"product_id":            "Product ID",
	"product_name":          "Product Name",
	"purchased_qty":         "Purchased Quantity",
	"purchase_return_qty":   "Purchase Return Quantity",
	"purchases_outstanding": "Outstanding Payables",
	"purchases_paid":        "Payments Made",
	"purchases_total":       "Purchases",
	"quantity":              "Quantity",
	"quantity_sold":         "Quantity Sold",
	"reference":             "Reference",
	"returns_total":         "Purchase Returns",
	"revenue":               "Sales Revenue",
	"sale_return_qty":       "Sales Return Quantity",
	"sales_total":           "Sales",
	"section":               "Section",
	"source_mode":           "Source Mode",
	"status":                "Status",
	"statement_entries":     "Statement Entries",
	"stock_value":           "Stock Value",
	"source_number":         "Source Number",
	"supplier_id":           "Supplier ID",
	"supplier_name":         "Supplier Name",
	"tax_side":              "Tax Side",
	"tax_amount":            "Tax Amount",
	"tax_name":              "Tax Code",
	"tax_rate":              "Tax Rate",
	"taxable_amount":        "Taxable Amount",
	"total_credit":          "Total Credit",
	"total_debit":           "Total Debit",
	"total_due":             "Outstanding Balance",
	"total_sales":           "Sales Total",
	"total_value":           "Total Value",
	"transactions":          "Transactions",
	"transaction_id":        "Transaction ID",
	"transaction_type":      "Source Type",
	"type":                  "Type",
	"matched_entries":       "Matched Entries",
	"unmatched_entries":     "Unmatched Entries",
	"review_entries":        "Review Entries",
	"value":                 "Value",
	"variance":              "Variance",
	"voucher_id":            "Voucher ID",
}

var reportExportValueLabels = map[string]map[string]string{
	"section": {
		"ASSET":                           "Assets",
		"LIABILITY":                       "Liabilities",
		"EQUITY":                          "Equity",
		"REVENUE":                         "Revenue",
		"EXPENSE":                         "Expenses",
		"TOTAL_ASSETS":                    "Total Assets",
		"TOTAL_LIABILITIES":               "Total Liabilities",
		"TOTAL_EQUITY":                    "Total Equity",
		"TOTAL_REVENUE":                   "Total Revenue",
		"TOTAL_EXPENSE":                   "Total Expenses",
		"NET_PROFIT":                      "Net Profit",
		"ASSETS_MINUS_LIABILITIES_EQUITY": "Balance Sheet Difference",
	},
	"type": {
		"sales":     "Accounts Receivable",
		"purchases": "Accounts Payable",
	},
	"tax_side": {
		"OUTPUT": "Output Tax",
		"INPUT":  "Input Tax",
		"NET":    "Net Tax",
	},
}

// GenerateExcel creates an Excel file from the provided data.
func GenerateExcel(endpoint string, data interface{}) ([]byte, error) {
	file := excelize.NewFile()

	schema := lookupReportSchema(endpoint)
	sheet := sanitizeSheetName(schema.Title)
	_ = file.SetSheetName(file.GetSheetName(0), sheet)

	normalized, err := normalizeForTabular(data)
	if err != nil {
		return nil, err
	}

	switch v := normalized.(type) {
	case []interface{}:
		if err := writeListAsTable(file, sheet, schema, v); err != nil {
			return nil, err
		}
	case map[string]interface{}:
		if err := writeMapAsPairs(file, sheet, schema, v); err != nil {
			return nil, err
		}
	default:
		jsonData, err := json.MarshalIndent(relabelNormalizedData(schema, normalized), "", "  ")
		if err != nil {
			return nil, err
		}
		file.SetCellValue(sheet, "A1", schema.Title)
		file.SetCellValue(sheet, "A3", string(jsonData))
	}

	var buf bytes.Buffer
	if err := file.Write(&buf); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func normalizeForTabular(data interface{}) (interface{}, error) {
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

func writeMapAsPairs(file *excelize.File, sheet string, schema reportExportSchema, m map[string]interface{}) error {
	file.SetCellValue(sheet, "A1", schema.Title)
	file.SetCellValue(sheet, "A3", "Field")
	file.SetCellValue(sheet, "B3", "Value")

	keys := orderedColumns(schema, mapKeys(m))

	row := 4
	for _, key := range keys {
		file.SetCellValue(sheet, fmt.Sprintf("A%d", row), labelForKey(key))
		file.SetCellValue(sheet, fmt.Sprintf("B%d", row), formatDisplayValue(key, m[key]))
		row++
	}

	if err := styleTitleRow(file, sheet, "A1:B1"); err != nil {
		return err
	}
	if err := styleHeaderRow(file, sheet, 2, 3); err != nil {
		return err
	}
	_ = file.AutoFilter(sheet, fmt.Sprintf("A3:B%d", row-1), []excelize.AutoFilterOptions{})
	_ = file.SetPanes(sheet, &excelize.Panes{Freeze: true, Split: true, XSplit: 0, YSplit: 3, TopLeftCell: "A4"})
	_ = file.SetColWidth(sheet, "A", "A", 28)
	_ = file.SetColWidth(sheet, "B", "B", 60)
	return nil
}

func writeListAsTable(file *excelize.File, sheet string, schema reportExportSchema, list []interface{}) error {
	if len(list) == 0 {
		file.SetCellValue(sheet, "A1", schema.Title)
		file.SetCellValue(sheet, "A3", "No data")
		_ = styleTitleRow(file, sheet, "A1:B1")
		return nil
	}

	columnSet := map[string]struct{}{}
	for i := 0; i < len(list) && i < 200; i++ {
		if rowMap, ok := list[i].(map[string]interface{}); ok {
			for _, key := range mapKeys(rowMap) {
				columnSet[key] = struct{}{}
			}
		} else {
			columnSet["value"] = struct{}{}
		}
	}
	if len(columnSet) == 0 {
		columnSet["value"] = struct{}{}
	}

	ordered := make([]string, 0, len(columnSet))
	for key := range columnSet {
		ordered = append(ordered, key)
	}
	ordered = orderedColumns(schema, ordered)

	file.SetCellValue(sheet, "A1", schema.Title)
	for i, col := range ordered {
		cell, _ := excelize.CoordinatesToCellName(i+1, 3)
		file.SetCellValue(sheet, cell, labelForKey(col))
	}
	if err := styleTitleRow(file, sheet, fmt.Sprintf("A1:%s1", mustColumnName(max(1, len(ordered))))); err != nil {
		return err
	}
	if err := styleHeaderRow(file, sheet, len(ordered), 3); err != nil {
		return err
	}
	_ = file.SetPanes(sheet, &excelize.Panes{Freeze: true, Split: true, XSplit: 0, YSplit: 3, TopLeftCell: "A4"})

	for r, raw := range list {
		rowIdx := r + 4
		rowMap, isMap := raw.(map[string]interface{})
		for c, col := range ordered {
			cell, _ := excelize.CoordinatesToCellName(c+1, rowIdx)
			if isMap {
				file.SetCellValue(sheet, cell, formatDisplayValue(col, rowMap[col]))
			} else if col == "value" {
				file.SetCellValue(sheet, cell, formatDisplayValue(col, raw))
			}
		}
	}

	lastCol := mustColumnName(len(ordered))
	lastRow := len(list) + 3
	_ = file.AutoFilter(sheet, fmt.Sprintf("A3:%s%d", lastCol, lastRow), []excelize.AutoFilterOptions{})
	for i := 1; i <= len(ordered); i++ {
		colName := mustColumnName(i)
		_ = file.SetColWidth(sheet, colName, colName, 18)
	}
	return nil
}

func styleTitleRow(file *excelize.File, sheet, cellRange string) error {
	styleID, err := file.NewStyle(&excelize.Style{
		Font:      &excelize.Font{Bold: true, Size: 14},
		Alignment: &excelize.Alignment{Horizontal: "left", Vertical: "center"},
	})
	if err != nil {
		return err
	}
	return file.SetCellStyle(sheet, strings.Split(cellRange, ":")[0], strings.Split(cellRange, ":")[1], styleID)
}

func styleHeaderRow(file *excelize.File, sheet string, columnCount int, row int) error {
	styleID, err := file.NewStyle(&excelize.Style{
		Font:      &excelize.Font{Bold: true},
		Fill:      excelize.Fill{Type: "pattern", Color: []string{"#EEEEEE"}, Pattern: 1},
		Alignment: &excelize.Alignment{Horizontal: "left", Vertical: "center", WrapText: true},
	})
	if err != nil {
		return err
	}
	lastCol := mustColumnName(columnCount)
	return file.SetCellStyle(sheet, fmt.Sprintf("A%d", row), fmt.Sprintf("%s%d", lastCol, row), styleID)
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

// GeneratePDF creates a minimal PDF file containing a labeled JSON-style
// representation of the provided report data.
func GeneratePDF(endpoint string, data interface{}) ([]byte, error) {
	schema := lookupReportSchema(endpoint)
	normalized, err := normalizeForTabular(data)
	if err != nil {
		return nil, err
	}
	labeled := relabelNormalizedData(schema, normalized)
	jsonData, err := json.MarshalIndent(labeled, "", "  ")
	if err != nil {
		return nil, err
	}

	text := schema.Title + "\n\n" + string(jsonData)
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

func lookupReportSchema(endpoint string) reportExportSchema {
	normalized := normalizeReportEndpoint(endpoint)
	if schema, ok := reportExportSchemas[normalized]; ok {
		return schema
	}
	return reportExportSchema{
		Title:         "Report",
		PreferredCols: nil,
	}
}

func ReportExportFilename(endpoint, ext string) string {
	schema := lookupReportSchema(endpoint)
	base := slugifyReportTitle(schema.Title)
	if base == "" {
		base = "report"
	}
	ext = strings.TrimSpace(strings.TrimPrefix(ext, "."))
	if ext == "" {
		return base
	}
	return base + "." + ext
}

func normalizeReportEndpoint(endpoint string) string {
	if endpoint == "" {
		return ""
	}
	if idx := strings.Index(endpoint, "/reports/"); idx >= 0 {
		return endpoint[idx:]
	}
	return endpoint
}

func orderedColumns(schema reportExportSchema, columns []string) []string {
	sorted := append([]string(nil), columns...)
	sort.Strings(sorted)
	if len(schema.PreferredCols) == 0 {
		return sorted
	}

	remaining := make(map[string]struct{}, len(sorted))
	for _, col := range sorted {
		remaining[col] = struct{}{}
	}

	out := make([]string, 0, len(sorted))
	for _, col := range schema.PreferredCols {
		if _, ok := remaining[col]; ok {
			out = append(out, col)
			delete(remaining, col)
		}
	}
	for _, col := range sorted {
		if _, ok := remaining[col]; ok {
			out = append(out, col)
		}
	}
	return out
}

func labelForKey(key string) string {
	key = strings.TrimSpace(key)
	if label, ok := reportExportLabels[key]; ok {
		return label
	}
	return humanizeKey(key)
}

func formatDisplayValue(key string, value interface{}) interface{} {
	if value == nil {
		return ""
	}

	if mapped := mapLabeledValue(key, value); mapped != nil {
		return mapped
	}

	switch v := value.(type) {
	case string:
		if looksLikeDateKey(key) {
			if parsed, err := time.Parse(time.RFC3339, v); err == nil {
				return parsed.Format("2006-01-02")
			}
			if parsed, err := time.Parse("2006-01-02", v); err == nil {
				return parsed.Format("2006-01-02")
			}
		}
		return v
	case float64:
		if looksLikePercentKey(key) {
			return fmt.Sprintf("%.2f%%", v)
		}
		if looksLikeQuantityKey(key) {
			if v == float64(int64(v)) {
				return fmt.Sprintf("%.0f", v)
			}
			return fmt.Sprintf("%.3f", v)
		}
		return fmt.Sprintf("%.2f", v)
	case bool, int, int64, int32, uint, uint64:
		return formatCellValue(v)
	case map[string]interface{}:
		return relabelMap(v, reportExportSchema{})
	case []interface{}:
		return relabelSlice(v, reportExportSchema{})
	default:
		return formatCellValue(v)
	}
}

func mapLabeledValue(key string, value interface{}) interface{} {
	val, ok := value.(string)
	if !ok {
		return nil
	}
	if labelMap, ok := reportExportValueLabels[key]; ok {
		if label, ok := labelMap[val]; ok {
			return label
		}
		return humanizeKey(val)
	}
	if key == "status" || key == "transaction_type" {
		return humanizeKey(val)
	}
	return nil
}

func looksLikeDateKey(key string) bool {
	return key == "date" || key == "day" || strings.HasSuffix(key, "_date") || strings.HasSuffix(key, "_at")
}

func looksLikePercentKey(key string) bool {
	return strings.Contains(key, "rate") || strings.Contains(key, "percent")
}

func looksLikeQuantityKey(key string) bool {
	return key == "quantity" || strings.HasSuffix(key, "_qty") || key == "transactions"
}

func relabelNormalizedData(schema reportExportSchema, data interface{}) interface{} {
	switch v := data.(type) {
	case map[string]interface{}:
		return relabelMap(v, schema)
	case []interface{}:
		return relabelSlice(v, schema)
	default:
		return formatDisplayValue("value", v)
	}
}

func relabelMap(m map[string]interface{}, schema reportExportSchema) map[string]interface{} {
	keys := orderedColumns(schema, mapKeys(m))
	out := make(map[string]interface{}, len(m))
	for _, key := range keys {
		out[labelForKey(key)] = relabelValue(key, m[key], schema)
	}
	return out
}

func relabelSlice(list []interface{}, schema reportExportSchema) []interface{} {
	out := make([]interface{}, 0, len(list))
	for _, item := range list {
		switch v := item.(type) {
		case map[string]interface{}:
			out = append(out, relabelMap(v, schema))
		case []interface{}:
			out = append(out, relabelSlice(v, schema))
		default:
			out = append(out, formatDisplayValue("value", v))
		}
	}
	return out
}

func relabelValue(key string, value interface{}, schema reportExportSchema) interface{} {
	switch v := value.(type) {
	case map[string]interface{}:
		return relabelMap(v, reportExportSchema{})
	case []interface{}:
		return relabelSlice(v, reportExportSchema{})
	default:
		return formatDisplayValue(key, v)
	}
}

func mapKeys(m map[string]interface{}) []string {
	keys := make([]string, 0, len(m))
	for key := range m {
		keys = append(keys, key)
	}
	return keys
}

func humanizeKey(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return raw
	}
	parts := strings.FieldsFunc(strings.ReplaceAll(raw, "-", "_"), func(r rune) bool {
		return r == '_'
	})
	if len(parts) == 0 {
		return raw
	}
	for i, part := range parts {
		lower := strings.ToLower(part)
		parts[i] = strings.ToUpper(lower[:1]) + lower[1:]
	}
	return strings.Join(parts, " ")
}

func sanitizeSheetName(name string) string {
	if strings.TrimSpace(name) == "" {
		return "Report"
	}
	replacer := strings.NewReplacer(":", " ", "/", " ", "\\", " ", "?", "", "*", "", "[", "", "]", "")
	name = replacer.Replace(strings.TrimSpace(name))
	if len(name) > 31 {
		name = name[:31]
	}
	if name == "" {
		return "Report"
	}
	return name
}

func slugifyReportTitle(title string) string {
	title = strings.TrimSpace(strings.ToLower(title))
	if title == "" {
		return ""
	}
	var out strings.Builder
	prevDash := false
	for _, r := range title {
		switch {
		case r >= 'a' && r <= 'z':
			out.WriteRune(r)
			prevDash = false
		case r >= '0' && r <= '9':
			out.WriteRune(r)
			prevDash = false
		default:
			if !prevDash && out.Len() > 0 {
				out.WriteRune('-')
				prevDash = true
			}
		}
	}
	slug := strings.Trim(out.String(), "-")
	return slug
}

func mustColumnName(n int) string {
	col, _ := excelize.ColumnNumberToName(max(1, n))
	return col
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
