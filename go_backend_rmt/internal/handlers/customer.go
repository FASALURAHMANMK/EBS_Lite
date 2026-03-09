package handlers

import (
	"io"
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type CustomerHandler struct {
	customerService *services.CustomerService
}

func NewCustomerHandler() *CustomerHandler {
	return &CustomerHandler{customerService: services.NewCustomerService()}
}

// GET /customers/:id
func (h *CustomerHandler) GetCustomer(c *gin.Context) {
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

	cust, err := h.customerService.GetCustomerByID(customerID, companyID)
	if err != nil {
		if err.Error() == "customer not found" {
			utils.NotFoundResponse(c, "Customer not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get customer", err)
		return
	}

	utils.SuccessResponse(c, "Customer retrieved successfully", cust)
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

	data, err := io.ReadAll(f)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to read file", err)
		return
	}

	res, err := h.customerService.ImportCustomersXLSX(companyID, userID, data)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to import customers", err)
		return
	}

	utils.SuccessResponse(c, "Customers import completed", res)
}

// GET /customers/export
func (h *CustomerHandler) ExportCustomers(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	data, err := h.customerService.ExportCustomersXLSX(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to export customers", err)
		return
	}

	c.Header("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
	c.Header("Content-Disposition", "attachment; filename=customers.xlsx")
	c.Data(http.StatusOK, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", data)
}

// GET /customers/import-template
func (h *CustomerHandler) CustomersImportTemplate(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	data, err := h.customerService.CustomersImportTemplateXLSX(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to generate template", err)
		return
	}

	c.Header("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
	c.Header("Content-Disposition", "attachment; filename=customers_template.xlsx")
	c.Data(http.StatusOK, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", data)
}

// GET /customers/import-example
func (h *CustomerHandler) CustomersImportExample(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	data, err := h.customerService.CustomersImportExampleXLSX(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to generate example", err)
		return
	}

	c.Header("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
	c.Header("Content-Disposition", "attachment; filename=customers_example.xlsx")
	c.Data(http.StatusOK, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", data)
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
