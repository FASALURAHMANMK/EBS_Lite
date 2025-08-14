package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type RoleHandler struct {
	roleService *services.RoleService
}

func NewRoleHandler() *RoleHandler {
	return &RoleHandler{
		roleService: services.NewRoleService(),
	}
}

// GET /roles
func (h *RoleHandler) GetRoles(c *gin.Context) {
	roles, err := h.roleService.GetRoles()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get roles", err)
		return
	}

	utils.SuccessResponse(c, "Roles retrieved successfully", roles)
}

// POST /roles
func (h *RoleHandler) CreateRole(c *gin.Context) {
	var req models.CreateRoleRequest
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

	role, err := h.roleService.CreateRole(&req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create role", err)
		return
	}

	utils.CreatedResponse(c, "Role created successfully", role)
}

// PUT /roles/:id
func (h *RoleHandler) UpdateRole(c *gin.Context) {
	roleID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid role ID", err)
		return
	}

	var req models.UpdateRoleRequest
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

	err = h.roleService.UpdateRole(roleID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update role", err)
		return
	}

	utils.SuccessResponse(c, "Role updated successfully", nil)
}

// DELETE /roles/:id
func (h *RoleHandler) DeleteRole(c *gin.Context) {
	roleID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid role ID", err)
		return
	}

	err = h.roleService.DeleteRole(roleID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete role", err)
		return
	}

	utils.SuccessResponse(c, "Role deleted successfully", nil)
}

// GET /permissions
func (h *RoleHandler) GetPermissions(c *gin.Context) {
	permissions, err := h.roleService.GetPermissions()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get permissions", err)
		return
	}

	utils.SuccessResponse(c, "Permissions retrieved successfully", permissions)
}

// GET /roles/:id/permissions
func (h *RoleHandler) GetRolePermissions(c *gin.Context) {
	roleID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid role ID", err)
		return
	}

	roleWithPermissions, err := h.roleService.GetRolePermissions(roleID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get role permissions", err)
		return
	}

	utils.SuccessResponse(c, "Role permissions retrieved successfully", roleWithPermissions)
}

// POST /roles/:id/permissions
func (h *RoleHandler) AssignPermissions(c *gin.Context) {
	roleID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid role ID", err)
		return
	}

	var req models.AssignPermissionsRequest
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

	err = h.roleService.AssignPermissions(roleID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to assign permissions", err)
		return
	}

	utils.SuccessResponse(c, "Permissions assigned successfully", nil)
}
