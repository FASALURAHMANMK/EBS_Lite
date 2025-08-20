package handlers

import (
	"net/http"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	authService *services.AuthService
}

func NewAuthHandler() *AuthHandler {
	return &AuthHandler{
		authService: services.NewAuthService(),
	}
}

// POST /auth/login
func (h *AuthHandler) Login(c *gin.Context) {
	var req models.LoginRequest
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

	ipAddress := c.ClientIP()
	userAgent := c.GetHeader("User-Agent")

	// Authenticate user
	response, err := h.authService.Login(&req, ipAddress, userAgent)
	if err != nil {
		utils.ErrorResponse(c, http.StatusUnauthorized, "Authentication failed", err)
		return
	}

	utils.SuccessResponse(c, "Login successful", response)
}

// POST /auth/logout
func (h *AuthHandler) Logout(c *gin.Context) {
       userID := c.GetInt("user_id")
       sessionID := c.GetString("session_id")
       if userID == 0 || sessionID == "" {
               utils.ForbiddenResponse(c, "User session not found")
               return
       }
       if err := h.authService.Logout(userID, sessionID); err != nil {
               utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to logout", err)
               return
       }
       utils.SuccessResponse(c, "Logout successful", nil)
}

// POST /auth/refresh-token
func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var req models.RefreshTokenRequest
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

	// Refresh token
	response, err := h.authService.RefreshToken(&req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusUnauthorized, "Token refresh failed", err)
		return
	}

	utils.SuccessResponse(c, "Token refreshed successfully", response)
}

// GET /auth/me
func (h *AuthHandler) GetMe(c *gin.Context) {
	userID := c.GetInt("user_id")
	if userID == 0 {
		utils.UnauthorizedResponse(c, "User context not found")
		return
	}

	user, err := h.authService.GetMe(userID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get user details", err)
		return
	}

	utils.SuccessResponse(c, "User details retrieved successfully", user)
}

// POST /auth/forgot-password
func (h *AuthHandler) ForgotPassword(c *gin.Context) {
	var req models.ForgotPasswordRequest
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

	err := h.authService.ForgotPassword(&req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to process password reset", err)
		return
	}

	utils.SuccessResponse(c, "Password reset instructions sent", nil)
}

// POST /auth/reset-password
func (h *AuthHandler) ResetPassword(c *gin.Context) {
	var req models.ResetPasswordRequest
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

	err := h.authService.ResetPassword(&req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to reset password", err)
		return
	}

	utils.SuccessResponse(c, "Password successfully reset", nil)
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req models.RegisterRequest
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

	// Register user
	response, err := h.authService.Register(&req)
	if err != nil {
		if err.Error() == "username or email already exists" {
			utils.ConflictResponse(c, "Username or email already exists")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Registration failed", err)
		return
	}

	utils.CreatedResponse(c, "Registration successful", response)
}
