package handlers

import (
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

// GET /customers
func (h *CustomerHandler) GetCustomers(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	search := c.Query("search")
	customers, err := h.customerService.GetCustomers(companyID, search)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get customers", err)
		return
	}
	utils.SuccessResponse(c, "Customers retrieved successfully", customers)
}

// POST /customers
func (h *CustomerHandler) CreateCustomer(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req models.CreateCustomerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	customer, err := h.customerService.CreateCustomer(companyID, &req)
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

	if err := h.customerService.UpdateCustomer(customerID, companyID, &req); err != nil {
		if err.Error() == "customer not found" {
			utils.NotFoundResponse(c, "Customer not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update customer", err)
		return
	}

	utils.SuccessResponse(c, "Customer updated successfully", nil)
}

// DELETE /customers/:id
func (h *CustomerHandler) DeleteCustomer(c *gin.Context) {
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

	if err := h.customerService.DeleteCustomer(customerID, companyID); err != nil {
		if err.Error() == "customer not found" {
			utils.NotFoundResponse(c, "Customer not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to delete customer", err)
		return
	}

	utils.SuccessResponse(c, "Customer deleted successfully", nil)
}
