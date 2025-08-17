package utils

import (
	"bytes"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/xuri/excelize/v2"
)

// GenerateExcel creates an Excel file from the provided data.
// The data is marshaled to JSON and written to the first cell of the sheet.
func GenerateExcel(data interface{}) ([]byte, error) {
	file := excelize.NewFile()
	jsonData, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return nil, err
	}
	file.SetCellValue("Sheet1", "A1", string(jsonData))
	var buf bytes.Buffer
	if err := file.Write(&buf); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
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

	content := fmt.Sprintf("BT /F1 12 Tf 72 720 Td (%s) Tj ET", text)

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
