package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type AccountingPeriodHandler struct {
	service *services.AccountingAdminService
}

func NewAccountingPeriodHandler() *AccountingPeriodHandler {
	return &AccountingPeriodHandler{service: services.NewAccountingAdminService()}
}

func (h *AccountingPeriodHandler) List(c *gin.Context) {
	companyID := c.GetInt("company_id")
	items, err := h.service.ListAccountingPeriods(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to list accounting periods", err)
		return
	}
	utils.SuccessResponse(c, "Accounting periods retrieved", items)
}

func (h *AccountingPeriodHandler) Create(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	var req models.CreateAccountingPeriodRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.service.CreateAccountingPeriod(companyID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create accounting period", err)
		return
	}
	utils.CreatedResponse(c, "Accounting period created", item)
}

func (h *AccountingPeriodHandler) Close(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	periodID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid period ID", err)
		return
	}
	var req models.UpdateAccountingPeriodStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil && err.Error() != "EOF" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request", err)
		return
	}
	item, err := h.service.CloseAccountingPeriod(companyID, periodID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to close accounting period", err)
		return
	}
	utils.SuccessResponse(c, "Accounting period closed", item)
}

func (h *AccountingPeriodHandler) Reopen(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	periodID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid period ID", err)
		return
	}
	var req models.UpdateAccountingPeriodStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil && err.Error() != "EOF" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request", err)
		return
	}
	item, err := h.service.ReopenAccountingPeriod(companyID, periodID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to reopen accounting period", err)
		return
	}
	utils.SuccessResponse(c, "Accounting period reopened", item)
}
