package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type CompanyHandler struct {
	companyService *services.CompanyService
}

func NewCompanyHandler() *CompanyHandler {
	return &CompanyHandler{
		companyService: services.NewCompanyService(),
	}
}

// GET /companies
func (h *CompanyHandler) GetCompanies(c *gin.Context) {
	companies, err := h.companyService.GetCompanies()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get companies", err)
		return
	}

	utils.SuccessResponse(c, "Companies retrieved successfully", companies)
}

// POST /companies
// func (h *CompanyHandler) CreateCompany(c *gin.Context) {
// 	var req models.CreateCompanyRequest
// 	if err := c.ShouldBindJSON(&req); err != nil {
// 		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
// 		return
// 	}

// 	// Validate request
// 	if err := utils.ValidateStruct(&req); err != nil {
// 		validationErrors := utils.GetValidationErrors(err)
// 		utils.ValidationErrorResponse(c, validationErrors)
// 		return
// 	}

// 	company, err := h.companyService.CreateCompany(&req)
// 	if err != nil {
// 		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create company", err)
// 		return
// 	}

// 	utils.CreatedResponse(c, "Company created successfully", company)
// }

func (h *CompanyHandler) CreateCompany(c *gin.Context) {
	var req models.CreateCompanyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	// Validate request
	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	// Get user ID for first-time company assignment
	userID := c.GetInt("user_id")

	company, err := h.companyService.CreateCompany(&req, userID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create company", err)
		return
	}

	utils.CreatedResponse(c, "Company created successfully", company)
}

// PUT /companies/:id
func (h *CompanyHandler) UpdateCompany(c *gin.Context) {
	companyID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid company ID", err)
		return
	}

	var req models.UpdateCompanyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	// Validate request
	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	err = h.companyService.UpdateCompany(companyID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update company", err)
		return
	}

	utils.SuccessResponse(c, "Company updated successfully", nil)
}

// DELETE /companies/:id
func (h *CompanyHandler) DeleteCompany(c *gin.Context) {
	companyID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid company ID", err)
		return
	}

	err = h.companyService.DeleteCompany(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete company", err)
		return
	}

	utils.SuccessResponse(c, "Company deleted successfully", nil)
}
