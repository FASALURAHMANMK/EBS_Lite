package handlers

import (
	"fmt"
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
	endpoint := c.FullPath()
	switch format {
	case "excel":
		content, err := utils.GenerateExcel(endpoint, data)
		if err != nil {
			utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to generate Excel", err)
			return
		}
		c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%s", utils.ReportExportFilename(endpoint, "xlsx")))
		c.Data(http.StatusOK, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", content)
	case "pdf":
		content, err := utils.GeneratePDF(endpoint, data)
		if err != nil {
			utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to generate PDF", err)
			return
		}
		c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%s", utils.ReportExportFilename(endpoint, "pdf")))
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

	h.handleReportResponse(c, "Sales summary retrieved successfully", summary)
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

	h.handleReportResponse(c, "Stock summary retrieved successfully", summary)
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

	h.handleReportResponse(c, "Top products retrieved successfully", products)
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

	h.handleReportResponse(c, "Customer balances retrieved successfully", balances)
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

	h.handleReportResponse(c, "Expenses summary retrieved successfully", summary)
}

// GET /reports/item-movement
func (h *ReportsHandler) GetItemMovement(c *gin.Context) {
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
	fromDate := c.Query("from_date")
	toDate := c.Query("to_date")

	data, err := h.reportsService.GetItemMovement(companyID, locationID, fromDate, toDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get item movement report", err)
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
	var locationID *int
	if val := c.Query("location_id"); val != "" {
		if id, err := strconv.Atoi(val); err == nil {
			locationID = &id
		}
	}
	data, err := h.reportsService.GetValuationReport(companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get valuation report", err)
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

	var locationID *int
	if val := c.Query("location_id"); val != "" {
		if id, err := strconv.Atoi(val); err == nil {
			locationID = &id
		}
	}
	fromDate := c.Query("from_date")
	toDate := c.Query("to_date")

	data, err := h.reportsService.GetPurchaseVsReturns(companyID, locationID, fromDate, toDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get purchase vs returns report", err)
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
	var locationID *int
	if val := c.Query("location_id"); val != "" {
		if id, err := strconv.Atoi(val); err == nil {
			locationID = &id
		}
	}
	fromDate := c.Query("from_date")
	toDate := c.Query("to_date")

	data, err := h.reportsService.GetSupplierReport(companyID, locationID, fromDate, toDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get supplier report", err)
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
	var locationID *int
	if val := c.Query("location_id"); val != "" {
		if id, err := strconv.Atoi(val); err == nil {
			locationID = &id
		}
	}
	fromDate := c.Query("from_date")
	toDate := c.Query("to_date")

	data, err := h.reportsService.GetDailyCashReport(companyID, locationID, fromDate, toDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get daily cash report", err)
		return
	}
	h.handleReportResponse(c, "Daily cash report retrieved successfully", data)
}

// GET /reports/cash-book
func (h *ReportsHandler) GetCashBookReport(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	fromDate := c.Query("from_date")
	toDate := c.Query("to_date")
	data, err := h.reportsService.GetCashBookReport(companyID, nil, fromDate, toDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get cash book report", err)
		return
	}
	h.handleReportResponse(c, "Cash book report retrieved successfully", data)
}

// GET /reports/bank-book
func (h *ReportsHandler) GetBankBookReport(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var bankAccountID *int
	if val := c.Query("bank_account_id"); val != "" {
		if id, err := strconv.Atoi(val); err == nil {
			bankAccountID = &id
		}
	}
	fromDate := c.Query("from_date")
	toDate := c.Query("to_date")
	data, err := h.reportsService.GetBankBookReport(companyID, bankAccountID, fromDate, toDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get bank book report", err)
		return
	}
	h.handleReportResponse(c, "Bank book report retrieved successfully", data)
}

// GET /reports/reconciliation-summary
func (h *ReportsHandler) GetReconciliationSummaryReport(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var bankAccountID *int
	if val := c.Query("bank_account_id"); val != "" {
		if id, err := strconv.Atoi(val); err == nil {
			bankAccountID = &id
		}
	}
	fromDate := c.Query("from_date")
	toDate := c.Query("to_date")
	data, err := h.reportsService.GetReconciliationSummaryReport(companyID, bankAccountID, fromDate, toDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get reconciliation summary report", err)
		return
	}
	h.handleReportResponse(c, "Reconciliation summary report retrieved successfully", data)
}

// GET /reports/income-expense
func (h *ReportsHandler) GetIncomeExpenseReport(c *gin.Context) {
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
	fromDate := c.Query("from_date")
	toDate := c.Query("to_date")

	data, err := h.reportsService.GetIncomeExpenseReport(companyID, locationID, fromDate, toDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get income vs expense report", err)
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
	fromDate := c.Query("from_date")
	toDate := c.Query("to_date")
	limit := 500
	if val := c.Query("limit"); val != "" {
		if l, err := strconv.Atoi(val); err == nil {
			limit = l
		}
	}

	data, err := h.reportsService.GetGeneralLedger(companyID, fromDate, toDate, limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get general ledger report", err)
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
	fromDate := c.Query("from_date")
	toDate := c.Query("to_date")

	data, err := h.reportsService.GetTrialBalance(companyID, fromDate, toDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get trial balance report", err)
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
	fromDate := c.Query("from_date")
	toDate := c.Query("to_date")

	data, err := h.reportsService.GetProfitLoss(companyID, fromDate, toDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get profit and loss report", err)
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
	asOfDate := c.Query("as_of_date")
	if asOfDate == "" {
		asOfDate = c.Query("to_date")
	}

	data, err := h.reportsService.GetBalanceSheet(companyID, asOfDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get balance sheet report", err)
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
	var locationID *int
	if val := c.Query("location_id"); val != "" {
		if id, err := strconv.Atoi(val); err == nil {
			locationID = &id
		}
	}

	data, err := h.reportsService.GetOutstandingReport(companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get outstanding report", err)
		return
	}
	h.handleReportResponse(c, "Outstanding report retrieved successfully", data)
}

// GET /reports/tax
func (h *ReportsHandler) GetTaxReport(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	fromDate := c.Query("from_date")
	toDate := c.Query("to_date")

	data, err := h.reportsService.GetTaxReport(companyID, fromDate, toDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get tax report", err)
		return
	}
	h.handleReportResponse(c, "Tax report retrieved successfully", data)
}

// GET /reports/tax-review
func (h *ReportsHandler) GetTaxReviewReport(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	fromDate := c.Query("from_date")
	toDate := c.Query("to_date")
	data, err := h.reportsService.GetTaxReviewReport(companyID, fromDate, toDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get tax review report", err)
		return
	}
	h.handleReportResponse(c, "Tax review report retrieved successfully", data)
}

// GET /reports/top-performers
func (h *ReportsHandler) GetTopPerformers(c *gin.Context) {
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

	data, err := h.reportsService.GetTopPerformers(companyID, fromDate, toDate, limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get top performers report", err)
		return
	}
	h.handleReportResponse(c, "Top performers report retrieved successfully", data)
}

func (h *ReportsHandler) GetAssetRegisterReport(c *gin.Context) {
	companyID := c.GetInt("company_id")
	var locationID *int
	if val := c.Query("location_id"); val != "" {
		if id, err := strconv.Atoi(val); err == nil {
			locationID = &id
		}
	}
	data, err := h.reportsService.GetAssetRegisterReport(companyID, locationID, c.Query("from_date"), c.Query("to_date"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get asset register report", err)
		return
	}
	h.handleReportResponse(c, "Asset register report retrieved successfully", data)
}

func (h *ReportsHandler) GetAssetValueSummaryReport(c *gin.Context) {
	companyID := c.GetInt("company_id")
	var locationID *int
	if val := c.Query("location_id"); val != "" {
		if id, err := strconv.Atoi(val); err == nil {
			locationID = &id
		}
	}
	data, err := h.reportsService.GetAssetValueSummary(companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get asset value summary report", err)
		return
	}
	h.handleReportResponse(c, "Asset value summary report retrieved successfully", data)
}

func (h *ReportsHandler) GetConsumableConsumptionReport(c *gin.Context) {
	companyID := c.GetInt("company_id")
	var locationID *int
	if val := c.Query("location_id"); val != "" {
		if id, err := strconv.Atoi(val); err == nil {
			locationID = &id
		}
	}
	data, err := h.reportsService.GetConsumableConsumptionReport(companyID, locationID, c.Query("from_date"), c.Query("to_date"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get consumable consumption report", err)
		return
	}
	h.handleReportResponse(c, "Consumable consumption report retrieved successfully", data)
}

func (h *ReportsHandler) GetConsumableBalanceReport(c *gin.Context) {
	companyID := c.GetInt("company_id")
	var locationID *int
	if val := c.Query("location_id"); val != "" {
		if id, err := strconv.Atoi(val); err == nil {
			locationID = &id
		}
	}
	data, err := h.reportsService.GetConsumableBalanceReport(companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get consumable balance report", err)
		return
	}
	h.handleReportResponse(c, "Consumable balance report retrieved successfully", data)
}
