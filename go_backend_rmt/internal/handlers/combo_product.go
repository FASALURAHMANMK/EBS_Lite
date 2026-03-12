package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type ComboProductHandler struct {
	comboService *services.ComboProductService
}

func NewComboProductHandler() *ComboProductHandler {
	return &ComboProductHandler{comboService: services.NewComboProductService()}
}

func (h *ComboProductHandler) GetComboProducts(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var locationID *int
	if raw := c.Query("location_id"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil && parsed > 0 {
			locationID = &parsed
		}
	}
	items, err := h.comboService.ListComboProducts(companyID, locationID, c.Query("search"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get combo products", err)
		return
	}
	utils.SuccessResponse(c, "Combo products retrieved successfully", items)
}

func (h *ComboProductHandler) GetComboProduct(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	comboProductID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid combo product ID", err)
		return
	}
	var locationID *int
	if raw := c.Query("location_id"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil && parsed > 0 {
			locationID = &parsed
		}
	}
	item, err := h.comboService.GetComboProductByID(comboProductID, companyID, locationID)
	if err != nil {
		if err.Error() == "combo product not found" {
			utils.NotFoundResponse(c, "Combo product not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to get combo product", err)
		return
	}
	utils.SuccessResponse(c, "Combo product retrieved successfully", item)
}

func (h *ComboProductHandler) CreateComboProduct(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.CreateComboProductRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.comboService.CreateComboProduct(companyID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create combo product", err)
		return
	}
	utils.CreatedResponse(c, "Combo product created successfully", item)
}

func (h *ComboProductHandler) UpdateComboProduct(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	comboProductID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid combo product ID", err)
		return
	}
	var req models.UpdateComboProductRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.comboService.UpdateComboProduct(comboProductID, companyID, userID, &req)
	if err != nil {
		if err.Error() == "combo product not found" {
			utils.NotFoundResponse(c, "Combo product not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update combo product", err)
		return
	}
	utils.SuccessResponse(c, "Combo product updated successfully", item)
}

func (h *ComboProductHandler) DeleteComboProduct(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	comboProductID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid combo product ID", err)
		return
	}
	if err := h.comboService.DeleteComboProduct(comboProductID, companyID, userID); err != nil {
		if err.Error() == "combo product not found" {
			utils.NotFoundResponse(c, "Combo product not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete combo product", err)
		return
	}
	utils.SuccessResponse(c, "Combo product deleted successfully", nil)
}
