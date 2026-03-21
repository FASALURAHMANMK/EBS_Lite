package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type WarrantyHandler struct {
	service *services.WarrantyService
}

func NewWarrantyHandler() *WarrantyHandler {
	return &WarrantyHandler{service: services.NewWarrantyService()}
}

// GET /warranties/prepare?sale_number=...
func (h *WarrantyHandler) PrepareWarranty(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	saleNumber := c.Query("sale_number")
	if saleNumber == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "sale_number is required", nil)
		return
	}

	result, err := h.service.PrepareWarranty(companyID, saleNumber)
	if err != nil {
		if err.Error() == "sale not found" {
			utils.NotFoundResponse(c, "Sale not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to prepare warranty registration", err)
		return
	}

	utils.SuccessResponse(c, "Warranty registration data prepared successfully", result)
}

// POST /warranties
func (h *WarrantyHandler) CreateWarranty(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req models.CreateWarrantyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	result, err := h.service.CreateWarranty(companyID, userID, &req)
	if err != nil {
		switch err.Error() {
		case "sale not found":
			utils.NotFoundResponse(c, "Sale not found")
			return
		case "customer not found":
			utils.NotFoundResponse(c, "Customer not found")
			return
		default:
			utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create warranty registration", err)
			return
		}
	}

	utils.CreatedResponse(c, "Warranty registered successfully", result)
}

// GET /warranties/search?sale_number=...&phone=...
func (h *WarrantyHandler) LookupWarranties(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	result, err := h.service.LookupWarranties(companyID, models.WarrantyLookupFilters{
		SaleNumber: c.Query("sale_number"),
		Phone:      c.Query("phone"),
	})
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to search warranties", err)
		return
	}

	utils.SuccessResponse(c, "Warranties retrieved successfully", result)
}

// GET /warranties/:id
func (h *WarrantyHandler) GetWarranty(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	warrantyID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid warranty ID", err)
		return
	}

	result, err := h.service.GetWarrantyByID(companyID, warrantyID)
	if err != nil {
		if err.Error() == "warranty not found" {
			utils.NotFoundResponse(c, "Warranty not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to retrieve warranty", err)
		return
	}

	utils.SuccessResponse(c, "Warranty retrieved successfully", result)
}

// GET /warranties/:id/card
func (h *WarrantyHandler) GetWarrantyCardData(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	warrantyID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid warranty ID", err)
		return
	}

	result, err := h.service.GetWarrantyCardData(companyID, warrantyID)
	if err != nil {
		if err.Error() == "warranty not found" {
			utils.NotFoundResponse(c, "Warranty not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to retrieve warranty card data", err)
		return
	}

	utils.SuccessResponse(c, "Warranty card data retrieved successfully", result)
}
