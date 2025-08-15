package handlers

import (
	"database/sql"
	"net/http"

	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type DeviceSessionHandler struct {
	service *services.DeviceSessionService
}

func NewDeviceSessionHandler() *DeviceSessionHandler {
	return &DeviceSessionHandler{
		service: services.NewDeviceSessionService(),
	}
}

// GET /device-sessions
func (h *DeviceSessionHandler) GetDeviceSessions(c *gin.Context) {
	userID := c.GetInt("user_id")
	companyID := c.GetInt("company_id")

	sessions, err := h.service.GetActiveSessions(userID, companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get device sessions", err)
		return
	}

	utils.SuccessResponse(c, "Device sessions retrieved successfully", sessions)
}

// DELETE /device-sessions/:session_id
func (h *DeviceSessionHandler) RevokeSession(c *gin.Context) {
	sessionID := c.Param("session_id")
	userID := c.GetInt("user_id")
	companyID := c.GetInt("company_id")

	err := h.service.RevokeSession(sessionID, userID, companyID)
	if err != nil {
		if err == sql.ErrNoRows {
			utils.NotFoundResponse(c, "Session not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to revoke session", err)
		return
	}

	utils.SuccessResponse(c, "Session revoked successfully", nil)
}
