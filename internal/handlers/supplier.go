package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type SupplierHandler struct {
	supplierService *services.SupplierService
}

func NewSupplierHandler() *SupplierHandler {
	return &SupplierHandler{
		supplierService: services.NewSupplierService(),
	}
}

// GET /suppliers
func (h *SupplierHandler) GetSuppliers(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	// Parse query filters
	filters := make(map[string]string)
	if isActive := c.Query("is_active"); isActive != "" {
		filters["is_active"] = isActive
	}
	if search := c.Query("search"); search != "" {
		filters["search"] = search
	}

	suppliers, err := h.supplierService.GetSuppliers(companyID, filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get suppliers", err)
		return
	}

	utils.SuccessResponse(c, "Suppliers retrieved successfully", suppliers)
}

// GET /suppliers/:id
func (h *SupplierHandler) GetSupplier(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	supplierID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid supplier ID", err)
		return
	}

	supplier, err := h.supplierService.GetSupplierByID(supplierID, companyID)
	if err != nil {
		if err.Error() == "supplier not found" {
			utils.NotFoundResponse(c, "Supplier not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get supplier", err)
		return
	}

	utils.SuccessResponse(c, "Supplier retrieved successfully", supplier)
}

// POST /suppliers
func (h *SupplierHandler) CreateSupplier(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	userID := c.GetInt("user_id")

	var req models.CreateSupplierRequest
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

	supplier, err := h.supplierService.CreateSupplier(companyID, userID, &req)
	if err != nil {
		if err.Error() == "supplier with this name already exists" {
			utils.ConflictResponse(c, "Supplier with this name already exists")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create supplier", err)
		return
	}

	utils.CreatedResponse(c, "Supplier created successfully", supplier)
}

// PUT /suppliers/:id
func (h *SupplierHandler) UpdateSupplier(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	userID := c.GetInt("user_id")

	supplierID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid supplier ID", err)
		return
	}

	var req models.UpdateSupplierRequest
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

	err = h.supplierService.UpdateSupplier(supplierID, companyID, userID, &req)
	if err != nil {
		if err.Error() == "supplier not found" {
			utils.NotFoundResponse(c, "Supplier not found")
			return
		}
		if err.Error() == "supplier with this name already exists" {
			utils.ConflictResponse(c, "Supplier with this name already exists")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update supplier", err)
		return
	}

	utils.SuccessResponse(c, "Supplier updated successfully", nil)
}

// DELETE /suppliers/:id
func (h *SupplierHandler) DeleteSupplier(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	userID := c.GetInt("user_id")

	supplierID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid supplier ID", err)
		return
	}

	err = h.supplierService.DeleteSupplier(supplierID, companyID, userID)
	if err != nil {
		if err.Error() == "supplier not found" {
			utils.NotFoundResponse(c, "Supplier not found")
			return
		}
		if err.Error() == "cannot delete supplier with existing purchases" {
			utils.ConflictResponse(c, "Cannot delete supplier with existing purchases")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to delete supplier", err)
		return
	}

	utils.SuccessResponse(c, "Supplier deleted successfully", nil)
}
