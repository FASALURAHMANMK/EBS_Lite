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
	requests, err := h.service.GetPendingRequests()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get workflow requests", err)
		return
	}
	utils.SuccessResponse(c, "Workflow requests retrieved successfully", requests)
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
	request, err := h.service.CreateRequest(userID, &req)
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
	if err := h.service.ApproveRequest(id, userID, req.Remarks); err != nil {
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
	if err := h.service.RejectRequest(id, userID, req.Remarks); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to reject workflow request", err)
		return
	}
	utils.SuccessResponse(c, "Workflow request rejected", nil)
}
