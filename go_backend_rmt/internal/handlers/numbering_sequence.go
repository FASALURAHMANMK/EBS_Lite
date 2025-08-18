package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type NumberingSequenceHandler struct {
	service *services.NumberingSequenceService
}

func NewNumberingSequenceHandler() *NumberingSequenceHandler {
	return &NumberingSequenceHandler{service: services.NewNumberingSequenceService()}
}

// GET /numbering-sequences
func (h *NumberingSequenceHandler) GetNumberingSequences(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var locationID *int
	if loc := c.Query("location_id"); loc != "" {
		if id, err := strconv.Atoi(loc); err == nil {
			locationID = &id
		}
	} else if userLoc := c.GetInt("location_id"); userLoc != 0 {
		locationID = &userLoc
	}

	sequences, err := h.service.GetNumberingSequences(companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get numbering sequences", err)
		return
	}
	utils.SuccessResponse(c, "Numbering sequences retrieved successfully", sequences)
}

// GET /numbering-sequences/:id
func (h *NumberingSequenceHandler) GetNumberingSequence(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid sequence ID", err)
		return
	}
	var locationID *int
	if loc := c.Query("location_id"); loc != "" {
		if lid, err := strconv.Atoi(loc); err == nil {
			locationID = &lid
		}
	} else if userLoc := c.GetInt("location_id"); userLoc != 0 {
		locationID = &userLoc
	}

	seq, err := h.service.GetNumberingSequenceByID(id, companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to get numbering sequence", err)
		return
	}
	utils.SuccessResponse(c, "Numbering sequence retrieved successfully", seq)
}

// POST /numbering-sequences
func (h *NumberingSequenceHandler) CreateNumberingSequence(c *gin.Context) {
	var req models.CreateNumberingSequenceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	userCompanyID := c.GetInt("company_id")
	if req.CompanyID != userCompanyID {
		utils.ForbiddenResponse(c, "Cannot create numbering sequences for other companies")
		return
	}
	if userLoc := c.GetInt("location_id"); userLoc != 0 && req.LocationID != nil && *req.LocationID != userLoc {
		utils.ForbiddenResponse(c, "Cannot create numbering sequences for other locations")
		return
	}

	seq, err := h.service.CreateNumberingSequence(&req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create numbering sequence", err)
		return
	}
	utils.CreatedResponse(c, "Numbering sequence created successfully", seq)
}

// PUT /numbering-sequences/:id
func (h *NumberingSequenceHandler) UpdateNumberingSequence(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid sequence ID", err)
		return
	}
	var req models.UpdateNumberingSequenceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}
	companyID := c.GetInt("company_id")
	var locationID *int
	if userLoc := c.GetInt("location_id"); userLoc != 0 {
		locationID = &userLoc
	}
	err = h.service.UpdateNumberingSequence(id, companyID, locationID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update numbering sequence", err)
		return
	}
	utils.SuccessResponse(c, "Numbering sequence updated successfully", nil)
}

// DELETE /numbering-sequences/:id
func (h *NumberingSequenceHandler) DeleteNumberingSequence(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid sequence ID", err)
		return
	}
	companyID := c.GetInt("company_id")
	var locationID *int
	if userLoc := c.GetInt("location_id"); userLoc != 0 {
		locationID = &userLoc
	}
	err = h.service.DeleteNumberingSequence(id, companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete numbering sequence", err)
		return
	}
	utils.SuccessResponse(c, "Numbering sequence deleted successfully", nil)
}
