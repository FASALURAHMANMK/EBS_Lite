package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type CashRegisterHandler struct {
	service *services.CashRegisterService
}

func NewCashRegisterHandler() *CashRegisterHandler {
	return &CashRegisterHandler{service: services.NewCashRegisterService()}
}

// GET /cash-registers
func (h *CashRegisterHandler) GetCashRegisters(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	if loc := c.Query("location_id"); loc != "" {
		if id, err := strconv.Atoi(loc); err == nil {
			locationID = id
		}
	}

	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	registers, err := h.service.GetCashRegisters(companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get cash registers", err)
		return
	}

	utils.SuccessResponse(c, "Cash registers retrieved successfully", registers)
}

// POST /cash-registers/open
func (h *CashRegisterHandler) OpenCashRegister(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")
	sessionID := c.GetString("session_id")
	requestID := c.GetString("request_id")
	ip := c.ClientIP()
	ua := c.GetHeader("User-Agent")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	if loc := c.Query("location_id"); loc != "" {
		if id, err := strconv.Atoi(loc); err == nil {
			locationID = id
		}
	}

	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	var req models.OpenCashRegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	id, err := h.service.OpenCashRegister(
		companyID,
		locationID,
		userID,
		req.OpeningBalance,
		sessionID,
		requestID,
		&ip,
		&ua,
	)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to open cash register", err)
		return
	}

	utils.CreatedResponse(c, "Cash register opened successfully", gin.H{"register_id": id})
}

// POST /cash-registers/close
func (h *CashRegisterHandler) CloseCashRegister(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")
	sessionID := c.GetString("session_id")
	requestID := c.GetString("request_id")
	ip := c.ClientIP()
	ua := c.GetHeader("User-Agent")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	if loc := c.Query("location_id"); loc != "" {
		if id, err := strconv.Atoi(loc); err == nil {
			locationID = id
		}
	}

	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	var req models.CloseCashRegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	err := h.service.CloseCashRegister(
		companyID,
		locationID,
		userID,
		req.ClosingBalance,
		req.Denominations,
		sessionID,
		requestID,
		&ip,
		&ua,
	)
	if err != nil {
		if err.Error() == "no open cash register" {
			utils.ErrorResponse(c, http.StatusBadRequest, "No open cash register", err)
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to close cash register", err)
		return
	}

	utils.SuccessResponse(c, "Cash register closed successfully", nil)
}

// POST /cash-registers/training/enable
func (h *CashRegisterHandler) EnableTrainingMode(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")
	sessionID := c.GetString("session_id")
	requestID := c.GetString("request_id")
	ip := c.ClientIP()
	ua := c.GetHeader("User-Agent")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	if loc := c.Query("location_id"); loc != "" {
		if id, err := strconv.Atoi(loc); err == nil {
			locationID = id
		}
	}
	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	if err := h.service.SetTrainingMode(companyID, locationID, userID, true, sessionID, requestID, &ip, &ua); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to enable training mode", err)
		return
	}

	utils.SuccessResponse(c, "Training mode enabled", gin.H{"training_mode": true})
}

// POST /cash-registers/training/disable
func (h *CashRegisterHandler) DisableTrainingMode(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")
	sessionID := c.GetString("session_id")
	requestID := c.GetString("request_id")
	ip := c.ClientIP()
	ua := c.GetHeader("User-Agent")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	if loc := c.Query("location_id"); loc != "" {
		if id, err := strconv.Atoi(loc); err == nil {
			locationID = id
		}
	}
	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	if err := h.service.SetTrainingMode(companyID, locationID, userID, false, sessionID, requestID, &ip, &ua); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to disable training mode", err)
		return
	}

	utils.SuccessResponse(c, "Training mode disabled", gin.H{"training_mode": false})
}

// POST /cash-registers/tally
func (h *CashRegisterHandler) RecordTally(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")
	sessionID := c.GetString("session_id")
	requestID := c.GetString("request_id")
	ip := c.ClientIP()
	ua := c.GetHeader("User-Agent")

	var req models.CashTallyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	if err := h.service.RecordTally(
		companyID,
		locationID,
		userID,
		req.Count,
		req.Notes,
		req.Denominations,
		sessionID,
		requestID,
		&ip,
		&ua,
	); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to record tally", err)
		return
	}
	utils.SuccessResponse(c, "Cash tally recorded", nil)
}

// POST /cash-registers/movement
func (h *CashRegisterHandler) RecordMovement(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")
	sessionID := c.GetString("session_id")
	requestID := c.GetString("request_id")
	ip := c.ClientIP()
	ua := c.GetHeader("User-Agent")

	if loc := c.Query("location_id"); loc != "" {
		if id, err := strconv.Atoi(loc); err == nil {
			locationID = id
		}
	}
	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	var req models.CashRegisterMovementRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	id, err := h.service.RecordMovement(companyID, locationID, userID, &req, sessionID, requestID, &ip, &ua)
	if err != nil {
		if err.Error() == "no open cash register" {
			utils.ErrorResponse(c, http.StatusBadRequest, "No open cash register", err)
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to record movement", err)
		return
	}

	utils.CreatedResponse(c, "Cash movement recorded", gin.H{"event_id": id})
}

// POST /cash-registers/force-close
func (h *CashRegisterHandler) ForceClose(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")
	sessionID := c.GetString("session_id")
	requestID := c.GetString("request_id")
	ip := c.ClientIP()
	ua := c.GetHeader("User-Agent")

	if loc := c.Query("location_id"); loc != "" {
		if id, err := strconv.Atoi(loc); err == nil {
			locationID = id
		}
	}
	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	var req models.ForceCloseCashRegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	if err := h.service.ForceClose(companyID, locationID, userID, &req, sessionID, requestID, &ip, &ua); err != nil {
		if err.Error() == "no open cash register" {
			utils.ErrorResponse(c, http.StatusBadRequest, "No open cash register", err)
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to force close cash register", err)
		return
	}

	utils.SuccessResponse(c, "Cash register force-closed successfully", nil)
}

// GET /cash-registers/events
func (h *CashRegisterHandler) GetEvents(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	if loc := c.Query("location_id"); loc != "" {
		if id, err := strconv.Atoi(loc); err == nil {
			locationID = id
		}
	}
	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	var regID *int
	if v := c.Query("register_id"); v != "" {
		if id, err := strconv.Atoi(v); err == nil && id > 0 {
			regID = &id
		}
	}
	limit := 200
	if v := c.Query("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			limit = n
		}
	}

	events, err := h.service.GetEvents(companyID, locationID, regID, limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get events", err)
		return
	}

	utils.SuccessResponse(c, "Cash register events retrieved successfully", events)
}
