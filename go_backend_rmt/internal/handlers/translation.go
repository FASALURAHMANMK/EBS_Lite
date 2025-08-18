package handlers

import (
	"net/http"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

// TranslationHandler manages translation endpoints
type TranslationHandler struct {
	service *services.TranslationService
}

func NewTranslationHandler() *TranslationHandler {
	return &TranslationHandler{service: services.NewTranslationService()}
}

// GET /translations
func (h *TranslationHandler) GetTranslations(c *gin.Context) {
	lang := c.Query("lang")
	if lang == "" {
		lang = "en"
	}

	translations, err := h.service.GetTranslations(lang)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get translations", err)
		return
	}
	utils.SuccessResponse(c, "Translations retrieved successfully", translations)
}

// PUT /translations
func (h *TranslationHandler) UpdateTranslations(c *gin.Context) {
	var req models.UpdateTranslationsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	if err := h.service.UpdateTranslations(req.Lang, req.Strings); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update translations", err)
		return
	}

	utils.SuccessResponse(c, "Translations updated successfully", nil)
}
