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

// handleReportResponse streams report data or exports it to Excel/PDF based on
// the requested format.
func (h *ReportsHandler) handleReportResponse(c *gin.Context, message string, data interface{}) {
	format := c.Query("format")
	switch format {
	case "excel":
		content, err := utils.GenerateExcel(data)
		if err != nil {
			utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to generate Excel", err)
			return
		}
		c.Header("Content-Disposition", "attachment; filename=report.xlsx")
		c.Data(http.StatusOK, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", content)
	case "pdf":
		content, err := utils.GeneratePDF(data)
		if err != nil {
			utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to generate PDF", err)
			return
		}
		c.Header("Content-Disposition", "attachment; filename=report.pdf")
		c.Data(http.StatusOK, "application/pdf", content)
	default:
		utils.SuccessResponse(c, message, data)
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

// GET /reports/item-movement
func (h *ReportsHandler) GetItemMovement(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	data, err := h.reportsService.GetItemMovement(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotImplemented, "Item movement report not implemented", err)
		return
	}
	h.handleReportResponse(c, "Item movement retrieved successfully", data)
}

// GET /reports/valuation
func (h *ReportsHandler) GetValuationReport(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	data, err := h.reportsService.GetValuationReport(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotImplemented, "Valuation report not implemented", err)
		return
	}
	h.handleReportResponse(c, "Valuation report retrieved successfully", data)
}

// GET /reports/purchase-vs-returns
func (h *ReportsHandler) GetPurchaseVsReturns(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	data, err := h.reportsService.GetPurchaseVsReturns(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotImplemented, "Purchase vs returns report not implemented", err)
		return
	}
	h.handleReportResponse(c, "Purchase vs returns retrieved successfully", data)
}

// GET /reports/supplier
func (h *ReportsHandler) GetSupplierReport(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	data, err := h.reportsService.GetSupplierReport(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotImplemented, "Supplier report not implemented", err)
		return
	}
	h.handleReportResponse(c, "Supplier report retrieved successfully", data)
}

// GET /reports/daily-cash
func (h *ReportsHandler) GetDailyCashReport(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	data, err := h.reportsService.GetDailyCashReport(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotImplemented, "Daily cash report not implemented", err)
		return
	}
	h.handleReportResponse(c, "Daily cash report retrieved successfully", data)
}

// GET /reports/income-expense
func (h *ReportsHandler) GetIncomeExpenseReport(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	data, err := h.reportsService.GetIncomeExpenseReport(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotImplemented, "Income vs expense report not implemented", err)
		return
	}
	h.handleReportResponse(c, "Income vs expense report retrieved successfully", data)
}

// GET /reports/general-ledger
func (h *ReportsHandler) GetGeneralLedger(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	data, err := h.reportsService.GetGeneralLedger(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotImplemented, "General ledger report not implemented", err)
		return
	}
	h.handleReportResponse(c, "General ledger retrieved successfully", data)
}

// GET /reports/trial-balance
func (h *ReportsHandler) GetTrialBalance(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	data, err := h.reportsService.GetTrialBalance(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotImplemented, "Trial balance report not implemented", err)
		return
	}
	h.handleReportResponse(c, "Trial balance retrieved successfully", data)
}

// GET /reports/profit-loss
func (h *ReportsHandler) GetProfitLoss(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	data, err := h.reportsService.GetProfitLoss(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotImplemented, "Profit and loss report not implemented", err)
		return
	}
	h.handleReportResponse(c, "Profit and loss report retrieved successfully", data)
}

// GET /reports/balance-sheet
func (h *ReportsHandler) GetBalanceSheet(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	data, err := h.reportsService.GetBalanceSheet(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotImplemented, "Balance sheet report not implemented", err)
		return
	}
	h.handleReportResponse(c, "Balance sheet report retrieved successfully", data)
}

// GET /reports/outstanding
func (h *ReportsHandler) GetOutstandingReport(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	data, err := h.reportsService.GetOutstandingReport(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotImplemented, "Outstanding report not implemented", err)
		return
	}
	h.handleReportResponse(c, "Outstanding report retrieved successfully", data)
}

// GET /reports/top-performers
func (h *ReportsHandler) GetTopPerformers(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	data, err := h.reportsService.GetTopPerformers(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotImplemented, "Top performers report not implemented", err)
		return
	}
	h.handleReportResponse(c, "Top performers report retrieved successfully", data)
}
