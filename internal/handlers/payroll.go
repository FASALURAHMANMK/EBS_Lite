package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type PayrollHandler struct {
	payrollService *services.PayrollService
}

func NewPayrollHandler() *PayrollHandler {
	return &PayrollHandler{payrollService: services.NewPayrollService()}
}

// GET /payrolls
func (h *PayrollHandler) GetPayrolls(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	filters := map[string]string{}
	if empID := c.Query("employee_id"); empID != "" {
		filters["employee_id"] = empID
	}
	if month := c.Query("month"); month != "" {
		filters["month"] = month
	}
	payrolls, err := h.payrollService.GetPayrolls(companyID, filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get payrolls", err)
		return
	}
	utils.SuccessResponse(c, "Payrolls retrieved successfully", payrolls)
}

// POST /payrolls
func (h *PayrollHandler) CreatePayroll(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.CreatePayrollRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	userID := c.GetInt("user_id")
	payroll, err := h.payrollService.CreatePayroll(companyID, &req, userID)
	if err != nil {
		if err.Error() == "employee not found" {
			utils.NotFoundResponse(c, "Employee not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create payroll", err)
		return
	}
	utils.CreatedResponse(c, "Payroll generated", payroll)
}

// PUT /payrolls/:id/mark-paid
func (h *PayrollHandler) MarkPayrollPaid(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	payrollID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid payroll ID", err)
		return
	}
	if err := h.payrollService.MarkPayrollPaid(payrollID, companyID); err != nil {
		if err.Error() == "payroll not found" {
			utils.NotFoundResponse(c, "Payroll not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to mark payroll paid", err)
		return
	}
	utils.SuccessResponse(c, "Payroll marked as paid", nil)
}
