package handlers

import (
	"net/http"

	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

// AuditLogHandler handles retrieval of audit logs
type AuditLogHandler struct {
	service *services.AuditLogService
}

func NewAuditLogHandler() *AuditLogHandler {
	return &AuditLogHandler{service: services.NewAuditLogService()}
}

// GET /audit-logs
func (h *AuditLogHandler) GetAuditLogs(c *gin.Context) {
	filters := map[string]string{
		"user_id":   c.Query("user_id"),
		"action":    c.Query("action"),
		"from_date": c.Query("from_date"),
		"to_date":   c.Query("to_date"),
	}

	logs, err := h.service.GetAuditLogs(filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get audit logs", err)
		return
	}
	utils.SuccessResponse(c, "Audit logs retrieved successfully", logs)
}
