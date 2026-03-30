package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type BankingHandler struct {
	service *services.BankingService
}

func NewBankingHandler() *BankingHandler {
	return &BankingHandler{service: services.NewBankingService()}
}

func (h *BankingHandler) ListBankAccounts(c *gin.Context) {
	companyID := c.GetInt("company_id")
	items, err := h.service.ListBankAccounts(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to list bank accounts", err)
		return
	}
	utils.SuccessResponse(c, "Bank accounts retrieved", items)
}

func (h *BankingHandler) CreateBankAccount(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	var req models.CreateBankAccountRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.service.CreateBankAccount(companyID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create bank account", err)
		return
	}
	utils.CreatedResponse(c, "Bank account created", item)
}

func (h *BankingHandler) UpdateBankAccount(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	bankAccountID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid bank account ID", err)
		return
	}
	var req models.UpdateBankAccountRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.service.UpdateBankAccount(companyID, bankAccountID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update bank account", err)
		return
	}
	utils.SuccessResponse(c, "Bank account updated", item)
}

func (h *BankingHandler) ListStatementEntries(c *gin.Context) {
	companyID := c.GetInt("company_id")
	bankAccountID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid bank account ID", err)
		return
	}
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "200"))
	items, err := h.service.ListStatementEntries(companyID, bankAccountID, map[string]string{
		"status":    c.Query("status"),
		"date_from": c.Query("date_from"),
		"date_to":   c.Query("date_to"),
	}, limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to list statement entries", err)
		return
	}
	utils.SuccessResponse(c, "Statement entries retrieved", items)
}

func (h *BankingHandler) CreateStatementEntry(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	bankAccountID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid bank account ID", err)
		return
	}
	var req models.CreateBankStatementEntryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	if idemKey := c.GetHeader("Idempotency-Key"); idemKey != "" {
		req.IdempotencyKey = &idemKey
	} else if idemKey := c.GetHeader("X-Idempotency-Key"); idemKey != "" {
		req.IdempotencyKey = &idemKey
	}
	item, err := h.service.CreateStatementEntry(companyID, bankAccountID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create statement entry", err)
		return
	}
	utils.CreatedResponse(c, "Statement entry created", item)
}

func (h *BankingHandler) MatchStatement(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	bankAccountID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid bank account ID", err)
		return
	}
	var req models.MatchBankStatementRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.service.MatchStatement(companyID, bankAccountID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to match statement entry", err)
		return
	}
	utils.SuccessResponse(c, "Statement entry matched", item)
}

func (h *BankingHandler) UnmatchStatement(c *gin.Context) {
	companyID := c.GetInt("company_id")
	bankAccountID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid bank account ID", err)
		return
	}
	var req models.UnmatchBankStatementRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.service.UnmatchStatement(companyID, bankAccountID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to unmatch statement entry", err)
		return
	}
	utils.SuccessResponse(c, "Statement entry unmatched", item)
}

func (h *BankingHandler) ReviewStatement(c *gin.Context) {
	companyID := c.GetInt("company_id")
	bankAccountID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid bank account ID", err)
		return
	}
	var req models.ReviewBankStatementRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.service.MarkStatementReview(companyID, bankAccountID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update review status", err)
		return
	}
	utils.SuccessResponse(c, "Statement entry review status updated", item)
}

func (h *BankingHandler) CreateAdjustment(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	bankAccountID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid bank account ID", err)
		return
	}
	var req models.CreateBankAdjustmentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	if idemKey := c.GetHeader("Idempotency-Key"); idemKey != "" {
		req.IdempotencyKey = &idemKey
	} else if idemKey := c.GetHeader("X-Idempotency-Key"); idemKey != "" {
		req.IdempotencyKey = &idemKey
	}
	item, err := h.service.CreateAdjustment(companyID, bankAccountID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create bank adjustment", err)
		return
	}
	utils.SuccessResponse(c, "Bank adjustment created and matched", item)
}
