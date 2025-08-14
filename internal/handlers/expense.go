package handlers

import (
	"net/http"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type ExpenseHandler struct {
	service *services.ExpenseService
}

func NewExpenseHandler() *ExpenseHandler {
	return &ExpenseHandler{service: services.NewExpenseService()}
}

// POST /expenses
func (h *ExpenseHandler) CreateExpense(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")

	var req models.CreateExpenseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	id, err := h.service.CreateExpense(companyID, locationID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to create expense", err)
		return
	}
	utils.CreatedResponse(c, "Expense recorded successfully", gin.H{"expense_id": id})
}

// GET /expenses/categories
func (h *ExpenseHandler) GetCategories(c *gin.Context) {
	companyID := c.GetInt("company_id")

	categories, err := h.service.GetCategories(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get categories", err)
		return
	}
	utils.SuccessResponse(c, "Expense categories retrieved", categories)
}

// POST /expenses/categories
func (h *ExpenseHandler) CreateCategory(c *gin.Context) {
	companyID := c.GetInt("company_id")

	var req models.CreateExpenseCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	id, err := h.service.CreateCategory(companyID, req.Name)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to create category", err)
		return
	}
	utils.CreatedResponse(c, "Category created", gin.H{"category_id": id})
}
