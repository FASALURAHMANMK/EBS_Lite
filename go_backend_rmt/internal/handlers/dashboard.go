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

func (h *DashboardHandler) dashboardScope(c *gin.Context) (int, *int, bool) {
	companyID := c.GetInt("company_id")
	var locationID *int

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return 0, nil, false
	}

	if locParam := c.Query("location_id"); locParam != "" {
		if id, err := strconv.Atoi(locParam); err == nil {
			locationID = &id
		}
	} else if lid := c.GetInt("location_id"); lid != 0 {
		locationID = &lid
	}

	return companyID, locationID, true
}

// GET /dashboard/overview
// location_id is optional; if omitted, aggregates across all locations in the company
func (h *DashboardHandler) GetOverview(c *gin.Context) {
	companyID, locationID, ok := h.dashboardScope(c)
	if !ok {
		return
	}

	overview, err := h.dashboardService.GetOverview(companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get dashboard overview", err)
		return
	}

	utils.SuccessResponse(c, "Dashboard overview retrieved successfully", overview)
}

// GET /dashboard/metrics
// location_id is optional; if omitted, aggregates across all locations in the company
func (h *DashboardHandler) GetMetrics(c *gin.Context) {
	companyID, locationID, ok := h.dashboardScope(c)
	if !ok {
		return
	}

	metrics, err := h.dashboardService.GetMetrics(companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get metrics", err)
		return
	}

	utils.SuccessResponse(c, "Dashboard metrics retrieved successfully", metrics)
}

// GET /dashboard/quick-actions returns quick action counts including
// today's sales, purchases, collections, vouchers and low stock items.
// location_id is optional; if omitted, aggregates across all locations in the company.
func (h *DashboardHandler) GetQuickActions(c *gin.Context) {
	companyID, locationID, ok := h.dashboardScope(c)
	if !ok {
		return
	}

	counts, err := h.dashboardService.GetQuickActionCounts(companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get quick actions", err)
		return
	}

	utils.SuccessResponse(c, "Quick action counts retrieved successfully", counts)
}
