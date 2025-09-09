package handlers

import (
    "net/http"
    "strconv"

    "erp-backend/internal/services"
    "erp-backend/internal/utils"
    "erp-backend/internal/models"

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

// POST /payments
func (h *PaymentHandler) CreatePayment(c *gin.Context) {
    companyID := c.GetInt("company_id")
    locationID := c.GetInt("location_id")
    userID := c.GetInt("user_id")

    if companyID == 0 {
        utils.ForbiddenResponse(c, "Company access required")
        return
    }

    // Allow overriding location via query param like other endpoints
    if v := c.Query("location_id"); v != "" {
        if id, err := strconv.Atoi(v); err == nil {
            locationID = id
        }
    }
    if locationID == 0 {
        utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
        return
    }

    var req models.CreatePaymentRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
        return
    }
    if err := utils.ValidateStruct(&req); err != nil {
        utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
        return
    }

    p, err := h.service.CreatePayment(companyID, locationID, userID, &req)
    if err != nil {
        // Friendly not found messages
        if err.Error() == "supplier not found" || err.Error() == "purchase not found" {
            utils.NotFoundResponse(c, err.Error())
            return
        }
        utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create payment", err)
        return
    }

    utils.CreatedResponse(c, "Payment recorded successfully", p)
}
