package utils

import (
	"bytes"
	"strings"
	"testing"

	"github.com/xuri/excelize/v2"
)

func TestGenerateExcelUsesAccountantFriendlyHeaders(t *testing.T) {
	data := []map[string]interface{}{
		{
			"account_code":     "4000",
			"account_name":     "Sales Revenue",
			"credit":           150.0,
			"date":             "2026-03-09",
			"debit":            0.0,
			"transaction_type": "sale_return",
		},
	}

	content, err := GenerateExcel("/reports/general-ledger", data)
	if err != nil {
		t.Fatalf("GenerateExcel returned error: %v", err)
	}

	file, err := excelize.OpenReader(bytes.NewReader(content))
	if err != nil {
		t.Fatalf("failed to open generated workbook: %v", err)
	}
	defer file.Close()

	sheet := file.GetSheetName(0)
	title, err := file.GetCellValue(sheet, "A1")
	if err != nil {
		t.Fatalf("failed to read title cell: %v", err)
	}
	if title != "General Ledger" {
		t.Fatalf("unexpected title: %s", title)
	}

	headers := []string{"A3", "B3", "C3", "D3", "E3", "F3"}
	expected := []string{"Date", "Account Code", "Account Name", "Debit", "Credit", "Source Type"}
	for i, cell := range headers {
		value, err := file.GetCellValue(sheet, cell)
		if err != nil {
			t.Fatalf("failed to read header %s: %v", cell, err)
		}
		if value != expected[i] {
			t.Fatalf("unexpected header at %s: got %q want %q", cell, value, expected[i])
		}
	}
}

func TestGeneratePDFUsesFriendlyLabels(t *testing.T) {
	data := map[string]interface{}{
		"section": "TOTAL_REVENUE",
		"amount":  450.0,
	}

	content, err := GeneratePDF("/reports/profit-loss", data)
	if err != nil {
		t.Fatalf("GeneratePDF returned error: %v", err)
	}

	text := string(content)
	if !strings.Contains(text, "Profit & Loss") {
		t.Fatalf("expected title in generated pdf content")
	}
	if !strings.Contains(text, "Total Revenue") {
		t.Fatalf("expected labeled section in generated pdf content")
	}
	if !strings.Contains(text, "Amount") {
		t.Fatalf("expected friendly key label in generated pdf content")
	}
}

func TestReportExportFilenameUsesFriendlySlug(t *testing.T) {
	got := ReportExportFilename("/reports/trial-balance", "xlsx")
	if got != "trial-balance.xlsx" {
		t.Fatalf("unexpected filename: %s", got)
	}

	got = ReportExportFilename("/reports/balance-sheet", "pdf")
	if got != "balance-sheet.pdf" {
		t.Fatalf("unexpected filename: %s", got)
	}
}
