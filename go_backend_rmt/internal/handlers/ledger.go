package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type LedgerHandler struct {
	service *services.LedgerService
}

func NewLedgerHandler() *LedgerHandler {
	return &LedgerHandler{service: services.NewLedgerService()}
}

// GET /ledgers
func (h *LedgerHandler) GetBalances(c *gin.Context) {
	companyID := c.GetInt("company_id")

	balances, err := h.service.GetAccountBalances(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get balances", err)
		return
	}
	utils.SuccessResponse(c, "Ledger balances retrieved", balances)
}

// GET /ledgers/:account_id/entries
func (h *LedgerHandler) GetEntries(c *gin.Context) {
	companyID := c.GetInt("company_id")
	accountID, err := strconv.Atoi(c.Param("account_id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid account ID", err)
		return
	}

	filters := map[string]string{}
	if v := c.Query("date_from"); v != "" {
		filters["date_from"] = v
	}
	if v := c.Query("date_to"); v != "" {
		filters["date_to"] = v
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	perPage, _ := strconv.Atoi(c.DefaultQuery("per_page", "20"))

	entries, total, err := h.service.GetAccountEntries(companyID, accountID, filters, page, perPage)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get ledger entries", err)
		return
	}

	totalPages := 0
	if perPage > 0 {
		totalPages = (total + perPage - 1) / perPage
	}
	meta := &models.Meta{Page: page, PerPage: perPage, Total: total, TotalPages: totalPages}
	utils.PaginatedResponse(c, "Ledger entries retrieved", entries, meta)
}
