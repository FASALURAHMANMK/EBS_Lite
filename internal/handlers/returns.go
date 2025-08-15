package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type ReturnsHandler struct {
	returnsService *services.ReturnsService
}

func NewReturnsHandler() *ReturnsHandler {
	return &ReturnsHandler{
		returnsService: services.NewReturnsService(),
	}
}

// GET /sale-returns
func (h *ReturnsHandler) GetSaleReturns(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	// Parse query filters
	filters := make(map[string]string)
	if dateFrom := c.Query("date_from"); dateFrom != "" {
		filters["date_from"] = dateFrom
	}
	if dateTo := c.Query("date_to"); dateTo != "" {
		filters["date_to"] = dateTo
	}
	if customerID := c.Query("customer_id"); customerID != "" {
		filters["customer_id"] = customerID
	}
	if saleID := c.Query("sale_id"); saleID != "" {
		filters["sale_id"] = saleID
	}
	if status := c.Query("status"); status != "" {
		filters["status"] = status
	}

	returns, err := h.returnsService.GetSaleReturns(companyID, filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get sale returns", err)
		return
	}

	utils.SuccessResponse(c, "Sale returns retrieved successfully", returns)
}

// GET /sale-returns/:id
func (h *ReturnsHandler) GetSaleReturn(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	returnID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid return ID", err)
		return
	}

	saleReturn, err := h.returnsService.GetSaleReturnByID(returnID, companyID)
	if err != nil {
		if err.Error() == "sale return not found" {
			utils.NotFoundResponse(c, "Sale return not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get sale return", err)
		return
	}

	utils.SuccessResponse(c, "Sale return retrieved successfully", saleReturn)
}

// POST /sale-returns
func (h *ReturnsHandler) CreateSaleReturn(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req models.CreateSaleReturnRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	// Validate request
	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	saleReturn, err := h.returnsService.CreateSaleReturn(companyID, userID, &req)
	if err != nil {
		if err.Error() == "sale not found" {
			utils.NotFoundResponse(c, "Sale not found")
			return
		}
		if err.Error() == "product not found in original sale" {
			utils.ErrorResponse(c, http.StatusBadRequest, "Product not found in original sale", err)
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create sale return", err)
		return
	}

	utils.CreatedResponse(c, "Sale return created successfully", saleReturn)
}

// PUT /sale-returns/:id
func (h *ReturnsHandler) UpdateSaleReturn(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	returnID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid return ID", err)
		return
	}

	var updates map[string]interface{}
	if err := c.ShouldBindJSON(&updates); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	err = h.returnsService.UpdateSaleReturn(returnID, companyID, userID, updates)
	if err != nil {
		if err.Error() == "return not found" {
			utils.NotFoundResponse(c, "Sale return not found")
			return
		}
		if err.Error() == "completed returns cannot be updated" {
			utils.ErrorResponse(c, http.StatusBadRequest, "Completed returns cannot be updated", err)
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update sale return", err)
		return
	}

	utils.SuccessResponse(c, "Sale return updated successfully", nil)
}

// DELETE /sale-returns/:id
func (h *ReturnsHandler) DeleteSaleReturn(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	returnID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid return ID", err)
		return
	}

	err = h.returnsService.DeleteSaleReturn(returnID, companyID, userID)
	if err != nil {
		if err.Error() == "return not found" {
			utils.NotFoundResponse(c, "Sale return not found")
			return
		}
		if err.Error() == "completed returns cannot be deleted" {
			utils.ErrorResponse(c, http.StatusBadRequest, "Completed returns cannot be deleted", err)
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete sale return", err)
		return
	}

	utils.SuccessResponse(c, "Sale return deleted successfully", nil)
}

// GET /sale-returns/summary
func (h *ReturnsHandler) GetReturnsSummary(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	dateFrom := c.Query("date_from")
	dateTo := c.Query("date_to")

	summary, err := h.returnsService.GetReturnsSummary(companyID, dateFrom, dateTo)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get returns summary", err)
		return
	}

	utils.SuccessResponse(c, "Returns summary retrieved successfully", summary)
}

// GET /sale-returns/search/:sale_id
func (h *ReturnsHandler) SearchReturnableSale(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	saleID, err := strconv.Atoi(c.Param("sale_id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid sale ID", err)
		return
	}

	// Use the sales service to get sale details
	salesService := services.NewSalesService()
	sale, err := salesService.GetSaleByID(saleID, companyID)
	if err != nil {
		if err.Error() == "sale not found" {
			utils.NotFoundResponse(c, "Sale not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get sale", err)
		return
	}

	// Check if sale is eligible for returns
	if sale.Status != "COMPLETED" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Only completed sales can be returned", nil)
		return
	}

	returnedQty, err := h.returnsService.GetReturnedQuantitiesBySaleDetail(saleID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get returned quantities", err)
		return
	}

	// Format response for return creation
	returnableItems := make([]map[string]interface{}, 0)
	for _, item := range sale.Items {
		if item.ProductID != nil {
			returned := returnedQty[item.SaleDetailID]
			maxQuantity := item.Quantity - returned
			if maxQuantity < 0 {
				maxQuantity = 0
			}
			returnableItems = append(returnableItems, map[string]interface{}{
				"product_id":   *item.ProductID,
				"product_name": item.ProductName,
				"quantity":     item.Quantity,
				"unit_price":   item.UnitPrice,
				"line_total":   item.LineTotal,
				"max_quantity": maxQuantity,
			})
		}
	}

	response := map[string]interface{}{
		"sale_id":          sale.SaleID,
		"sale_number":      sale.SaleNumber,
		"sale_date":        sale.SaleDate,
		"customer":         sale.Customer,
		"total_amount":     sale.TotalAmount,
		"returnable_items": returnableItems,
	}

	utils.SuccessResponse(c, "Returnable sale details retrieved successfully", response)
}

// POST /sale-returns/process/:sale_id (Quick return processing)
func (h *ReturnsHandler) ProcessQuickReturn(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	saleID, err := strconv.Atoi(c.Param("sale_id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid sale ID", err)
		return
	}

	var req struct {
		Items  []models.CreateSaleReturnItemRequest `json:"items" validate:"required,min=1"`
		Reason *string                              `json:"reason,omitempty"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	// Validate request
	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	// Create return request
	returnReq := &models.CreateSaleReturnRequest{
		SaleID: saleID,
		Items:  req.Items,
		Reason: req.Reason,
	}

	saleReturn, err := h.returnsService.CreateSaleReturn(companyID, userID, returnReq)
	if err != nil {
		if err.Error() == "sale not found" {
			utils.NotFoundResponse(c, "Sale not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to process return", err)
		return
	}

	utils.CreatedResponse(c, "Return processed successfully", saleReturn)
}
