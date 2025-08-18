package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"
)

type GoodsReceiptHandler struct {
	purchaseService *services.PurchaseService
}

func NewGoodsReceiptHandler() *GoodsReceiptHandler {
	return &GoodsReceiptHandler{
		purchaseService: services.NewPurchaseService(),
	}
}

func (h *GoodsReceiptHandler) RecordGoodsReceipt(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")

	var req models.RecordGoodsReceiptRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	if err := h.purchaseService.RecordGoodsReceipt(req.PurchaseID, companyID, userID, &req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to record goods receipt", err)
		return
	}

	utils.SuccessResponse(c, "Goods receipt recorded successfully", nil)
}
