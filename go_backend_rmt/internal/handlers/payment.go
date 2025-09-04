package handlers

import (
    "net/http"

    "erp-backend/internal/services"
    "erp-backend/internal/utils"

    "github.com/gin-gonic/gin"
)

type PaymentHandler struct {
    service *services.PaymentService
}

func NewPaymentHandler() *PaymentHandler {
    return &PaymentHandler{service: services.NewPaymentService()}
}

// GET /payments
func (h *PaymentHandler) GetPayments(c *gin.Context) {
    companyID := c.GetInt("company_id")
    if companyID == 0 {
        utils.ForbiddenResponse(c, "Company access required")
        return
    }

    filters := map[string]string{}
    if v := c.Query("supplier_id"); v != "" { filters["supplier_id"] = v }
    if v := c.Query("location_id"); v != "" { filters["location_id"] = v }
    if v := c.Query("date_from"); v != "" { filters["date_from"] = v }
    if v := c.Query("date_to"); v != "" { filters["date_to"] = v }

    items, err := h.service.GetPayments(companyID, filters)
    if err != nil {
        utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get payments", err)
        return
    }
    utils.SuccessResponse(c, "Payments retrieved successfully", items)
}

