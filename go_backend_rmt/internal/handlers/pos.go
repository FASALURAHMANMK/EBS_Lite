package handlers

import (
	"errors"
	"log"
	"net/http"
	"strconv"
	"strings"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type POSHandler struct {
	posService      *services.POSService
	settingsService *services.SettingsService
}

func NewPOSHandler() *POSHandler {
	return &POSHandler{
		posService:      services.NewPOSService(),
		settingsService: services.NewSettingsService(),
	}
}

// GET /pos/products
func (h *POSHandler) GetPOSProducts(c *gin.Context) {
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

	includeCombos := true
	if raw := c.Query("include_combo_products"); raw != "" {
		includeCombos = raw != "false" && raw != "0"
	}

	// Check if it's a search request
	if searchTerm := c.Query("search"); searchTerm != "" {
		products, err := h.posService.SearchProducts(companyID, locationID, searchTerm, includeCombos)
		if err != nil {
			utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to search products", err)
			return
		}
		utils.SuccessResponse(c, "Products search completed", products)
		return
	}

	products, err := h.posService.GetPOSProducts(companyID, locationID, includeCombos)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get POS products", err)
		return
	}

	utils.SuccessResponse(c, "POS products retrieved successfully", products)
}

// GET /pos/customers
func (h *POSHandler) GetPOSCustomers(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	// Check if it's a search request
	customerType := c.Query("customer_type")
	if searchTerm := c.Query("search"); searchTerm != "" {
		customers, err := h.posService.SearchCustomers(companyID, searchTerm, customerType)
		if err != nil {
			utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to search customers", err)
			return
		}
		utils.SuccessResponse(c, "Customer search completed", customers)
		return
	}

	customers, err := h.posService.GetPOSCustomers(companyID, customerType)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get POS customers", err)
		return
	}

	utils.SuccessResponse(c, "POS customers retrieved successfully", customers)
}

// POST /pos/checkout
func (h *POSHandler) ProcessCheckout(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")

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

	var req models.POSCheckoutRequest
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

	idemKey := c.GetHeader("Idempotency-Key")
	if idemKey == "" {
		idemKey = c.GetHeader("X-Idempotency-Key")
	}

	sale, err := h.posService.ProcessCheckout(companyID, locationID, userID, &req, idemKey)
	if err != nil {
		var ov *services.OverrideRequiredError
		if errors.As(err, &ov) {
			utils.JSONResponse(c, http.StatusForbidden, false, ov.Error(), gin.H{
				"code":                 "OVERRIDE_REQUIRED",
				"required_permissions": ov.RequiredPermissions,
				"reason_required":      ov.ReasonRequired,
			}, nil)
			return
		}
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
		var cl *services.CreditLimitExceededError
		if errors.As(err, &cl) {
			utils.JSONResponse(c, http.StatusBadRequest, false, "Credit limit exceeded", gin.H{
				"code":             "CREDIT_LIMIT_EXCEEDED",
				"credit_limit":     cl.CreditLimit,
				"current_outstand": cl.CurrentBalance,
				"attempted_new":    cl.AttemptedDelta,
			}, nil)
			return
		}
		if err.Error() == "customer not found" {
			utils.NotFoundResponse(c, "Customer not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to process checkout", err)
		return
	}

	if idemKey != "" {
		requestID := c.GetString("request_id")
		if requestID == "" {
			requestID = c.GetHeader("X-Request-ID")
		}
		log.Printf("request_id=%s idempotency_key=%s sale_id=%d", requestID, idemKey, sale.SaleID)
	}

	utils.CreatedResponse(c, "Checkout completed successfully", map[string]interface{}{
		"sale":       sale,
		"invoice_id": sale.SaleID,
	})
}

// PUT /pos/sales/:id
func (h *POSHandler) EditSale(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	if locationParam := c.Query("location_id"); locationParam != "" {
		if id, err := strconv.Atoi(locationParam); err == nil {
			locationID = id
		}
	}
	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	saleID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid sale ID", err)
		return
	}

	var req models.POSEditSaleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	requestID := c.GetString("request_id")
	if requestID == "" {
		requestID = c.GetHeader("X-Request-ID")
	}

	sale, err := h.posService.EditCompletedSale(companyID, locationID, userID, saleID, &req, requestID)
	if err != nil {
		var ov *services.OverrideRequiredError
		if errors.As(err, &ov) {
			utils.JSONResponse(c, http.StatusForbidden, false, ov.Error(), gin.H{
				"code":                 "OVERRIDE_REQUIRED",
				"required_permissions": ov.RequiredPermissions,
				"reason_required":      ov.ReasonRequired,
			}, nil)
			return
		}
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
		var cl *services.CreditLimitExceededError
		if errors.As(err, &cl) {
			utils.JSONResponse(c, http.StatusBadRequest, false, "Credit limit exceeded", gin.H{
				"code":             "CREDIT_LIMIT_EXCEEDED",
				"credit_limit":     cl.CreditLimit,
				"current_outstand": cl.CurrentBalance,
				"attempted_new":    cl.AttemptedDelta,
			}, nil)
			return
		}
		switch err.Error() {
		case "sale not found":
			utils.NotFoundResponse(c, "Sale not found")
			return
		case "invalid transaction_type", "transaction_type mismatch for sale edit":
			utils.ErrorResponse(c, http.StatusBadRequest, "Failed to edit sale", err)
			return
		case "sales action password is not configured for this user", "sales action password is required":
			utils.ErrorResponse(c, http.StatusForbidden, "Failed to edit sale", err)
			return
		case "invalid sales action password":
			utils.ErrorResponse(c, http.StatusUnauthorized, "Failed to edit sale", err)
			return
		case "sale has changed since the edit session started":
			utils.ErrorResponse(c, http.StatusConflict, "Failed to edit sale", err)
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to edit sale", err)
		return
	}

	utils.SuccessResponse(c, "Sale updated successfully", map[string]interface{}{
		"sale":       sale,
		"invoice_id": sale.SaleID,
	})
}

// POST /pos/numbering/reserve
func (h *POSHandler) ReserveNumberBlock(c *gin.Context) {
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

	var req models.ReserveNumberBlockRequest
	// Accept empty body; defaults will apply.
	_ = c.ShouldBindJSON(&req)

	sequence := strings.TrimSpace(req.SequenceName)
	if sequence == "" {
		sequence = "sale"
	}
	if sequence != "sale" && sequence != "sale_training" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Unsupported sequence for POS numbering reservation", nil)
		return
	}

	ns := services.NewNumberingSequenceService()
	resp, err := ns.ReserveNumberBlock(sequence, companyID, &locationID, req.BlockSize)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to reserve numbering block", err)
		return
	}
	utils.SuccessResponse(c, "Numbering block reserved", resp)
}

// POST /pos/print
func (h *POSHandler) PrintInvoice(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req models.POSPrintRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	// Require either invoice_id or sale_number
	if (req.InvoiceID == nil || *req.InvoiceID == 0) && (req.SaleNumber == nil || *req.SaleNumber == "") {
		utils.ErrorResponse(c, http.StatusBadRequest, "invoice_id or sale_number is required", nil)
		return
	}

	// Resolve sale
	salesSvc := services.NewSalesService()
	var sale *models.Sale
	var err error
	if req.InvoiceID != nil && *req.InvoiceID > 0 {
		sale, err = salesSvc.GetSaleByID(*req.InvoiceID, companyID)
	} else if req.SaleNumber != nil {
		sale, err = salesSvc.GetSaleByNumber(*req.SaleNumber, companyID)
	}
	if err != nil {
		if err.Error() == "sale not found" {
			utils.NotFoundResponse(c, "Invoice not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to get invoice", err)
		return
	}

	// Company details for header/branding
	companySvc := services.NewCompanyService()
	company, err := companySvc.GetCompanyByID(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to load company", err)
		return
	}

	raffleCoupons, err := services.NewLoyaltyService().GetRaffleCoupons(companyID, nil, &sale.SaleID)
	if err != nil {
		raffleCoupons = nil
	}

	utils.SuccessResponse(c, "Print data", models.POSPrintDataResponse{
		Sale:          *sale,
		Company:       *company,
		RaffleCoupons: raffleCoupons,
	})
}

// GET /pos/held-sales
func (h *POSHandler) GetHeldSales(c *gin.Context) {
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

	sales, err := h.posService.GetHeldSales(companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get held sales", err)
		return
	}

	utils.SuccessResponse(c, "Held sales retrieved successfully", sales)
}

// GET /pos/payment-methods
func (h *POSHandler) GetPaymentMethods(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	methods, err := h.posService.GetPaymentMethods(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get payment methods", err)
		return
	}

	utils.SuccessResponse(c, "Payment methods retrieved successfully", methods)
}

// GET /pos/payment-methods/currencies
func (h *POSHandler) GetPaymentMethodCurrencies(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	mappings, err := h.settingsService.GetPaymentMethodCurrencies(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get payment method currencies", err)
		return
	}

	utils.SuccessResponse(c, "Payment method currencies retrieved successfully", mappings)
}

// GET /pos/sales-summary
func (h *POSHandler) GetSalesSummary(c *gin.Context) {
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

	dateFrom := c.Query("date_from")
	dateTo := c.Query("date_to")

	summary, err := h.posService.GetSalesSummary(companyID, locationID, dateFrom, dateTo)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get sales summary", err)
		return
	}

	utils.SuccessResponse(c, "Sales summary retrieved successfully", summary)
}

// GET /pos/receipt/:id
func (h *POSHandler) GetReceiptData(c *gin.Context) {
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

	// Use the sales service to get the sale details for receipt
	salesService := services.NewSalesService()
	sale, err := salesService.GetSaleByID(saleID, companyID)
	if err != nil {
		if err.Error() == "sale not found" {
			utils.NotFoundResponse(c, "Sale not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get sale for receipt", err)
		return
	}

	// Format response for receipt printing
	receiptData := map[string]interface{}{
		"sale_id":        sale.SaleID,
		"sale_number":    sale.SaleNumber,
		"sale_date":      sale.SaleDate,
		"sale_time":      sale.SaleTime,
		"items":          sale.Items,
		"subtotal":       sale.Subtotal,
		"tax_amount":     sale.TaxAmount,
		"discount":       sale.DiscountAmount,
		"total":          sale.TotalAmount,
		"customer":       sale.Customer,
		"payment_method": sale.PaymentMethod,
	}

	utils.SuccessResponse(c, "Receipt data retrieved successfully", receiptData)
}

// POST /pos/void/:id
// Creates a VOID invoice document using the next sale number. If the original
// sale is COMPLETED, this void invoice will contain negative item lines to
// reverse stock and amounts. If the original is DRAFT/HELD, a zero-total VOID
// document is created just to record the void event and advance numbering.
func (h *POSHandler) VoidSale(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	if loc := c.Query("location_id"); loc != "" {
		if id, err := strconv.Atoi(loc); err == nil {
			locationID = id
		}
	}
	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	saleID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid sale ID", err)
		return
	}

	var body models.POSVoidRequest
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&body); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	reason := strings.TrimSpace(body.Reason)
	if reason == "" {
		utils.ValidationErrorResponse(c, map[string]string{"reason": "Reason is required"})
		return
	}

	idemKey := c.GetHeader("Idempotency-Key")
	if idemKey == "" {
		idemKey = c.GetHeader("X-Idempotency-Key")
	}

	// Enforce void permission server-side; allow manager override token as approval.
	permSvc := services.NewPermissionService()
	hasVoid, err := permSvc.UserHasPermission(userID, "DELETE_SALES")
	if err != nil {
		utils.InternalServerErrorResponse(c, "Failed to check permissions", err)
		return
	}

	var approverID *int
	if !hasVoid {
		token := ""
		if body.ManagerOverrideToken != nil {
			token = strings.TrimSpace(*body.ManagerOverrideToken)
		}
		if token == "" {
			utils.JSONResponse(c, http.StatusForbidden, false, "Manager override required", gin.H{
				"code":                 "OVERRIDE_REQUIRED",
				"required_permissions": []string{"DELETE_SALES"},
				"reason_required":      true,
			}, nil)
			return
		}
		ctx, err := services.ValidateOverrideToken(token, companyID, []string{"DELETE_SALES"})
		if err != nil {
			utils.ErrorResponse(c, http.StatusUnauthorized, "Invalid manager override", err)
			return
		}
		approverID = &ctx.ApproverUserID
	}

	requestID := c.GetString("request_id")
	if requestID == "" {
		requestID = c.GetHeader("X-Request-ID")
	}

	voidSale, err := h.posService.VoidSale(companyID, locationID, userID, saleID, idemKey, reason, approverID, requestID)
	if err != nil {
		if err.Error() == "sale not found" {
			utils.NotFoundResponse(c, "Sale not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to void sale", err)
		return
	}

	utils.CreatedResponse(c, "Void invoice created", voidSale)
}

// POST /pos/calculate
// Calculates subtotal, tax and total for the provided POS items and discount
// without creating a sale. Useful for client-side previews.
func (h *POSHandler) CalculateTotals(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req models.POSCheckoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	// Reuse sales service calculation logic
	salesService := services.NewSalesService()
	subtotal, tax, total, err := salesService.CalculateTotals(companyID, &models.CreateSaleRequest{
		CustomerID:     req.CustomerID,
		Items:          req.Items,
		DiscountAmount: req.DiscountAmount,
	})
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to calculate totals", err)
		return
	}

	utils.SuccessResponse(c, "Totals calculated successfully", gin.H{
		"subtotal":     subtotal,
		"tax_amount":   tax,
		"total_amount": total,
	})
}

// POST /pos/hold
// Creates a held sale (status=DRAFT, pos_status=HOLD) without affecting stock.
func (h *POSHandler) HoldSale(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	if loc := c.Query("location_id"); loc != "" {
		if id, err := strconv.Atoi(loc); err == nil {
			locationID = id
		}
	}
	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	var req models.POSCheckoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	idemKey := c.GetHeader("Idempotency-Key")
	if idemKey == "" {
		idemKey = c.GetHeader("X-Idempotency-Key")
	}

	sale, err := h.posService.CreateHeldSale(companyID, locationID, userID, &req, idemKey)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to hold sale", err)
		return
	}

	utils.CreatedResponse(c, "Sale held successfully", sale)
}
