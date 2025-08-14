package handlers

import (
	"net/http"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type AttendanceHandler struct {
	attendanceService *services.AttendanceService
}

func NewAttendanceHandler() *AttendanceHandler {
	return &AttendanceHandler{attendanceService: services.NewAttendanceService()}
}

// POST /attendance/check-in
func (h *AttendanceHandler) CheckIn(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.CheckInRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	att, err := h.attendanceService.CheckIn(companyID, req.EmployeeID)
	if err != nil {
		if err.Error() == "employee not found" {
			utils.NotFoundResponse(c, "Employee not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to check in", err)
		return
	}
	utils.CreatedResponse(c, "Check-in recorded", att)
}

// POST /attendance/check-out
func (h *AttendanceHandler) CheckOut(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.CheckOutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	att, err := h.attendanceService.CheckOut(companyID, req.EmployeeID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to check out", err)
		return
	}
	utils.SuccessResponse(c, "Check-out recorded", att)
}

// POST /attendance/leave
func (h *AttendanceHandler) ApplyLeave(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.LeaveRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	leave, err := h.attendanceService.ApplyLeave(companyID, &req)
	if err != nil {
		if err.Error() == "employee not found" {
			utils.NotFoundResponse(c, "Employee not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to apply leave", err)
		return
	}
	utils.CreatedResponse(c, "Leave applied", leave)
}

// GET /attendance/holidays
func (h *AttendanceHandler) GetHolidays(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	holidays, err := h.attendanceService.GetHolidays(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get holidays", err)
		return
	}
	utils.SuccessResponse(c, "Holidays retrieved", holidays)
}
