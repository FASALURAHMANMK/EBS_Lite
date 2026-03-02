package handlers

import (
	"fmt"
	"mime/multipart"
	"net/http"
	"strconv"

	"erp-backend/internal/config"
	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type CompanyHandler struct {
	companyService *services.CompanyService
	cfg            *config.Config
}

func NewCompanyHandler(cfg *config.Config) *CompanyHandler {
	return &CompanyHandler{
		companyService: services.NewCompanyService(),
		cfg:            cfg,
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

// POST /companies/:id/logo
// Accepts multipart file 'file' and stores under uploads directory.
// Updates companies.logo with served path and returns { logo: "/uploads/.." }
func (h *CompanyHandler) UploadCompanyLogo(c *gin.Context) {
	companyID, err := strconv.Atoi(c.Param("id"))
	if err != nil || companyID <= 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid company ID", err)
		return
	}

	file, err := c.FormFile("file")
	if err != nil {
		if utils.IsRequestBodyTooLarge(err) {
			utils.ErrorResponse(c, http.StatusRequestEntityTooLarge, "Upload too large", err)
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "File is required", err)
		return
	}

	if err := h.saveAndSetCompanyLogo(c, companyID, file); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to upload logo", err)
		return
	}
}

func (h *CompanyHandler) saveAndSetCompanyLogo(c *gin.Context, companyID int, fh *multipart.FileHeader) error {
	served, err := services.SaveUploadedFile(h.cfg.UploadPath, "logos", fh, services.AllowlistCompanyLogo())
	if err != nil {
		return err
	}

	// Update via service
	req := &models.UpdateCompanyRequest{Logo: &served}
	if err := h.companyService.UpdateCompany(companyID, req); err != nil {
		return fmt.Errorf("failed to update company logo: %w", err)
	}

	utils.SuccessResponse(c, "Logo uploaded", gin.H{"logo": served})
	return nil
}
