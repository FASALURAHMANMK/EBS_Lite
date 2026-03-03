package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type NotificationsHandler struct {
	service *services.NotificationsService
}

func NewNotificationsHandler() *NotificationsHandler {
	return &NotificationsHandler{service: services.NewNotificationsService()}
}

// GET /notifications
func (h *NotificationsHandler) List(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	locationID := c.GetInt("location_id")

	var locPtr *int
	// Allow overriding by query param (useful for admin dashboards).
	if v := c.Query("location_id"); v != "" {
		if id, err := strconv.Atoi(v); err == nil {
			locationID = id
		}
	}
	if locationID != 0 {
		locPtr = &locationID
	}

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	if userID == 0 {
		utils.ForbiddenResponse(c, "User access required")
		return
	}

	list, err := h.service.ListNotifications(companyID, userID, locPtr)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to load notifications", err)
		return
	}
	utils.SuccessResponse(c, "Notifications retrieved", list)
}

// GET /notifications/unread-count
func (h *NotificationsHandler) UnreadCount(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	locationID := c.GetInt("location_id")

	var locPtr *int
	if v := c.Query("location_id"); v != "" {
		if id, err := strconv.Atoi(v); err == nil {
			locationID = id
		}
	}
	if locationID != 0 {
		locPtr = &locationID
	}

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	if userID == 0 {
		utils.ForbiddenResponse(c, "User access required")
		return
	}

	n, err := h.service.UnreadCount(companyID, userID, locPtr)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get unread count", err)
		return
	}
	utils.SuccessResponse(c, "Unread count retrieved", gin.H{"unread": n})
}

// POST /notifications/mark-read
func (h *NotificationsHandler) MarkRead(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	if userID == 0 {
		utils.ForbiddenResponse(c, "User access required")
		return
	}

	var req models.MarkNotificationsReadRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	if err := h.service.MarkRead(companyID, userID, req.Keys); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to mark notifications read", err)
		return
	}

	utils.SuccessResponse(c, "Notifications marked read", nil)
}
