package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type ProductAttributeHandler struct {
	service *services.ProductAttributeService
}

func NewProductAttributeHandler() *ProductAttributeHandler {
	return &ProductAttributeHandler{service: services.NewProductAttributeService()}
}

// GET /product-attributes
func (h *ProductAttributeHandler) GetAttributes(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	attrs, err := h.service.GetProductAttributes(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get product attributes", err)
		return
	}
	utils.SuccessResponse(c, "Product attributes retrieved successfully", attrs)
}

// POST /product-attributes
func (h *ProductAttributeHandler) CreateAttribute(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.CreateProductAttributeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	attr, err := h.service.CreateProductAttribute(companyID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create product attribute", err)
		return
	}
	utils.CreatedResponse(c, "Product attribute created successfully", attr)
}

// PUT /product-attributes/:id
func (h *ProductAttributeHandler) UpdateAttribute(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid attribute ID", err)
		return
	}
	var req models.UpdateProductAttributeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := h.service.UpdateProductAttribute(id, companyID, &req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update product attribute", err)
		return
	}
	utils.SuccessResponse(c, "Product attribute updated successfully", nil)
}

// DELETE /product-attributes/:id
func (h *ProductAttributeHandler) DeleteAttribute(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid attribute ID", err)
		return
	}
	if err := h.service.DeleteProductAttribute(id, companyID); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete product attribute", err)
		return
	}
	utils.SuccessResponse(c, "Product attribute deleted successfully", nil)
}
