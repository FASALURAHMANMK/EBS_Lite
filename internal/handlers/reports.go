package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

// ReportsHandler handles report related endpoints
type ReportsHandler struct {
	reportsService *services.ReportsService
}

// NewReportsHandler creates a new ReportsHandler
func NewReportsHandler() *ReportsHandler {
	return &ReportsHandler{
		reportsService: services.NewReportsService(),
	}
}

// GET /reports/sales-summary
func (h *ReportsHandler) GetSalesSummary(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	groupBy := c.Query("group_by")
	if groupBy == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "group_by is required", nil)
		return
	}

	fromDate := c.Query("from_date")
	toDate := c.Query("to_date")

	summary, err := h.reportsService.GetSalesSummary(companyID, fromDate, toDate, groupBy)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get sales summary", err)
		return
	}

	utils.SuccessResponse(c, "Sales summary retrieved successfully", summary)
}

// GET /reports/stock-summary
func (h *ReportsHandler) GetStockSummary(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var locationID *int
	if val := c.Query("location_id"); val != "" {
		if id, err := strconv.Atoi(val); err == nil {
			locationID = &id
		}
	}

	var productID *int
	if val := c.Query("product_id"); val != "" {
		if id, err := strconv.Atoi(val); err == nil {
			productID = &id
		}
	}

	summary, err := h.reportsService.GetStockSummary(companyID, locationID, productID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get stock summary", err)
		return
	}

	utils.SuccessResponse(c, "Stock summary retrieved successfully", summary)
}

// GET /reports/top-products
func (h *ReportsHandler) GetTopProducts(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	fromDate := c.Query("from_date")
	toDate := c.Query("to_date")

	limit := 10
	if val := c.Query("limit"); val != "" {
		if l, err := strconv.Atoi(val); err == nil {
			limit = l
		}
	}

	products, err := h.reportsService.GetTopProducts(companyID, fromDate, toDate, limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get top products", err)
		return
	}

	utils.SuccessResponse(c, "Top products retrieved successfully", products)
}

// GET /reports/customer-balances
func (h *ReportsHandler) GetCustomerBalances(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	balances, err := h.reportsService.GetCustomerBalances(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get customer balances", err)
		return
	}

	utils.SuccessResponse(c, "Customer balances retrieved successfully", balances)
}

// GET /reports/expenses-summary
func (h *ReportsHandler) GetExpensesSummary(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	groupBy := c.Query("group_by")

	summary, err := h.reportsService.GetExpensesSummary(companyID, groupBy)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get expenses summary", err)
		return
	}

	utils.SuccessResponse(c, "Expenses summary retrieved successfully", summary)
}
