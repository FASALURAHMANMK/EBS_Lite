package handlers

import (
	"net/http"

	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type UserPreferencesHandler struct {
	service *services.UserPreferencesService
}

func NewUserPreferencesHandler() *UserPreferencesHandler {
	return &UserPreferencesHandler{service: services.NewUserPreferencesService()}
}

func (h *UserPreferencesHandler) GetPreferences(c *gin.Context) {
	userID := c.GetInt("user_id")
	if userID == 0 {
		utils.UnauthorizedResponse(c, "User context not found")
		return
	}
	prefs, err := h.service.GetPreferences(userID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get preferences", err)
		return
	}
	utils.SuccessResponse(c, "Preferences retrieved successfully", prefs)
}

type UserPreferenceRequest struct {
	Key   string `json:"key" validate:"required"`
	Value string `json:"value"`
}

func (h *UserPreferencesHandler) UpsertPreference(c *gin.Context) {
	userID := c.GetInt("user_id")
	if userID == 0 {
		utils.UnauthorizedResponse(c, "User context not found")
		return
	}
	var req UserPreferenceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	if err := h.service.UpsertPreference(userID, req.Key, req.Value); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to upsert preference", err)
		return
	}
	utils.SuccessResponse(c, "Preference saved successfully", nil)
}

func (h *UserPreferencesHandler) DeletePreference(c *gin.Context) {
	userID := c.GetInt("user_id")
	if userID == 0 {
		utils.UnauthorizedResponse(c, "User context not found")
		return
	}
	key := c.Param("key")
	if key == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Preference key required", nil)
		return
	}
	if err := h.service.DeletePreference(userID, key); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to delete preference", err)
		return
	}
	utils.SuccessResponse(c, "Preference deleted successfully", nil)
}
