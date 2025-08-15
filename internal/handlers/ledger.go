package handlers

import (
	"net/http"

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
