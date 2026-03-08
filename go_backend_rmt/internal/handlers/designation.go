package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type DesignationHandler struct {
	designationService *services.DesignationService
}

func NewDesignationHandler() *DesignationHandler {
	return &DesignationHandler{designationService: services.NewDesignationService()}
}

// GET /designations
func (h *DesignationHandler) List(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var departmentID *int
	if dep := c.Query("department_id"); dep != "" {
		if id, err := strconv.Atoi(dep); err == nil {
			departmentID = &id
		}
	}
	list, err := h.designationService.List(companyID, departmentID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to list designations", err)
		return
	}
	utils.SuccessResponse(c, "Designations retrieved", list)
}

// POST /designations
func (h *DesignationHandler) Create(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.CreateDesignationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	userID := c.GetInt("user_id")
	r, err := h.designationService.Create(companyID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create designation", err)
		return
	}
	utils.CreatedResponse(c, "Designation created", r)
}

// PUT /designations/:id
func (h *DesignationHandler) Update(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	designationID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid designation ID", err)
		return
	}
	var req models.UpdateDesignationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	userID := c.GetInt("user_id")
	if err := h.designationService.Update(companyID, designationID, userID, &req); err != nil {
		if err.Error() == "designation not found" {
			utils.NotFoundResponse(c, "Designation not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update designation", err)
		return
	}
	utils.SuccessResponse(c, "Designation updated", nil)
}

// DELETE /designations/:id
func (h *DesignationHandler) Delete(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	designationID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid designation ID", err)
		return
	}
	userID := c.GetInt("user_id")
	if err := h.designationService.Delete(companyID, designationID, userID); err != nil {
		if err.Error() == "designation not found" {
			utils.NotFoundResponse(c, "Designation not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete designation", err)
		return
	}
	utils.SuccessResponse(c, "Designation deleted", nil)
}
