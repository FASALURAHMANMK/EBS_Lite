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

// GET /product-attribute-definitions
func (h *ProductAttributeHandler) GetDefinitions(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	defs, err := h.service.GetAttributeDefinitions(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get product attribute definitions", err)
		return
	}
	utils.SuccessResponse(c, "Product attribute definitions retrieved successfully", defs)
}

// POST /product-attribute-definitions
func (h *ProductAttributeHandler) CreateDefinition(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.CreateProductAttributeDefinitionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	def, err := h.service.CreateAttributeDefinition(companyID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create product attribute definition", err)
		return
	}
	utils.CreatedResponse(c, "Product attribute definition created successfully", def)
}

// PUT /product-attribute-definitions/:id
func (h *ProductAttributeHandler) UpdateDefinition(c *gin.Context) {
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
	var req models.UpdateProductAttributeDefinitionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := h.service.UpdateAttributeDefinition(id, companyID, &req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update product attribute definition", err)
		return
	}
	utils.SuccessResponse(c, "Product attribute definition updated successfully", nil)
}

// DELETE /product-attribute-definitions/:id
func (h *ProductAttributeHandler) DeleteDefinition(c *gin.Context) {
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
	if err := h.service.DeleteAttributeDefinition(id, companyID); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete product attribute definition", err)
		return
	}
	utils.SuccessResponse(c, "Product attribute definition deleted successfully", nil)
}
