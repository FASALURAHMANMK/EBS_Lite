package handlers

import (
	"net/http"
	"strconv"
	"strings"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type FinanceIntegrityHandler struct {
	service *services.FinanceIntegrityService
}

func NewFinanceIntegrityHandler() *FinanceIntegrityHandler {
	return &FinanceIntegrityHandler{service: services.NewFinanceIntegrityService()}
}

func (h *FinanceIntegrityHandler) GetDiagnostics(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	limit := 25
	if raw := strings.TrimSpace(c.Query("limit")); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	diagnostics, err := h.service.GetDiagnostics(companyID, limit, c.Query("status"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to load finance diagnostics", err)
		return
	}
	utils.SuccessResponse(c, "Finance diagnostics retrieved successfully", diagnostics)
}

func (h *FinanceIntegrityHandler) Replay(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req models.FinanceReplayRequest
	if err := c.ShouldBindJSON(&req); err != nil && err.Error() != "EOF" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	limit := 50
	if req.Limit != nil && *req.Limit > 0 {
		limit = *req.Limit
	}
	result, err := h.service.Replay(companyID, req.OutboxIDs, limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to replay finance outbox entries", err)
		return
	}
	utils.SuccessResponse(c, "Finance outbox replay completed", result)
}

func (h *FinanceIntegrityHandler) RepairMissingLedger(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req models.FinanceRepairLedgerRequest
	if err := c.ShouldBindJSON(&req); err != nil && err.Error() != "EOF" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	limit := 50
	if req.Limit != nil && *req.Limit > 0 {
		limit = *req.Limit
	}
	result, err := h.service.RepairMissingLedger(companyID, userID, limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to repair missing ledger postings", err)
		return
	}
	utils.SuccessResponse(c, "Missing ledger postings repaired", result)
}
