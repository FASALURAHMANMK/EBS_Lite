package handlers

import (
	"errors"
	"io"
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type SalesHandler struct {
	salesService *services.SalesService
}

func NewSalesHandler() *SalesHandler {
	return &SalesHandler{
		salesService: services.NewSalesService(),
	}
}

// GET /sales
func (h *SalesHandler) GetSales(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	// Use location from context or query parameter
	if locationParam := c.Query("location_id"); locationParam != "" {
		if id, err := strconv.Atoi(locationParam); err == nil {
			locationID = id
		}
	}

	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
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
	if status := c.Query("status"); status != "" {
		filters["status"] = status
	}
	if transactionType := c.Query("transaction_type"); transactionType != "" {
		filters["transaction_type"] = transactionType
	}

	sales, err := h.salesService.GetSales(companyID, locationID, filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get sales", err)
		return
	}

	utils.SuccessResponse(c, "Sales retrieved successfully", sales)
}

// GET /sales/:id
func (h *SalesHandler) GetSale(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	saleID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid sale ID", err)
		return
	}

	sale, err := h.salesService.GetSaleByID(saleID, companyID)
	if err != nil {
		if err.Error() == "sale not found" {
			utils.NotFoundResponse(c, "Sale not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get sale", err)
		return
	}

	utils.SuccessResponse(c, "Sale retrieved successfully", sale)
}

// POST /sales
func (h *SalesHandler) CreateSale(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	// Use location from context or request body
	if locationParam := c.Query("location_id"); locationParam != "" {
		if id, err := strconv.Atoi(locationParam); err == nil {
			locationID = id
		}
	}

	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	var req models.CreateSaleRequest
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

	// Calculate totals to validate paid amount
	_, _, totalAmount, err := h.salesService.CalculateTotals(companyID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to calculate totals", err)
		return
	}

	if req.PaidAmount < 0 {
		utils.ValidationErrorResponse(c, map[string]string{"paid_amount": "must be non-negative"})
		return
	}
	if req.PaidAmount > totalAmount {
		utils.ValidationErrorResponse(c, map[string]string{"paid_amount": "cannot exceed total_amount"})
		return
	}

	sale, err := h.salesService.CreateSale(companyID, locationID, userID, &req, nil)
	if err != nil {
		var approvalErr *services.NegativeStockApprovalRequiredError
		if errors.As(err, &approvalErr) {
			utils.JSONResponse(c, http.StatusForbidden, false, approvalErr.Error(), gin.H{
				"code": "NEGATIVE_STOCK_APPROVAL_REQUIRED",
			}, nil)
			return
		}
		var profitApprovalErr *services.NegativeProfitApprovalRequiredError
		if errors.As(err, &profitApprovalErr) {
			utils.JSONResponse(c, http.StatusForbidden, false, profitApprovalErr.Error(), gin.H{
				"code":    "NEGATIVE_PROFIT_APPROVAL_REQUIRED",
				"details": profitApprovalErr.Details,
			}, nil)
			return
		}
		var profitBlockedErr *services.NegativeProfitNotAllowedError
		if errors.As(err, &profitBlockedErr) {
			utils.JSONResponse(c, http.StatusBadRequest, false, profitBlockedErr.Error(), gin.H{
				"code":    "NEGATIVE_PROFIT_NOT_ALLOWED",
				"details": profitBlockedErr.Details,
			}, nil)
			return
		}
		if err.Error() == "customer not found" {
			utils.NotFoundResponse(c, "Customer not found")
			return
		}
		if err.Error() == "b2b transactions require customer_id" || err.Error() == "invalid transaction_type" {
			utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create sale", err)
			return
		}
		if err.Error() == "paid amount cannot exceed total amount" {
			utils.ValidationErrorResponse(c, map[string]string{"paid_amount": "cannot exceed total_amount"})
			return
		}
		if err.Error() == "paid amount cannot be negative" {
			utils.ValidationErrorResponse(c, map[string]string{"paid_amount": "must be non-negative"})
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create sale", err)
		return
	}

	utils.CreatedResponse(c, "Sale created successfully", sale)
}

// PUT /sales/:id
func (h *SalesHandler) UpdateSale(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	saleID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid sale ID", err)
		return
	}

	var req models.UpdateSaleRequest
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

	err = h.salesService.UpdateSale(saleID, companyID, userID, &req)
	if err != nil {
		if err.Error() == "sale not found" {
			utils.NotFoundResponse(c, "Sale not found")
			return
		}
		if err.Error() == "sales action password is not configured for this user" ||
			err.Error() == "sales action password is required" {
			utils.ErrorResponse(c, http.StatusForbidden, "Failed to update sale", err)
			return
		}
		if err.Error() == "invalid sales action password" {
			utils.ErrorResponse(c, http.StatusUnauthorized, "Failed to update sale", err)
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update sale", err)
		return
	}

	utils.SuccessResponse(c, "Sale updated successfully", nil)
}

// POST /sales/:id/refund-invoice
func (h *SalesHandler) CreateRefundInvoice(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	saleID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid sale ID", err)
		return
	}

	var req models.CreateRefundInvoiceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	refundSale, err := h.salesService.CreateRefundInvoice(companyID, saleID, userID, &req)
	if err != nil {
		switch err.Error() {
		case "sale not found":
			utils.NotFoundResponse(c, "Sale not found")
			return
		case "sales action password is not configured for this user", "sales action password is required":
			utils.ErrorResponse(c, http.StatusForbidden, "Failed to create refund invoice", err)
			return
		case "invalid sales action password":
			utils.ErrorResponse(c, http.StatusUnauthorized, "Failed to create refund invoice", err)
			return
		case "invoice returns must use sale return documents", "pos sales must be refunded as refund invoices", "only completed sales can be refunded":
			utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create refund invoice", err)
			return
		default:
			utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create refund invoice", err)
			return
		}
	}

	utils.CreatedResponse(c, "Refund invoice created successfully", refundSale)
}

// GET /sales/:id/refundable-items
func (h *SalesHandler) GetRefundableItems(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	saleID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid sale ID", err)
		return
	}

	sale, err := h.salesService.GetSaleByID(saleID, companyID)
	if err != nil {
		if err.Error() == "sale not found" {
			utils.NotFoundResponse(c, "Sale not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get sale", err)
		return
	}

	if sale.Status != "COMPLETED" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Only completed sales can be refunded", nil)
		return
	}
	if sale.RefundSourceID != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Refund invoices cannot be refunded again", nil)
		return
	}

	returnedQty, err := services.NewReturnsService().GetReturnedQuantitiesBySaleDetail(companyID, saleID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get refunded quantities", err)
		return
	}

	refundableItems := make([]map[string]interface{}, 0)
	for _, item := range sale.Items {
		if item.ProductID == nil || item.Quantity <= 0 {
			continue
		}
		returned := returnedQty[item.SaleDetailID]
		maxQuantity := item.Quantity - returned
		if maxQuantity < 0 {
			maxQuantity = 0
		}
		refundableItems = append(refundableItems, map[string]interface{}{
			"sale_detail_id": item.SaleDetailID,
			"product_id":     *item.ProductID,
			"product_name":   item.ProductName,
			"barcode_id":     item.BarcodeID,
			"tracking_type":  item.TrackingType,
			"is_serialized":  item.IsSerialized,
			"serial_numbers": item.SerialNumbers,
			"quantity":       item.Quantity,
			"unit_price":     item.UnitPrice,
			"line_total":     item.LineTotal,
			"max_quantity":   maxQuantity,
		})
	}

	utils.SuccessResponse(c, "Refundable sale details retrieved successfully", map[string]interface{}{
		"sale_id":            sale.SaleID,
		"sale_number":        sale.SaleNumber,
		"sale_date":          sale.SaleDate,
		"customer":           sale.Customer,
		"total_amount":       sale.TotalAmount,
		"refundable_items":   refundableItems,
		"refund_source_sale": sale.RefundSourceID,
	})
}

// DELETE /sales/:id
func (h *SalesHandler) DeleteSale(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	saleID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid sale ID", err)
		return
	}

	err = h.salesService.DeleteSale(saleID, companyID, userID)
	if err != nil {
		if err.Error() == "sale not found" {
			utils.NotFoundResponse(c, "Sale not found")
			return
		}
		if err.Error() == "completed sales cannot be deleted" {
			utils.ErrorResponse(c, http.StatusBadRequest, "Completed sales cannot be deleted", err)
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete sale", err)
		return
	}

	utils.SuccessResponse(c, "Sale deleted successfully", nil)
}

// POST /sales/:id/hold
func (h *SalesHandler) HoldSale(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	saleID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid sale ID", err)
		return
	}

	err = h.salesService.HoldSale(saleID, companyID, userID)
	if err != nil {
		if err.Error() == "sale not found" {
			utils.NotFoundResponse(c, "Sale not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to hold sale", err)
		return
	}

	utils.SuccessResponse(c, "Sale held successfully", nil)
}

// POST /sales/:id/resume
func (h *SalesHandler) ResumeSale(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	saleID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid sale ID", err)
		return
	}

	err = h.salesService.ResumeSale(saleID, companyID, userID)
	if err != nil {
		if err.Error() == "sale not found" {
			utils.NotFoundResponse(c, "Sale not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to resume sale", err)
		return
	}

	utils.SuccessResponse(c, "Sale resumed successfully", nil)
}

// POST /sales/quick
func (h *SalesHandler) CreateQuickSale(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	// Use location from context or request body
	if locationParam := c.Query("location_id"); locationParam != "" {
		if id, err := strconv.Atoi(locationParam); err == nil {
			locationID = id
		}
	}

	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	var req models.QuickSaleRequest
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

	sale, err := h.salesService.CreateQuickSale(companyID, locationID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create quick sale", err)
		return
	}

	utils.CreatedResponse(c, "Quick sale created successfully", sale)
}

// GET /sales/history
func (h *SalesHandler) GetSalesHistory(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

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
	if productID := c.Query("product_id"); productID != "" {
		filters["product_id"] = productID
	}
	if paymentMethodID := c.Query("payment_method_id"); paymentMethodID != "" {
		filters["payment_method_id"] = paymentMethodID
	}
	if saleNumber := c.Query("sale_number"); saleNumber != "" {
		filters["sale_number"] = saleNumber
	}
	if transactionType := c.Query("transaction_type"); transactionType != "" {
		filters["transaction_type"] = transactionType
	}

	sales, err := h.salesService.GetSalesHistory(companyID, filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get sales history", err)
		return
	}

	utils.SuccessResponse(c, "Sales history retrieved successfully", sales)
}

// GET /sales/history/export
func (h *SalesHandler) ExportInvoices(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

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
	if productID := c.Query("product_id"); productID != "" {
		filters["product_id"] = productID
	}
	if paymentMethodID := c.Query("payment_method_id"); paymentMethodID != "" {
		filters["payment_method_id"] = paymentMethodID
	}
	if transactionType := c.Query("transaction_type"); transactionType != "" {
		filters["transaction_type"] = transactionType
	}

	invoices, err := h.salesService.ExportInvoices(companyID, filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to export invoices", err)
		return
	}

	utils.SuccessResponse(c, "Invoices exported successfully", invoices)
}

// GET /sales/quotes
func (h *SalesHandler) GetQuotes(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	filters := make(map[string]string)
	if status := c.Query("status"); status != "" {
		filters["status"] = status
	}
	if customerID := c.Query("customer_id"); customerID != "" {
		filters["customer_id"] = customerID
	}
	if dateFrom := c.Query("date_from"); dateFrom != "" {
		filters["date_from"] = dateFrom
	}
	if dateTo := c.Query("date_to"); dateTo != "" {
		filters["date_to"] = dateTo
	}
	if transactionType := c.Query("transaction_type"); transactionType != "" {
		filters["transaction_type"] = transactionType
	}

	quotes, err := h.salesService.GetQuotes(companyID, filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get quotes", err)
		return
	}

	utils.SuccessResponse(c, "Quotes retrieved successfully", quotes)
}

// GET /sales/quotes/:id
func (h *SalesHandler) GetQuote(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	quoteID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid quote ID", err)
		return
	}

	quote, err := h.salesService.GetQuoteByID(quoteID, companyID)
	if err != nil {
		if err.Error() == "quote not found" {
			utils.NotFoundResponse(c, "Quote not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get quote", err)
		return
	}

	utils.SuccessResponse(c, "Quote retrieved successfully", quote)
}

// POST /sales/quotes
func (h *SalesHandler) CreateQuote(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	if locationID == 0 {
		if val := c.Query("location_id"); val != "" {
			if id, err := strconv.Atoi(val); err == nil {
				locationID = id
			}
		}
	}
	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location access required", nil)
		return
	}

	var req models.CreateQuoteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	quote, err := h.salesService.CreateQuote(companyID, locationID, userID, &req)
	if err != nil {
		if err.Error() == "b2b quotes require customer_id" || err.Error() == "invalid transaction_type" {
			utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create quote", err)
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create quote", err)
		return
	}

	utils.CreatedResponse(c, "Quote created successfully", quote)
}

// PUT /sales/quotes/:id
func (h *SalesHandler) UpdateQuote(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	quoteID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid quote ID", err)
		return
	}

	var req models.UpdateQuoteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	if err := h.salesService.UpdateQuote(quoteID, companyID, userID, &req); err != nil {
		if err.Error() == "quote not found" {
			utils.NotFoundResponse(c, "Quote not found")
			return
		}
		if err.Error() == "b2b quotes require customer_id" || err.Error() == "invalid transaction_type" {
			utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update quote", err)
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update quote", err)
		return
	}

	utils.SuccessResponse(c, "Quote updated successfully", nil)
}

// DELETE /sales/quotes/:id
func (h *SalesHandler) DeleteQuote(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	quoteID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid quote ID", err)
		return
	}

	if err := h.salesService.DeleteQuote(quoteID, companyID); err != nil {
		if err.Error() == "quote not found" {
			utils.NotFoundResponse(c, "Quote not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete quote", err)
		return
	}

	utils.SuccessResponse(c, "Quote deleted successfully", nil)
}

// POST /sales/quotes/:id/print
func (h *SalesHandler) PrintQuote(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	quoteID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid quote ID", err)
		return
	}

	if err := h.salesService.PrintQuote(quoteID, companyID); err != nil {
		if err.Error() == "quote not found" {
			utils.NotFoundResponse(c, "Quote not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to print quote", err)
		return
	}

	utils.SuccessResponse(c, "Quote print initiated", nil)
}

// POST /sales/quotes/:id/share
func (h *SalesHandler) ShareQuote(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	quoteID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid quote ID", err)
		return
	}

	var req models.ShareQuoteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		if !errors.Is(err, io.EOF) {
			utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
			return
		}
	} else {
		if err := utils.ValidateStruct(&req); err != nil {
			validationErrors := utils.GetValidationErrors(err)
			utils.ValidationErrorResponse(c, validationErrors)
			return
		}
	}

	if err := h.salesService.ShareQuote(quoteID, companyID, &req); err != nil {
		if err.Error() == "quote not found" {
			utils.NotFoundResponse(c, "Quote not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to share quote", err)
		return
	}

	utils.SuccessResponse(c, "Quote shared successfully", nil)
}

// POST /sales/quotes/:id/print-data
func (h *SalesHandler) GetQuotePrintData(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	quoteID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid quote ID", err)
		return
	}

	data, err := h.salesService.GetQuotePrintData(quoteID, companyID)
	if err != nil {
		if err.Error() == "quote not found" {
			utils.NotFoundResponse(c, "Quote not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get quote print data", err)
		return
	}

	utils.SuccessResponse(c, "Quote print data retrieved successfully", data)
}

// POST /sales/quotes/:id/convert
func (h *SalesHandler) ConvertQuoteToSale(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	quoteID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid quote ID", err)
		return
	}

	var req models.ConvertQuoteToSaleRequest
	if err := c.ShouldBindJSON(&req); err != nil && !errors.Is(err, io.EOF) {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	sale, err := h.salesService.ConvertQuoteToSale(quoteID, companyID, userID, req.OverridePassword)
	if err != nil {
		var stockApprovalErr *services.NegativeStockApprovalRequiredError
		if errors.As(err, &stockApprovalErr) {
			utils.JSONResponse(c, http.StatusForbidden, false, stockApprovalErr.Error(), gin.H{
				"code": "NEGATIVE_STOCK_APPROVAL_REQUIRED",
			}, nil)
			return
		}
		var profitApprovalErr *services.NegativeProfitApprovalRequiredError
		if errors.As(err, &profitApprovalErr) {
			utils.JSONResponse(c, http.StatusForbidden, false, profitApprovalErr.Error(), gin.H{
				"code":    "NEGATIVE_PROFIT_APPROVAL_REQUIRED",
				"details": profitApprovalErr.Details,
			}, nil)
			return
		}
		var profitBlockedErr *services.NegativeProfitNotAllowedError
		if errors.As(err, &profitBlockedErr) {
			utils.JSONResponse(c, http.StatusBadRequest, false, profitBlockedErr.Error(), gin.H{
				"code":    "NEGATIVE_PROFIT_NOT_ALLOWED",
				"details": profitBlockedErr.Details,
			}, nil)
			return
		}
		switch err.Error() {
		case "quote not found":
			utils.NotFoundResponse(c, "Quote not found")
			return
		case "quote must be ACCEPTED before conversion", "quote has no items":
			utils.ErrorResponse(c, http.StatusBadRequest, "Failed to convert quote to sale", err)
			return
		default:
			utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to convert quote to sale", err)
			return
		}
	}

	utils.CreatedResponse(c, "Sale created from quote successfully", sale)
}

// GET /sales/quotes/export
func (h *SalesHandler) ExportQuotes(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	filters := make(map[string]string)
	if status := c.Query("status"); status != "" {
		filters["status"] = status
	}
	if customerID := c.Query("customer_id"); customerID != "" {
		filters["customer_id"] = customerID
	}
	if dateFrom := c.Query("date_from"); dateFrom != "" {
		filters["date_from"] = dateFrom
	}
	if dateTo := c.Query("date_to"); dateTo != "" {
		filters["date_to"] = dateTo
	}
	if transactionType := c.Query("transaction_type"); transactionType != "" {
		filters["transaction_type"] = transactionType
	}

	quotes, err := h.salesService.ExportQuotes(companyID, filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to export quotes", err)
		return
	}

	utils.SuccessResponse(c, "Quotes exported successfully", quotes)
}
