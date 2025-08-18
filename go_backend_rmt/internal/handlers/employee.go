package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type EmployeeHandler struct {
	employeeService *services.EmployeeService
}

func NewEmployeeHandler() *EmployeeHandler {
	return &EmployeeHandler{employeeService: services.NewEmployeeService()}
}

// GET /employees
func (h *EmployeeHandler) GetEmployees(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	filters := map[string]string{}
	if dept := c.Query("department"); dept != "" {
		filters["department"] = dept
	}
	if status := c.Query("status"); status != "" {
		filters["status"] = status
	}
	employees, err := h.employeeService.GetEmployees(companyID, filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get employees", err)
		return
	}
	utils.SuccessResponse(c, "Employees retrieved successfully", employees)
}

// POST /employees
func (h *EmployeeHandler) CreateEmployee(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.CreateEmployeeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	userID := c.GetInt("user_id")
	employee, err := h.employeeService.CreateEmployee(companyID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create employee", err)
		return
	}
	utils.CreatedResponse(c, "Employee created", employee)
}

// PUT /employees/:id
func (h *EmployeeHandler) UpdateEmployee(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	employeeID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid employee ID", err)
		return
	}
	var req models.UpdateEmployeeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	userID := c.GetInt("user_id")
	if err := h.employeeService.UpdateEmployee(employeeID, companyID, userID, &req); err != nil {
		if err.Error() == "employee not found" {
			utils.NotFoundResponse(c, "Employee not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update employee", err)
		return
	}
	utils.SuccessResponse(c, "Employee updated", nil)
}

// DELETE /employees/:id
func (h *EmployeeHandler) DeleteEmployee(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	employeeID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid employee ID", err)
		return
	}
	if err := h.employeeService.DeleteEmployee(employeeID, companyID); err != nil {
		if err.Error() == "employee not found" {
			utils.NotFoundResponse(c, "Employee not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete employee", err)
		return
	}
	utils.SuccessResponse(c, "Employee deleted", nil)
}
