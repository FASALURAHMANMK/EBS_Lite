package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type InvoiceTemplateHandler struct {
	service *services.InvoiceTemplateService
}

func NewInvoiceTemplateHandler() *InvoiceTemplateHandler {
	return &InvoiceTemplateHandler{service: services.NewInvoiceTemplateService()}
}

// GET /invoice-templates
func (h *InvoiceTemplateHandler) GetInvoiceTemplates(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	templates, err := h.service.GetInvoiceTemplates(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get invoice templates", err)
		return
	}
	utils.SuccessResponse(c, "Invoice templates retrieved successfully", templates)
}

// GET /invoice-templates/:id
func (h *InvoiceTemplateHandler) GetInvoiceTemplate(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid template ID", err)
		return
	}

	template, err := h.service.GetInvoiceTemplateByID(id, companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to get invoice template", err)
		return
	}
	utils.SuccessResponse(c, "Invoice template retrieved successfully", template)
}

// POST /invoice-templates
func (h *InvoiceTemplateHandler) CreateInvoiceTemplate(c *gin.Context) {
	var req models.CreateInvoiceTemplateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	userCompanyID := c.GetInt("company_id")
	if req.CompanyID != userCompanyID {
		utils.ForbiddenResponse(c, "Cannot create invoice templates for other companies")
		return
	}

	template, err := h.service.CreateInvoiceTemplate(&req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create invoice template", err)
		return
	}
	utils.CreatedResponse(c, "Invoice template created successfully", template)
}

// PUT /invoice-templates/:id
func (h *InvoiceTemplateHandler) UpdateInvoiceTemplate(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid template ID", err)
		return
	}
	var req models.UpdateInvoiceTemplateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	companyID := c.GetInt("company_id")
	err = h.service.UpdateInvoiceTemplate(id, companyID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update invoice template", err)
		return
	}
	utils.SuccessResponse(c, "Invoice template updated successfully", nil)
}

// DELETE /invoice-templates/:id
func (h *InvoiceTemplateHandler) DeleteInvoiceTemplate(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid template ID", err)
		return
	}
	companyID := c.GetInt("company_id")
	err = h.service.DeleteInvoiceTemplate(id, companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete invoice template", err)
		return
	}
	utils.SuccessResponse(c, "Invoice template deleted successfully", nil)
}
