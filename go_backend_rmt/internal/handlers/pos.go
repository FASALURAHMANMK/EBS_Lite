package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type POSHandler struct {
	posService *services.POSService
}

func NewPOSHandler() *POSHandler {
	return &POSHandler{
		posService: services.NewPOSService(),
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

	// Check if it's a search request
	if searchTerm := c.Query("search"); searchTerm != "" {
		products, err := h.posService.SearchProducts(companyID, locationID, searchTerm)
		if err != nil {
			utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to search products", err)
			return
		}
		utils.SuccessResponse(c, "Products search completed", products)
		return
	}

	products, err := h.posService.GetPOSProducts(companyID, locationID)
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
	if searchTerm := c.Query("search"); searchTerm != "" {
		customers, err := h.posService.SearchCustomers(companyID, searchTerm)
		if err != nil {
			utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to search customers", err)
			return
		}
		utils.SuccessResponse(c, "Customer search completed", customers)
		return
	}

	customers, err := h.posService.GetPOSCustomers(companyID)
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

	sale, err := h.posService.ProcessCheckout(companyID, locationID, userID, &req)
	if err != nil {
		if err.Error() == "customer not found" {
			utils.NotFoundResponse(c, "Customer not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to process checkout", err)
		return
	}

	utils.CreatedResponse(c, "Checkout completed successfully", map[string]interface{}{
		"sale":       sale,
		"invoice_id": sale.SaleID,
	})
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

	// Validate request
	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	err := h.posService.PrintInvoice(req.InvoiceID, companyID)
	if err != nil {
		if err.Error() == "invoice not found" {
			utils.NotFoundResponse(c, "Invoice not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to print invoice", err)
		return
	}

	utils.SuccessResponse(c, "Invoice sent to printer successfully", nil)
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

    voidSale, err := h.posService.VoidSale(companyID, locationID, userID, saleID)
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
    subtotal, tax, total, err := salesService.CalculateTotals(&models.CreateSaleRequest{
        CustomerID:     req.CustomerID,
        Items:          req.Items,
        DiscountAmount: req.DiscountAmount,
    })
    if err != nil {
        utils.ErrorResponse(c, http.StatusBadRequest, "Failed to calculate totals", err)
        return
    }

    utils.SuccessResponse(c, "Totals calculated successfully", gin.H{
        "subtotal":    subtotal,
        "tax_amount":  tax,
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

    sale, err := h.posService.CreateHeldSale(companyID, locationID, userID, &req)
    if err != nil {
        utils.ErrorResponse(c, http.StatusBadRequest, "Failed to hold sale", err)
        return
    }

    utils.CreatedResponse(c, "Sale held successfully", sale)
}
