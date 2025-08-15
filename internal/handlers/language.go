package handlers

import (
	"net/http"

	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

// LanguageHandler handles language related endpoints
type LanguageHandler struct {
	service *services.LanguageService
}

// NewLanguageHandler creates a new LanguageHandler
func NewLanguageHandler() *LanguageHandler {
	return &LanguageHandler{service: services.NewLanguageService()}
}

// GetLanguages handles GET /languages and returns active languages
func (h *LanguageHandler) GetLanguages(c *gin.Context) {
	languages, err := h.service.GetActiveLanguages()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get languages", err)
		return
	}
	utils.SuccessResponse(c, "Languages retrieved successfully", languages)
}

// UpdateLanguageStatus handles PUT /languages/:code to activate/deactivate a language
func (h *LanguageHandler) UpdateLanguageStatus(c *gin.Context) {
	code := c.Param("code")
	var req struct {
		IsActive bool `json:"is_active" validate:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	if err := h.service.UpdateLanguageStatus(code, req.IsActive); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update language", err)
		return
	}
	utils.SuccessResponse(c, "Language status updated successfully", nil)
}
