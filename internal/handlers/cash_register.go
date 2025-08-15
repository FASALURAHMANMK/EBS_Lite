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

	id, err := h.service.OpenCashRegister(companyID, locationID, userID, req.OpeningBalance)
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

	err := h.service.CloseCashRegister(companyID, locationID, userID, req.ClosingBalance)
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

// POST /cash-registers/tally
func (h *CashRegisterHandler) RecordTally(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")

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

	if err := h.service.RecordTally(companyID, locationID, userID, req.Count, req.Notes); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to record tally", err)
		return
	}
	utils.SuccessResponse(c, "Cash tally recorded", nil)
}
