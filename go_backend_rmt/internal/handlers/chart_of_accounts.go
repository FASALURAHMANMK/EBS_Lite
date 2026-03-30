package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type ChartOfAccountsHandler struct {
	service *services.AccountingAdminService
}

func NewChartOfAccountsHandler() *ChartOfAccountsHandler {
	return &ChartOfAccountsHandler{service: services.NewAccountingAdminService()}
}

func (h *ChartOfAccountsHandler) List(c *gin.Context) {
	companyID := c.GetInt("company_id")
	includeInactive := c.DefaultQuery("include_inactive", "false") == "true"
	items, err := h.service.ListChartOfAccounts(companyID, includeInactive)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to list chart of accounts", err)
		return
	}
	utils.SuccessResponse(c, "Chart of accounts retrieved", items)
}

func (h *ChartOfAccountsHandler) Create(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	var req models.CreateChartOfAccountRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.service.CreateChartOfAccount(companyID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create chart of account", err)
		return
	}
	utils.CreatedResponse(c, "Chart of account created", item)
}

func (h *ChartOfAccountsHandler) Update(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	accountID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid account ID", err)
		return
	}
	var req models.UpdateChartOfAccountRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.service.UpdateChartOfAccount(companyID, accountID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update chart of account", err)
		return
	}
	utils.SuccessResponse(c, "Chart of account updated", item)
}
