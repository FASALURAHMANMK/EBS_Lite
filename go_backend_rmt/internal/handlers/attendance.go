package handlers

import (
	"net/http"
	"strconv"
	"time"

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

// GET /attendance/records
func (h *AttendanceHandler) GetAttendanceRecords(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var employeeID *int
	if idStr := c.Query("employee_id"); idStr != "" {
		id, err := strconv.Atoi(idStr)
		if err != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, "Invalid employee_id", err)
			return
		}
		employeeID = &id
	}

	var startDate, endDate *time.Time
	if sdStr := c.Query("start_date"); sdStr != "" {
		sd, err := time.Parse("2006-01-02", sdStr)
		if err != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, "Invalid start_date", err)
			return
		}
		startDate = &sd
	}
	if edStr := c.Query("end_date"); edStr != "" {
		ed, err := time.Parse("2006-01-02", edStr)
		if err != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, "Invalid end_date", err)
			return
		}
		endDate = &ed
	}

	records, err := h.attendanceService.GetAttendanceRecords(companyID, employeeID, startDate, endDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get attendance records", err)
		return
	}
	utils.SuccessResponse(c, "Attendance records retrieved", records)
}

// GET /attendance/leaves
func (h *AttendanceHandler) GetLeaves(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	filters := map[string]string{}
	if status := c.Query("status"); status != "" {
		filters["status"] = status
	}
	if empID := c.Query("employee_id"); empID != "" {
		filters["employee_id"] = empID
	}

	leaves, err := h.attendanceService.ListLeaves(companyID, filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to list leaves", err)
		return
	}
	utils.SuccessResponse(c, "Leaves retrieved", leaves)
}

// PUT /attendance/leaves/:id/approve
func (h *AttendanceHandler) ApproveLeave(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	leaveID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid leave ID", err)
		return
	}
	var req models.LeaveDecisionRequest
	_ = c.ShouldBindJSON(&req)
	userID := c.GetInt("user_id")
	if err := h.attendanceService.DecideLeave(companyID, leaveID, userID, true, req.DecisionNotes); err != nil {
		if err.Error() == "leave not found" {
			utils.NotFoundResponse(c, "Leave not found or not pending")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to approve leave", err)
		return
	}
	utils.SuccessResponse(c, "Leave approved", nil)
}

// PUT /attendance/leaves/:id/reject
func (h *AttendanceHandler) RejectLeave(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	leaveID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid leave ID", err)
		return
	}
	var req models.LeaveDecisionRequest
	_ = c.ShouldBindJSON(&req)
	userID := c.GetInt("user_id")
	if err := h.attendanceService.DecideLeave(companyID, leaveID, userID, false, req.DecisionNotes); err != nil {
		if err.Error() == "leave not found" {
			utils.NotFoundResponse(c, "Leave not found or not pending")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to reject leave", err)
		return
	}
	utils.SuccessResponse(c, "Leave rejected", nil)
}
