package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"
)

type GoodsReceiptHandler struct {
	purchaseService               *services.PurchaseService
	purchaseCostAdjustmentService *services.PurchaseCostAdjustmentService
}

func NewGoodsReceiptHandler() *GoodsReceiptHandler {
	return &GoodsReceiptHandler{
		purchaseService:               services.NewPurchaseService(),
		purchaseCostAdjustmentService: services.NewPurchaseCostAdjustmentService(),
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

	receipt, err := h.purchaseService.RecordGoodsReceiptDetailed(req.PurchaseID, companyID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to record goods receipt", err)
		return
	}

	utils.SuccessResponse(c, "Goods receipt recorded successfully", receipt)
}

// GET /goods-receipts
func (h *GoodsReceiptHandler) GetGoodsReceipts(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	// Allow overriding location via query
	if loc := c.Query("location_id"); loc != "" {
		if id, err := strconv.Atoi(loc); err == nil {
			locationID = id
		}
	}
	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}
	filters := map[string]string{}
	if s := c.Query("search"); s != "" {
		filters["search"] = s
	}
	list, err := h.purchaseService.GetGoodsReceipts(companyID, locationID, filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get goods receipts", err)
		return
	}
	utils.SuccessResponse(c, "Goods receipts retrieved successfully", list)
}

// GET /goods-receipts/:id
func (h *GoodsReceiptHandler) GetGoodsReceipt(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid GRN ID", err)
		return
	}
	gr, err := h.purchaseService.GetGoodsReceiptByID(companyID, id)
	if err != nil {
		if err.Error() == "goods receipt not found" {
			utils.NotFoundResponse(c, "Goods receipt not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get goods receipt", err)
		return
	}
	utils.SuccessResponse(c, "Goods receipt retrieved successfully", gr)
}

func (h *GoodsReceiptHandler) CreateGoodsReceiptAddons(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid GRN ID", err)
		return
	}
	var req models.CreateGoodsReceiptAddonRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	result, err := h.purchaseCostAdjustmentService.CreateGoodsReceiptAddons(companyID, id, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to add GRN add-ons", err)
		return
	}
	utils.CreatedResponse(c, "Goods receipt add-ons recorded successfully", result)
}

func (h *GoodsReceiptHandler) GetGoodsReceiptAddons(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid GRN ID", err)
		return
	}
	items, err := h.purchaseCostAdjustmentService.GetGoodsReceiptAddons(companyID, id)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get GRN add-ons", err)
		return
	}
	utils.SuccessResponse(c, "Goods receipt add-ons retrieved successfully", items)
}
