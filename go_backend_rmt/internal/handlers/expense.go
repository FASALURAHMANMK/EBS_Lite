package handlers

import (
	"net/http"
	"strconv"

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

// GET /expenses
func (h *ExpenseHandler) GetExpenses(c *gin.Context) {
	companyID := c.GetInt("company_id")

	filters := map[string]string{}
	if v := c.Query("category_id"); v != "" {
		filters["category_id"] = v
	}
	if v := c.Query("location_id"); v != "" {
		filters["location_id"] = v
	}
	if v := c.Query("date_from"); v != "" {
		filters["date_from"] = v
	}
	if v := c.Query("date_to"); v != "" {
		filters["date_to"] = v
	}

	expenses, err := h.service.ListExpenses(companyID, filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get expenses", err)
		return
	}
	utils.SuccessResponse(c, "Expenses retrieved", expenses)
}

// GET /expenses/:id
func (h *ExpenseHandler) GetExpense(c *gin.Context) {
	companyID := c.GetInt("company_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid expense ID", err)
		return
	}

	expense, err := h.service.GetExpense(companyID, id)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "Expense not found", err)
		return
	}
	utils.SuccessResponse(c, "Expense retrieved", expense)
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
	userID := c.GetInt("user_id")

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

	id, err := h.service.CreateCategory(companyID, userID, req.Name)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to create category", err)
		return
	}
	utils.CreatedResponse(c, "Category created", gin.H{"category_id": id})
}

// PUT /expenses/categories/:id
func (h *ExpenseHandler) UpdateCategory(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid category ID", err)
		return
	}

	var req struct {
		Name string `json:"name" validate:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	if err := h.service.UpdateCategory(companyID, id, userID, req.Name); err != nil {
		if err.Error() == "category not found" {
			utils.NotFoundResponse(c, "Category not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to update category", err)
		return
	}
	utils.SuccessResponse(c, "Category updated", nil)
}

// DELETE /expenses/categories/:id
func (h *ExpenseHandler) DeleteCategory(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid category ID", err)
		return
	}

	if err := h.service.DeleteCategory(companyID, id, userID); err != nil {
		if err.Error() == "category not found" {
			utils.NotFoundResponse(c, "Category not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to delete category", err)
		return
	}
	utils.SuccessResponse(c, "Category deleted", nil)
}
