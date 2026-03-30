package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

// WorkflowHandler manages workflow approval requests
type WorkflowHandler struct {
	service *services.WorkflowService
}

func NewWorkflowHandler() *WorkflowHandler {
	return &WorkflowHandler{service: services.NewWorkflowService()}
}

// GET /workflow-requests
func (h *WorkflowHandler) GetWorkflowRequests(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 || userID == 0 {
		utils.ForbiddenResponse(c, "Company and user access required")
		return
	}
	requests, err := h.service.ListRequests(companyID, userID, c.Query("status"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get workflow requests", err)
		return
	}
	utils.SuccessResponse(c, "Workflow requests retrieved successfully", requests)
}

// GET /workflow-requests/:id
func (h *WorkflowHandler) GetWorkflowRequest(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 || userID == 0 {
		utils.ForbiddenResponse(c, "Company and user access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request id", err)
		return
	}
	request, err := h.service.GetRequestByID(companyID, userID, id)
	if err != nil {
		if err.Error() == "workflow request not found" {
			utils.NotFoundResponse(c, "Workflow request not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get workflow request", err)
		return
	}
	utils.SuccessResponse(c, "Workflow request retrieved successfully", request)
}

// POST /workflow-requests
func (h *WorkflowHandler) CreateWorkflowRequest(c *gin.Context) {
	var req models.CreateWorkflowRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	userID := c.GetInt("user_id")
	companyID := c.GetInt("company_id")
	request, err := h.service.CreateRequest(companyID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create workflow request", err)
		return
	}
	utils.CreatedResponse(c, "Workflow request created successfully", request)
}

// PUT /workflow-requests/:id/approve
func (h *WorkflowHandler) ApproveWorkflowRequest(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request id", err)
		return
	}

	var req models.DecisionRequest
	if err := c.ShouldBindJSON(&req); err != nil && err.Error() != "EOF" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	userID := c.GetInt("user_id")
	companyID := c.GetInt("company_id")
	if err := h.service.ApproveRequest(companyID, id, userID, req.Remarks); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to approve workflow request", err)
		return
	}
	utils.SuccessResponse(c, "Workflow request approved", nil)
}

// PUT /workflow-requests/:id/reject
func (h *WorkflowHandler) RejectWorkflowRequest(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request id", err)
		return
	}

	var req models.DecisionRequest
	if err := c.ShouldBindJSON(&req); err != nil && err.Error() != "EOF" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	userID := c.GetInt("user_id")
	companyID := c.GetInt("company_id")
	if err := h.service.RejectRequest(companyID, id, userID, req.Remarks); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to reject workflow request", err)
		return
	}
	utils.SuccessResponse(c, "Workflow request rejected", nil)
}
