package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type DepartmentHandler struct {
	departmentService *services.DepartmentService
}

func NewDepartmentHandler() *DepartmentHandler {
	return &DepartmentHandler{departmentService: services.NewDepartmentService()}
}

// GET /departments
func (h *DepartmentHandler) List(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	list, err := h.departmentService.List(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to list departments", err)
		return
	}
	utils.SuccessResponse(c, "Departments retrieved", list)
}

// POST /departments
func (h *DepartmentHandler) Create(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.CreateDepartmentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	userID := c.GetInt("user_id")
	d, err := h.departmentService.Create(companyID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create department", err)
		return
	}
	utils.CreatedResponse(c, "Department created", d)
}

// PUT /departments/:id
func (h *DepartmentHandler) Update(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	departmentID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid department ID", err)
		return
	}
	var req models.UpdateDepartmentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	userID := c.GetInt("user_id")
	if err := h.departmentService.Update(companyID, departmentID, userID, &req); err != nil {
		if err.Error() == "department not found" {
			utils.NotFoundResponse(c, "Department not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update department", err)
		return
	}
	utils.SuccessResponse(c, "Department updated", nil)
}

// DELETE /departments/:id
func (h *DepartmentHandler) Delete(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	departmentID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid department ID", err)
		return
	}
	userID := c.GetInt("user_id")
	if err := h.departmentService.Delete(companyID, departmentID, userID); err != nil {
		if err.Error() == "department not found" {
			utils.NotFoundResponse(c, "Department not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete department", err)
		return
	}
	utils.SuccessResponse(c, "Department deleted", nil)
}
