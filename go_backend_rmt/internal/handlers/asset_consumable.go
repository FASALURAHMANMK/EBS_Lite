package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type AssetConsumableHandler struct {
	service *services.AssetConsumableService
}

func NewAssetConsumableHandler() *AssetConsumableHandler {
	return &AssetConsumableHandler{service: services.NewAssetConsumableService()}
}

func (h *AssetConsumableHandler) GetAssetCategories(c *gin.Context) {
	companyID := c.GetInt("company_id")
	items, err := h.service.GetAssetCategories(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get asset categories", err)
		return
	}
	utils.SuccessResponse(c, "Asset categories retrieved successfully", items)
}

func (h *AssetConsumableHandler) CreateAssetCategory(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	var req models.CreateAssetCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.service.CreateAssetCategory(companyID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create asset category", err)
		return
	}
	utils.CreatedResponse(c, "Asset category created successfully", item)
}

func (h *AssetConsumableHandler) UpdateAssetCategory(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	categoryID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid category ID", err)
		return
	}
	var req models.UpdateAssetCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.service.UpdateAssetCategory(companyID, categoryID, userID, &req)
	if err != nil {
		if err.Error() == "asset category not found" {
			utils.NotFoundResponse(c, "Asset category not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update asset category", err)
		return
	}
	utils.SuccessResponse(c, "Asset category updated successfully", item)
}

func (h *AssetConsumableHandler) DeleteAssetCategory(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	categoryID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid category ID", err)
		return
	}
	if err := h.service.DeleteAssetCategory(companyID, categoryID, userID); err != nil {
		if err.Error() == "asset category not found" {
			utils.NotFoundResponse(c, "Asset category not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete asset category", err)
		return
	}
	utils.SuccessResponse(c, "Asset category deleted successfully", nil)
}

func (h *AssetConsumableHandler) GetConsumableCategories(c *gin.Context) {
	companyID := c.GetInt("company_id")
	items, err := h.service.GetConsumableCategories(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get consumable categories", err)
		return
	}
	utils.SuccessResponse(c, "Consumable categories retrieved successfully", items)
}

func (h *AssetConsumableHandler) CreateConsumableCategory(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	var req models.CreateConsumableCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.service.CreateConsumableCategory(companyID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create consumable category", err)
		return
	}
	utils.CreatedResponse(c, "Consumable category created successfully", item)
}

func (h *AssetConsumableHandler) UpdateConsumableCategory(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	categoryID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid category ID", err)
		return
	}
	var req models.UpdateConsumableCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.service.UpdateConsumableCategory(companyID, categoryID, userID, &req)
	if err != nil {
		if err.Error() == "consumable category not found" {
			utils.NotFoundResponse(c, "Consumable category not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update consumable category", err)
		return
	}
	utils.SuccessResponse(c, "Consumable category updated successfully", item)
}

func (h *AssetConsumableHandler) DeleteConsumableCategory(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	categoryID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid category ID", err)
		return
	}
	if err := h.service.DeleteConsumableCategory(companyID, categoryID, userID); err != nil {
		if err.Error() == "consumable category not found" {
			utils.NotFoundResponse(c, "Consumable category not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete consumable category", err)
		return
	}
	utils.SuccessResponse(c, "Consumable category deleted successfully", nil)
}

func (h *AssetConsumableHandler) GetAssetRegister(c *gin.Context) {
	companyID := c.GetInt("company_id")
	var locationID *int
	if raw := c.Query("location_id"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil && parsed > 0 {
			locationID = &parsed
		}
	}
	items, err := h.service.GetAssetRegister(companyID, locationID, c.Query("search"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get asset register", err)
		return
	}
	utils.SuccessResponse(c, "Asset register retrieved successfully", items)
}

func (h *AssetConsumableHandler) GetAssetRegisterSummary(c *gin.Context) {
	companyID := c.GetInt("company_id")
	var locationID *int
	if raw := c.Query("location_id"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil && parsed > 0 {
			locationID = &parsed
		}
	}
	summary, err := h.service.GetAssetRegisterSummary(companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get asset summary", err)
		return
	}
	utils.SuccessResponse(c, "Asset summary retrieved successfully", summary)
}

func (h *AssetConsumableHandler) CreateAssetRegisterEntry(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")
	if raw := c.Query("location_id"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil {
			locationID = parsed
		}
	}
	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}
	var req models.CreateAssetRegisterEntryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.service.CreateAssetRegisterEntry(companyID, locationID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create asset register entry", err)
		return
	}
	utils.CreatedResponse(c, "Asset register entry created successfully", item)
}

func (h *AssetConsumableHandler) GetConsumableEntries(c *gin.Context) {
	companyID := c.GetInt("company_id")
	var locationID *int
	if raw := c.Query("location_id"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil && parsed > 0 {
			locationID = &parsed
		}
	}
	items, err := h.service.GetConsumableEntries(companyID, locationID, c.Query("search"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get consumable entries", err)
		return
	}
	utils.SuccessResponse(c, "Consumable entries retrieved successfully", items)
}

func (h *AssetConsumableHandler) GetConsumableSummary(c *gin.Context) {
	companyID := c.GetInt("company_id")
	var locationID *int
	if raw := c.Query("location_id"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil && parsed > 0 {
			locationID = &parsed
		}
	}
	summary, err := h.service.GetConsumableSummary(companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get consumable summary", err)
		return
	}
	utils.SuccessResponse(c, "Consumable summary retrieved successfully", summary)
}

func (h *AssetConsumableHandler) CreateConsumableEntry(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")
	if raw := c.Query("location_id"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil {
			locationID = parsed
		}
	}
	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}
	var req models.CreateConsumableEntryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.service.CreateConsumableEntry(companyID, locationID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create consumable entry", err)
		return
	}
	utils.CreatedResponse(c, "Consumable entry created successfully", item)
}
