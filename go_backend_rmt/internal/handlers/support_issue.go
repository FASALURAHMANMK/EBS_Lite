package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type SupportIssueHandler struct {
	service *services.SupportIssueService
}

func NewSupportIssueHandler() *SupportIssueHandler {
	return &SupportIssueHandler{service: services.NewSupportIssueService()}
}

// POST /support/issues
func (h *SupportIssueHandler) CreateIssue(c *gin.Context) {
	var req models.CreateSupportIssueRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	locationID := c.GetInt("location_id")
	if companyID == 0 || userID == 0 {
		utils.ForbiddenResponse(c, "Company and user access required")
		return
	}

	var locationPtr *int
	if locationID != 0 {
		locationPtr = &locationID
	}

	issue, err := h.service.CreateIssue(companyID, userID, locationPtr, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create support issue", err)
		return
	}

	utils.CreatedResponse(c, "Support issue created successfully", issue)
}

// GET /support/issues
func (h *SupportIssueHandler) ListIssues(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	limit := 50
	if raw := c.Query("limit"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil {
			limit = parsed
		}
	}

	issues, err := h.service.ListIssues(companyID, models.SupportIssueListFilters{
		Status:   c.Query("status"),
		Severity: c.Query("severity"),
		Limit:    limit,
	})
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to list support issues", err)
		return
	}

	utils.SuccessResponse(c, "Support issues retrieved successfully", issues)
}

// GET /support/issues/:id
func (h *SupportIssueHandler) GetIssue(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	issueID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid issue id", err)
		return
	}

	issue, err := h.service.GetIssueByID(companyID, issueID)
	if err != nil {
		if err.Error() == "support issue not found" {
			utils.NotFoundResponse(c, "Support issue not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get support issue", err)
		return
	}

	utils.SuccessResponse(c, "Support issue retrieved successfully", issue)
}
