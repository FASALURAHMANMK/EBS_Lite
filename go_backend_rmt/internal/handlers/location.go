package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type LocationHandler struct {
	locationService *services.LocationService
}

func NewLocationHandler() *LocationHandler {
	return &LocationHandler{
		locationService: services.NewLocationService(),
	}
}

// GET /locations
func (h *LocationHandler) GetLocations(c *gin.Context) {
	// Get query parameters
	var companyID *int

	if companyParam := c.Query("company_id"); companyParam != "" {
		if id, err := strconv.Atoi(companyParam); err == nil {
			companyID = &id
		}
	}

	// For non-admin users, restrict to their company
	userCompanyID := c.GetInt("company_id")
	if companyID == nil || *companyID != userCompanyID {
		companyID = &userCompanyID
	}

	locations, err := h.locationService.GetLocations(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get locations", err)
		return
	}

	utils.SuccessResponse(c, "Locations retrieved successfully", locations)
}

// POST /locations
func (h *LocationHandler) CreateLocation(c *gin.Context) {
	var req models.CreateLocationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	// Validate request
	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	// Ensure user can only create locations in their company
	userCompanyID := c.GetInt("company_id")
	if req.CompanyID != userCompanyID {
		utils.ForbiddenResponse(c, "Cannot create locations for other companies")
		return
	}

	location, err := h.locationService.CreateLocation(&req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create location", err)
		return
	}

	utils.CreatedResponse(c, "Location created successfully", location)
}

// PUT /locations/:id
func (h *LocationHandler) UpdateLocation(c *gin.Context) {
	locationID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid location ID", err)
		return
	}

	var req models.UpdateLocationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	// Validate request
	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	err = h.locationService.UpdateLocation(locationID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update location", err)
		return
	}

	utils.SuccessResponse(c, "Location updated successfully", nil)
}

// DELETE /locations/:id
func (h *LocationHandler) DeleteLocation(c *gin.Context) {
	locationID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid location ID", err)
		return
	}

	err = h.locationService.DeleteLocation(locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete location", err)
		return
	}

	utils.SuccessResponse(c, "Location deleted successfully", nil)
}
