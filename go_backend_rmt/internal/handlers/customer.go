package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/xuri/excelize/v2"
)

type CustomerHandler struct {
	customerService *services.CustomerService
}

func NewCustomerHandler() *CustomerHandler {
	return &CustomerHandler{customerService: services.NewCustomerService()}
}

// GET /customers
func (h *CustomerHandler) GetCustomers(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	filters := make(map[string]string)
	if search := c.Query("search"); search != "" {
		filters["search"] = search
	}
	if phone := c.Query("phone"); phone != "" {
		filters["phone"] = phone
	}
	if creditMin := c.Query("credit_min"); creditMin != "" {
		filters["credit_min"] = creditMin
	}
	if creditMax := c.Query("credit_max"); creditMax != "" {
		filters["credit_max"] = creditMax
	}
	if balanceMin := c.Query("balance_min"); balanceMin != "" {
		filters["balance_min"] = balanceMin
	}
	if balanceMax := c.Query("balance_max"); balanceMax != "" {
		filters["balance_max"] = balanceMax
	}

	customers, err := h.customerService.GetCustomers(companyID, filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get customers", err)
		return
	}
	utils.SuccessResponse(c, "Customers retrieved successfully", customers)
}

// GET /customers/:id/summary
func (h *CustomerHandler) GetCustomerSummary(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	customerID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid customer ID", err)
		return
	}

	summary, err := h.customerService.GetCustomerSummary(customerID, companyID)
	if err != nil {
		if err.Error() == "customer not found" {
			utils.NotFoundResponse(c, "Customer not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get customer summary", err)
		return
	}

	utils.SuccessResponse(c, "Customer summary retrieved successfully", summary)
}

// POST /customers
func (h *CustomerHandler) CreateCustomer(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	userID := c.GetInt("user_id")

	var req models.CreateCustomerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	customer, err := h.customerService.CreateCustomer(companyID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create customer", err)
		return
	}

	utils.CreatedResponse(c, "Customer created successfully", customer)
}

// PUT /customers/:id
func (h *CustomerHandler) UpdateCustomer(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	userID := c.GetInt("user_id")

	customerID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid customer ID", err)
		return
	}

	var req models.UpdateCustomerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	customer, err := h.customerService.UpdateCustomer(customerID, companyID, userID, &req)
	if err != nil {
		if err.Error() == "customer not found" {
			utils.NotFoundResponse(c, "Customer not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update customer", err)
		return
	}

	utils.SuccessResponse(c, "Customer updated successfully", customer)
}

// DELETE /customers/:id
func (h *CustomerHandler) DeleteCustomer(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	userID := c.GetInt("user_id")

	customerID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid customer ID", err)
		return
	}

	if err := h.customerService.DeleteCustomer(customerID, companyID, userID); err != nil {
		if err.Error() == "customer not found" {
			utils.NotFoundResponse(c, "Customer not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to delete customer", err)
		return
	}

	utils.SuccessResponse(c, "Customer deleted successfully", nil)
}

// POST /customers/import
func (h *CustomerHandler) ImportCustomers(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	userID := c.GetInt("user_id")

	file, err := c.FormFile("file")
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "File is required", err)
		return
	}

	f, err := file.Open()
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to open file", err)
		return
	}
	defer f.Close()

	xl, err := excelize.OpenReader(f)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid Excel file", err)
		return
	}

	sheetName := xl.GetSheetName(0)
	rows, err := xl.GetRows(sheetName)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to read sheet", err)
		return
	}

	created := 0
	for i, row := range rows {
		if i == 0 || len(row) == 0 {
			continue // skip header
		}
		req := models.CreateCustomerRequest{Name: row[0]}
		if len(row) > 1 && row[1] != "" {
			req.Phone = &row[1]
		}
		if len(row) > 2 && row[2] != "" {
			req.Email = &row[2]
		}
		if len(row) > 3 && row[3] != "" {
			req.Address = &row[3]
		}
		if len(row) > 4 && row[4] != "" {
			req.TaxNumber = &row[4]
		}
		if len(row) > 5 && row[5] != "" {
			if v, err := strconv.ParseFloat(row[5], 64); err == nil {
				req.CreditLimit = v
			}
		}
		if len(row) > 6 && row[6] != "" {
			if v, err := strconv.Atoi(row[6]); err == nil {
				req.PaymentTerms = v
			}
		}

		if req.Name == "" {
			continue
		}

		if _, err := h.customerService.CreateCustomer(companyID, userID, &req); err == nil {
			created++
		}
	}

	utils.SuccessResponse(c, "Customers imported successfully", map[string]int{"count": created})
}

// GET /customers/export
func (h *CustomerHandler) ExportCustomers(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	customers, err := h.customerService.GetCustomers(companyID, nil)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get customers", err)
		return
	}

	f := excelize.NewFile()
	sheet := "Customers"
	f.SetSheetName("Sheet1", sheet)

	headers := []string{"Name", "Phone", "Email", "Address", "Tax Number", "Credit Limit", "Payment Terms"}
	for i, h := range headers {
		cell, _ := excelize.CoordinatesToCellName(i+1, 1)
		f.SetCellValue(sheet, cell, h)
	}

	for idx, cust := range customers {
		row := idx + 2
		cell, _ := excelize.CoordinatesToCellName(1, row)
		f.SetCellValue(sheet, cell, cust.Name)
		if cust.Phone != nil {
			cell, _ = excelize.CoordinatesToCellName(2, row)
			f.SetCellValue(sheet, cell, *cust.Phone)
		}
		if cust.Email != nil {
			cell, _ = excelize.CoordinatesToCellName(3, row)
			f.SetCellValue(sheet, cell, *cust.Email)
		}
		if cust.Address != nil {
			cell, _ = excelize.CoordinatesToCellName(4, row)
			f.SetCellValue(sheet, cell, *cust.Address)
		}
		if cust.TaxNumber != nil {
			cell, _ = excelize.CoordinatesToCellName(5, row)
			f.SetCellValue(sheet, cell, *cust.TaxNumber)
		}
		cell, _ = excelize.CoordinatesToCellName(6, row)
		f.SetCellValue(sheet, cell, cust.CreditLimit)
		cell, _ = excelize.CoordinatesToCellName(7, row)
		f.SetCellValue(sheet, cell, cust.PaymentTerms)
	}

	buf, err := f.WriteToBuffer()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to generate file", err)
		return
	}

	c.Header("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
	c.Header("Content-Disposition", "attachment; filename=customers.xlsx")
	c.Data(http.StatusOK, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", buf.Bytes())
}

// POST /customers/:id/credit
func (h *CustomerHandler) RecordCreditTransaction(c *gin.Context) {
	customerID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid customer ID", err)
		return
	}
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	userID := c.GetInt("user_id")

	var req models.CreditTransactionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	tx, err := h.customerService.RecordCreditTransaction(customerID, companyID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to record transaction", err)
		return
	}

	utils.CreatedResponse(c, "Credit transaction recorded successfully", tx)
}

// GET /customers/:id/credit
func (h *CustomerHandler) GetCreditHistory(c *gin.Context) {
	customerID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid customer ID", err)
		return
	}
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	history, err := h.customerService.GetCreditHistory(customerID, companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get credit history", err)
		return
	}

	utils.SuccessResponse(c, "Credit history retrieved successfully", history)
}
