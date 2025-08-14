package handlers

import (
	"net/http"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

// SettingsHandler handles HTTP requests for system settings
type SettingsHandler struct {
	service *services.SettingsService
}

func NewSettingsHandler() *SettingsHandler {
	return &SettingsHandler{service: services.NewSettingsService()}
}

// GET /settings
func (h *SettingsHandler) GetSettings(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	settings, err := h.service.GetSettings(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get settings", err)
		return
	}
	utils.SuccessResponse(c, "Settings retrieved successfully", settings)
}

// PUT /settings
func (h *SettingsHandler) UpdateSettings(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req models.UpdateSettingsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	if err := h.service.UpdateSettings(companyID, req.Settings); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update settings", err)
		return
	}

	utils.SuccessResponse(c, "Settings updated successfully", nil)
}
