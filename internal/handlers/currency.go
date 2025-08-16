package handlers

import (
	"net/http"
	"strconv"
	"strings"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

// CurrencyHandler handles currency related endpoints
type CurrencyHandler struct {
	service *services.CurrencyService
}

// NewCurrencyHandler creates a new CurrencyHandler
func NewCurrencyHandler() *CurrencyHandler {
	return &CurrencyHandler{service: services.NewCurrencyService()}
}

// GetCurrencies handles GET /currencies
func (h *CurrencyHandler) GetCurrencies(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	currencies, err := h.service.GetCurrencies()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get currencies", err)
		return
	}
	utils.SuccessResponse(c, "Currencies retrieved successfully", currencies)
}

// CreateCurrency handles POST /currencies
func (h *CurrencyHandler) CreateCurrency(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req models.CreateCurrencyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	req.Code = strings.ToUpper(req.Code)

	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	currency, err := h.service.CreateCurrency(&req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create currency", err)
		return
	}
	utils.CreatedResponse(c, "Currency created successfully", currency)
}

// UpdateCurrency handles PUT/PATCH /currencies/:id
func (h *CurrencyHandler) UpdateCurrency(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid currency ID", err)
		return
	}

	var req models.UpdateCurrencyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if req.Code != nil {
		code := strings.ToUpper(*req.Code)
		req.Code = &code
	}

	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	if err := h.service.UpdateCurrency(id, &req); err != nil {
		if err.Error() == "currency not found" {
			utils.NotFoundResponse(c, "Currency not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update currency", err)
		return
	}
	utils.SuccessResponse(c, "Currency updated successfully", nil)
}

// DeleteCurrency handles DELETE /currencies/:id
func (h *CurrencyHandler) DeleteCurrency(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid currency ID", err)
		return
	}

	if err := h.service.DeleteCurrency(id); err != nil {
		if err.Error() == "currency not found" {
			utils.NotFoundResponse(c, "Currency not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to delete currency", err)
		return
	}
	utils.SuccessResponse(c, "Currency deleted successfully", nil)
}
