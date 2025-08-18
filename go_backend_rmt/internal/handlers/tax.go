package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

// TaxHandler handles HTTP requests for taxes

type TaxHandler struct {
	service *services.TaxService
}

// NewTaxHandler creates a new TaxHandler
func NewTaxHandler() *TaxHandler {
	return &TaxHandler{service: services.NewTaxService()}
}

// GetTaxes handles GET /taxes
func (h *TaxHandler) GetTaxes(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	taxes, err := h.service.GetTaxes(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get taxes", err)
		return
	}
	utils.SuccessResponse(c, "Taxes retrieved successfully", taxes)
}

// CreateTax handles POST /taxes
func (h *TaxHandler) CreateTax(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req models.CreateTaxRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	tax, err := h.service.CreateTax(companyID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create tax", err)
		return
	}
	utils.CreatedResponse(c, "Tax created successfully", tax)
}

// UpdateTax handles PUT /taxes/:id
func (h *TaxHandler) UpdateTax(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid tax ID", err)
		return
	}

	var req models.UpdateTaxRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	if err := h.service.UpdateTax(id, companyID, &req); err != nil {
		if err.Error() == "tax not found" {
			utils.NotFoundResponse(c, "Tax not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update tax", err)
		return
	}
	utils.SuccessResponse(c, "Tax updated successfully", nil)
}

// DeleteTax handles DELETE /taxes/:id
func (h *TaxHandler) DeleteTax(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid tax ID", err)
		return
	}

	if err := h.service.DeleteTax(id, companyID); err != nil {
		if err.Error() == "tax not found" {
			utils.NotFoundResponse(c, "Tax not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to delete tax", err)
		return
	}
	utils.SuccessResponse(c, "Tax deleted successfully", nil)
}
