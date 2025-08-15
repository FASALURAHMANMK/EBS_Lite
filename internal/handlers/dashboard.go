package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

// DashboardHandler handles dashboard related endpoints

type DashboardHandler struct {
	dashboardService *services.DashboardService
}

// NewDashboardHandler creates a new DashboardHandler
func NewDashboardHandler() *DashboardHandler {
	return &DashboardHandler{
		dashboardService: services.NewDashboardService(),
	}
}

// GET /dashboard/metrics
func (h *DashboardHandler) GetMetrics(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	if locParam := c.Query("location_id"); locParam != "" {
		if id, err := strconv.Atoi(locParam); err == nil {
			locationID = id
		}
	}

	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	metrics, err := h.dashboardService.GetMetrics(companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get metrics", err)
		return
	}

	utils.SuccessResponse(c, "Dashboard metrics retrieved successfully", metrics)
}

// GET /dashboard/quick-actions
func (h *DashboardHandler) GetQuickActions(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	if locParam := c.Query("location_id"); locParam != "" {
		if id, err := strconv.Atoi(locParam); err == nil {
			locationID = id
		}
	}

	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	counts, err := h.dashboardService.GetQuickActionCounts(companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get quick actions", err)
		return
	}

	utils.SuccessResponse(c, "Quick action counts retrieved successfully", counts)
}
