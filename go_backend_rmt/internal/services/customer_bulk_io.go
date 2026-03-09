package services

import (
	"bytes"
	"fmt"
	"strconv"
	"strings"

	"erp-backend/internal/models"
	"erp-backend/internal/utils"

	"github.com/xuri/excelize/v2"
)

var customerImportHeaders = []string{
	"Name",
	"Phone",
	"Email",
	"Address",
	"Tax Number",
	"Credit Limit",
	"Payment Terms",
	"Is Loyalty",
	"Loyalty Tier",
	"Is Active",
}

func normalizeHeader(s string) string {
	return strings.ToLower(strings.TrimSpace(s))
}

func headerIndex(headers []string) map[string]int {
	m := make(map[string]int, len(headers))
	for i, h := range headers {
		key := normalizeHeader(h)
		if key != "" {
			m[key] = i
		}
	}
	return m
}

func firstHeaderMatch(idx map[string]int, candidates ...string) (int, bool) {
	for _, c := range candidates {
		if i, ok := idx[normalizeHeader(c)]; ok {
			return i, true
		}
	}
	return 0, false
}

func cell(row []string, i int) string {
	if i < 0 || i >= len(row) {
		return ""
	}
	return strings.TrimSpace(row[i])
}

func parseBoolLoose(s string) (bool, bool) {
	v := strings.ToLower(strings.TrimSpace(s))
	switch v {
	case "1", "true", "yes", "y":
		return true, true
	case "0", "false", "no", "n":
		return false, true
	default:
		return false, false
	}
}

func parseFloatLoose(s string) (float64, bool) {
	v := strings.TrimSpace(s)
	if v == "" {
		return 0, false
	}
	f, err := strconv.ParseFloat(v, 64)
	if err != nil {
		return 0, false
	}
	return f, true
}

func parseIntLoose(s string) (int, bool) {
	v := strings.TrimSpace(s)
	if v == "" {
		return 0, false
	}
	i, err := strconv.Atoi(v)
	if err != nil {
		return 0, false
	}
	return i, true
}

func (s *CustomerService) ExportCustomersXLSX(companyID int) ([]byte, error) {
	customers, err := s.GetCustomers(companyID, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get customers: %w", err)
	}

	f := excelize.NewFile()
	sheet := "Customers"
	f.SetSheetName("Sheet1", sheet)

	for i, h := range customerImportHeaders {
		cellName, _ := excelize.CoordinatesToCellName(i+1, 1)
		f.SetCellValue(sheet, cellName, h)
	}

	_ = f.SetPanes(sheet, &excelize.Panes{
		Freeze:      true,
		Split:       true,
		XSplit:      0,
		YSplit:      1,
		TopLeftCell: "A2",
		ActivePane:  "bottomLeft",
	})
	_ = f.AutoFilter(sheet, "A1:J1", nil)

	for idx, cust := range customers {
		r := idx + 2
		f.SetCellValue(sheet, fmt.Sprintf("A%d", r), cust.Name)
		if cust.Phone != nil {
			f.SetCellValue(sheet, fmt.Sprintf("B%d", r), *cust.Phone)
		}
		if cust.Email != nil {
			f.SetCellValue(sheet, fmt.Sprintf("C%d", r), *cust.Email)
		}
		if cust.Address != nil {
			f.SetCellValue(sheet, fmt.Sprintf("D%d", r), *cust.Address)
		}
		if cust.TaxNumber != nil {
			f.SetCellValue(sheet, fmt.Sprintf("E%d", r), *cust.TaxNumber)
		}
		f.SetCellValue(sheet, fmt.Sprintf("F%d", r), cust.CreditLimit)
		f.SetCellValue(sheet, fmt.Sprintf("G%d", r), cust.PaymentTerms)
		f.SetCellValue(sheet, fmt.Sprintf("H%d", r), cust.IsLoyalty)
		if cust.LoyaltyTierID != nil {
			f.SetCellValue(sheet, fmt.Sprintf("I%d", r), *cust.LoyaltyTierID)
		}
		f.SetCellValue(sheet, fmt.Sprintf("J%d", r), cust.IsActive)
	}

	buf, err := f.WriteToBuffer()
	if err != nil {
		return nil, fmt.Errorf("failed to generate file: %w", err)
	}
	return buf.Bytes(), nil
}

func (s *CustomerService) ImportCustomersXLSX(companyID, userID int, data []byte) (*models.ImportResult, error) {
	xl, err := excelize.OpenReader(bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("invalid Excel file: %w", err)
	}

	sheetName := xl.GetSheetName(0)
	rows, err := xl.GetRows(sheetName)
	if err != nil {
		return nil, fmt.Errorf("failed to read sheet: %w", err)
	}
	if len(rows) == 0 {
		return &models.ImportResult{}, nil
	}

	hdr := headerIndex(rows[0])
	nameIdx, ok := firstHeaderMatch(hdr, "name")
	if !ok {
		return nil, fmt.Errorf("missing required column: Name")
	}

	phoneIdx, _ := firstHeaderMatch(hdr, "phone")
	emailIdx, _ := firstHeaderMatch(hdr, "email")
	addressIdx, _ := firstHeaderMatch(hdr, "address")
	taxIdx, _ := firstHeaderMatch(hdr, "tax number", "tax_number", "tax")
	creditIdx, _ := firstHeaderMatch(hdr, "credit limit", "credit_limit")
	termsIdx, _ := firstHeaderMatch(hdr, "payment terms", "payment_terms")
	loyaltyIdx, hasLoyalty := firstHeaderMatch(hdr, "is loyalty", "is_loyalty", "loyalty")
	tierIdx, hasTier := firstHeaderMatch(hdr, "loyalty tier", "loyalty tier id", "loyalty_tier_id", "loyalty_tier")
	activeIdx, hasActive := firstHeaderMatch(hdr, "is active", "is_active", "active")

	// Lookup loyalty tiers by name for convenience.
	tiersByName := map[string]int{}
	tierRows, err := s.db.Query(`SELECT tier_id, name FROM loyalty_tiers WHERE company_id=$1 AND is_active=TRUE`, companyID)
	if err == nil {
		defer tierRows.Close()
		for tierRows.Next() {
			var id int
			var name string
			if err := tierRows.Scan(&id, &name); err == nil {
				tiersByName[normalizeHeader(name)] = id
			}
		}
	}

	res := &models.ImportResult{Errors: make([]models.ImportRowError, 0)}
	for i, row := range rows[1:] {
		rowNum := i + 2 // 1-based with header row
		name := cell(row, nameIdx)
		if name == "" {
			res.Skipped++
			continue
		}

		req := models.CreateCustomerRequest{
			Name:         name,
			Phone:        utils.EmptyToNil(cell(row, phoneIdx)),
			Email:        utils.EmptyToNil(cell(row, emailIdx)),
			Address:      utils.EmptyToNil(cell(row, addressIdx)),
			TaxNumber:    utils.EmptyToNil(cell(row, taxIdx)),
			CreditLimit:  0,
			PaymentTerms: 0,
			IsLoyalty:    false,
		}

		if v, ok := parseFloatLoose(cell(row, creditIdx)); ok {
			req.CreditLimit = v
		} else if credit := cell(row, creditIdx); credit != "" {
			res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Credit Limit", Message: "invalid number"})
			res.Skipped++
			continue
		}

		if v, ok := parseIntLoose(cell(row, termsIdx)); ok {
			req.PaymentTerms = v
		} else if terms := cell(row, termsIdx); terms != "" {
			res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Payment Terms", Message: "invalid number"})
			res.Skipped++
			continue
		}

		if hasLoyalty {
			if b, ok := parseBoolLoose(cell(row, loyaltyIdx)); ok {
				req.IsLoyalty = b
			} else if raw := cell(row, loyaltyIdx); raw != "" {
				res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Is Loyalty", Message: "invalid boolean (use true/false)"})
				res.Skipped++
				continue
			}
		}

		if hasTier {
			raw := cell(row, tierIdx)
			if raw != "" {
				if id, ok := parseIntLoose(raw); ok && id > 0 {
					req.LoyaltyTierID = &id
				} else if id, ok := tiersByName[normalizeHeader(raw)]; ok {
					req.LoyaltyTierID = &id
				} else {
					res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Loyalty Tier", Message: "unknown tier (use tier ID or name from Lookups)"})
					res.Skipped++
					continue
				}
			}
		}

		if err := utils.ValidateStruct(&req); err != nil {
			res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Message: "validation failed"})
			res.Skipped++
			continue
		}

		createdCust, err := s.CreateCustomer(companyID, userID, &req)
		if err != nil {
			res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Message: err.Error()})
			res.Skipped++
			continue
		}
		res.Created++

		if hasActive {
			if b, ok := parseBoolLoose(cell(row, activeIdx)); ok && b == false {
				_, _ = s.UpdateCustomer(createdCust.CustomerID, companyID, userID, &models.UpdateCustomerRequest{IsActive: &b})
			} else if raw := cell(row, activeIdx); raw != "" && !ok {
				res.Errors = append(res.Errors, models.ImportRowError{Row: rowNum, Column: "Is Active", Message: "invalid boolean (use true/false)"})
			}
		}
	}

	res.Count = res.Created
	return res, nil
}

func (s *CustomerService) CustomersImportTemplateXLSX(companyID int) ([]byte, error) {
	f := excelize.NewFile()

	sheet := "Customers"
	f.SetSheetName("Sheet1", sheet)
	for i, h := range customerImportHeaders {
		cellName, _ := excelize.CoordinatesToCellName(i+1, 1)
		f.SetCellValue(sheet, cellName, h)
	}
	_ = f.SetPanes(sheet, &excelize.Panes{Freeze: true, Split: true, YSplit: 1, TopLeftCell: "A2", ActivePane: "bottomLeft"})
	_ = f.AutoFilter(sheet, "A1:J1", nil)

	lookups := "Lookups"
	f.NewSheet(lookups)
	f.SetCellValue(lookups, "A1", "Loyalty Tiers")
	f.SetCellValue(lookups, "A3", "Tier ID")
	f.SetCellValue(lookups, "B3", "Name")
	f.SetCellValue(lookups, "C3", "Min Points")
	f.SetCellValue(lookups, "D3", "Points/Currency")

	rows, err := s.db.Query(`SELECT tier_id, name, min_points, COALESCE(points_per_currency,0) FROM loyalty_tiers WHERE company_id=$1 AND is_active=TRUE ORDER BY min_points ASC`, companyID)
	if err == nil {
		defer rows.Close()
		r := 4
		for rows.Next() {
			var id int
			var name string
			var min int
			var rate float64
			if err := rows.Scan(&id, &name, &min, &rate); err == nil {
				f.SetCellValue(lookups, fmt.Sprintf("A%d", r), id)
				f.SetCellValue(lookups, fmt.Sprintf("B%d", r), name)
				f.SetCellValue(lookups, fmt.Sprintf("C%d", r), min)
				f.SetCellValue(lookups, fmt.Sprintf("D%d", r), rate)
				r++
			}
		}
	}

	buf, err := f.WriteToBuffer()
	if err != nil {
		return nil, fmt.Errorf("failed to generate file: %w", err)
	}
	return buf.Bytes(), nil
}

func (s *CustomerService) CustomersImportExampleXLSX(companyID int) ([]byte, error) {
	b, err := s.CustomersImportTemplateXLSX(companyID)
	if err != nil {
		return nil, err
	}
	f, err := excelize.OpenReader(bytes.NewReader(b))
	if err != nil {
		return nil, err
	}

	sheet := "Customers"
	f.SetCellValue(sheet, "A2", "John Doe")
	f.SetCellValue(sheet, "B2", "5550001")
	f.SetCellValue(sheet, "C2", "john@example.com")
	f.SetCellValue(sheet, "D2", "Muscat")
	f.SetCellValue(sheet, "E2", "TAX-123")
	f.SetCellValue(sheet, "F2", 100.0)
	f.SetCellValue(sheet, "G2", 30)
	f.SetCellValue(sheet, "H2", true)
	// Loyalty Tier left blank intentionally; use Lookups sheet if needed.
	f.SetCellValue(sheet, "J2", true)

	buf, err := f.WriteToBuffer()
	if err != nil {
		return nil, fmt.Errorf("failed to generate file: %w", err)
	}
	return buf.Bytes(), nil
}
