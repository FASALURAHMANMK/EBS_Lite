package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"
)

type PurchaseOrderHandler struct {
	purchaseService *services.PurchaseService
}

func NewPurchaseOrderHandler() *PurchaseOrderHandler {
	return &PurchaseOrderHandler{
		purchaseService: services.NewPurchaseService(),
	}
}

func (h *PurchaseOrderHandler) CreatePurchaseOrder(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")

	var req models.CreatePurchaseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	purchase, err := h.purchaseService.CreatePurchase(companyID, locationID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create purchase order", err)
		return
	}
	utils.SuccessResponse(c, "Purchase order created successfully", purchase)
}

func (h *PurchaseOrderHandler) UpdatePurchaseOrder(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	purchaseID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid purchase ID", err)
		return
	}

	var req models.UpdatePurchaseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	if err := h.purchaseService.UpdatePurchase(purchaseID, companyID, userID, &req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update purchase order", err)
		return
	}
	utils.SuccessResponse(c, "Purchase order updated successfully", nil)
}

func (h *PurchaseOrderHandler) DeletePurchaseOrder(c *gin.Context) {
	companyID := c.GetInt("company_id")
	purchaseID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid purchase ID", err)
		return
	}

	if err := h.purchaseService.DeletePurchase(purchaseID, companyID); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete purchase order", err)
		return
	}
	utils.SuccessResponse(c, "Purchase order deleted successfully", nil)
}

func (h *PurchaseOrderHandler) ApprovePurchaseOrder(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	purchaseID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid purchase ID", err)
		return
	}

	if err := h.purchaseService.ApprovePurchaseOrder(purchaseID, companyID, userID); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to approve purchase order", err)
		return
	}
	utils.SuccessResponse(c, "Purchase order approved successfully", nil)
}
