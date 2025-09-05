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
    if s := c.Query("search"); s != "" { filters["search"] = s }
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
