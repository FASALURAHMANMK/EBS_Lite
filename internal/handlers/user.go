package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type UserHandler struct {
	userService *services.UserService
}

func NewUserHandler() *UserHandler {
	return &UserHandler{
		userService: services.NewUserService(),
	}
}

// GET /users
func (h *UserHandler) GetUsers(c *gin.Context) {
	// Get query parameters
	var companyID *int
	var locationID *int

	if companyParam := c.Query("company_id"); companyParam != "" {
		if id, err := strconv.Atoi(companyParam); err == nil {
			companyID = &id
		}
	}

	if locationParam := c.Query("location_id"); locationParam != "" {
		if id, err := strconv.Atoi(locationParam); err == nil {
			locationID = &id
		}
	}

	// For non-admin users, restrict to their company
	userCompanyID := c.GetInt("company_id")
	if companyID == nil || *companyID != userCompanyID {
		companyID = &userCompanyID
	}

	users, err := h.userService.GetUsers(companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get users", err)
		return
	}

	utils.SuccessResponse(c, "Users retrieved successfully", users)
}

// POST /users
func (h *UserHandler) CreateUser(c *gin.Context) {
	var req models.CreateUserRequest
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

	// Ensure user can only create users in their company
	userCompanyID := c.GetInt("company_id")
	if req.CompanyID != userCompanyID {
		utils.ForbiddenResponse(c, "Cannot create users for other companies")
		return
	}

	user, err := h.userService.CreateUser(&req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create user", err)
		return
	}

	utils.CreatedResponse(c, "User created successfully", user)
}

// PUT /users/:id
func (h *UserHandler) UpdateUser(c *gin.Context) {
	userID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid user ID", err)
		return
	}

	var req models.UpdateUserRequest
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

	err = h.userService.UpdateUser(userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update user", err)
		return
	}

	utils.SuccessResponse(c, "User updated successfully", nil)
}

// DELETE /users/:id
func (h *UserHandler) DeleteUser(c *gin.Context) {
	userID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid user ID", err)
		return
	}

	// Prevent users from deleting themselves
	currentUserID := c.GetInt("user_id")
	if userID == currentUserID {
		utils.ErrorResponse(c, http.StatusBadRequest, "Cannot delete your own account", nil)
		return
	}

	err = h.userService.DeleteUser(userID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete user", err)
		return
	}

	utils.SuccessResponse(c, "User deleted successfully", nil)
}
