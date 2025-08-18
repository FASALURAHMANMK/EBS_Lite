package utils

import (
	"net/http"

	"erp-backend/internal/models"

	"github.com/gin-gonic/gin"
)

// SuccessResponse sends a success response
func SuccessResponse(c *gin.Context, message string, data interface{}) {
	response := models.APIResponse{
		Success: true,
		Message: message,
		Data:    data,
	}
	c.JSON(http.StatusOK, response)
}

// CreatedResponse sends a created response
func CreatedResponse(c *gin.Context, message string, data interface{}) {
	response := models.APIResponse{
		Success: true,
		Message: message,
		Data:    data,
	}
	c.JSON(http.StatusCreated, response)
}

// ErrorResponse sends an error response
func ErrorResponse(c *gin.Context, statusCode int, message string, err error) {
	response := models.APIResponse{
		Success: false,
		Message: message,
	}

	if err != nil {
		response.Error = err.Error()
	}

	c.JSON(statusCode, response)
}

// ValidationErrorResponse sends a validation error response
func ValidationErrorResponse(c *gin.Context, validationErrors map[string]string) {
	response := models.APIResponse{
		Success: false,
		Message: "Validation failed",
		Data:    validationErrors,
	}
	c.JSON(http.StatusBadRequest, response)
}

// PaginatedResponse sends a paginated response
func PaginatedResponse(c *gin.Context, message string, data interface{}, meta *models.Meta) {
	response := models.APIResponse{
		Success: true,
		Message: message,
		Data:    data,
		Meta:    meta,
	}
	c.JSON(http.StatusOK, response)
}

// NotFoundResponse sends a not found response
func NotFoundResponse(c *gin.Context, message string) {
	response := models.APIResponse{
		Success: false,
		Message: message,
	}
	c.JSON(http.StatusNotFound, response)
}

// UnauthorizedResponse sends an unauthorized response
func UnauthorizedResponse(c *gin.Context, message string) {
	response := models.APIResponse{
		Success: false,
		Message: message,
	}
	c.JSON(http.StatusUnauthorized, response)
}

// ForbiddenResponse sends a forbidden response
func ForbiddenResponse(c *gin.Context, message string) {
	response := models.APIResponse{
		Success: false,
		Message: message,
	}
	c.JSON(http.StatusForbidden, response)
}

// ConflictResponse sends a conflict response
func ConflictResponse(c *gin.Context, message string) {
	response := models.APIResponse{
		Success: false,
		Message: message,
	}
	c.JSON(http.StatusConflict, response)
}

// InternalServerErrorResponse sends an internal server error response
func InternalServerErrorResponse(c *gin.Context, message string, err error) {
	response := models.APIResponse{
		Success: false,
		Message: message,
	}

	if err != nil {
		response.Error = err.Error()
	}

	c.JSON(http.StatusInternalServerError, response)
}
