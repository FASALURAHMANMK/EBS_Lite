package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type PurchaseHandler struct {
	purchaseService       *services.PurchaseService
	purchaseReturnService *services.PurchaseReturnService
}

func NewPurchaseHandler() *PurchaseHandler {
	return &PurchaseHandler{
		purchaseService:       services.NewPurchaseService(),
		purchaseReturnService: services.NewPurchaseReturnService(),
	}
}

// GET /purchases
func (h *PurchaseHandler) GetPurchases(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	// Use location from context or query parameter
	if locationParam := c.Query("location_id"); locationParam != "" {
		if id, err := strconv.Atoi(locationParam); err == nil {
			locationID = id
		}
	}

	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	// Parse query filters
	filters := make(map[string]string)
	if supplierID := c.Query("supplier_id"); supplierID != "" {
		filters["supplier_id"] = supplierID
	}
	if dateFrom := c.Query("date_from"); dateFrom != "" {
		filters["date_from"] = dateFrom
	}
	if dateTo := c.Query("date_to"); dateTo != "" {
		filters["date_to"] = dateTo
	}
	if status := c.Query("status"); status != "" {
		filters["status"] = status
	}

	purchases, err := h.purchaseService.GetPurchases(companyID, locationID, filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get purchases", err)
		return
	}

	utils.SuccessResponse(c, "Purchases retrieved successfully", purchases)
}

// GET /purchases/:id
func (h *PurchaseHandler) GetPurchase(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	purchaseID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid purchase ID", err)
		return
	}

	purchase, err := h.purchaseService.GetPurchaseByID(purchaseID, companyID)
	if err != nil {
		if err.Error() == "purchase not found" {
			utils.NotFoundResponse(c, "Purchase not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get purchase", err)
		return
	}

	utils.SuccessResponse(c, "Purchase retrieved successfully", purchase)
}

// POST /purchases
func (h *PurchaseHandler) CreatePurchase(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	// Use location from context or request body
	if locationParam := c.Query("location_id"); locationParam != "" {
		if id, err := strconv.Atoi(locationParam); err == nil {
			locationID = id
		}
	}

	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	var req models.CreatePurchaseRequest
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

	purchase, err := h.purchaseService.CreatePurchase(companyID, locationID, userID, &req)
	if err != nil {
		if err.Error() == "supplier not found" || err.Error() == "supplier does not belong to company" {
			utils.NotFoundResponse(c, "Supplier not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create purchase", err)
		return
	}

	utils.CreatedResponse(c, "Purchase created successfully", purchase)
}

// PUT /purchases/:id
func (h *PurchaseHandler) UpdatePurchase(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

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

	// Validate request
	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	err = h.purchaseService.UpdatePurchase(purchaseID, companyID, userID, &req)
	if err != nil {
		if err.Error() == "purchase not found" {
			utils.NotFoundResponse(c, "Purchase not found")
			return
		}
		if err.Error() == "cannot update purchase with status RECEIVED" ||
			err.Error() == "cannot update purchase with status CANCELLED" {
			utils.ConflictResponse(c, err.Error())
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update purchase", err)
		return
	}

	utils.SuccessResponse(c, "Purchase updated successfully", nil)
}

// DELETE /purchases/:id
func (h *PurchaseHandler) DeletePurchase(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	purchaseID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid purchase ID", err)
		return
	}

	err = h.purchaseService.DeletePurchase(purchaseID, companyID)
	if err != nil {
		if err.Error() == "purchase not found" {
			utils.NotFoundResponse(c, "Purchase not found")
			return
		}
		if err.Error() == "cannot delete received purchase" {
			utils.ConflictResponse(c, "Cannot delete received purchase")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to delete purchase", err)
		return
	}

	utils.SuccessResponse(c, "Purchase deleted successfully", nil)
}

// GET /purchase-returns
func (h *PurchaseHandler) GetPurchaseReturns(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	// Use location from context or query parameter
	if locationParam := c.Query("location_id"); locationParam != "" {
		if id, err := strconv.Atoi(locationParam); err == nil {
			locationID = id
		}
	}

	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	// Parse query filters
	filters := make(map[string]string)
	if purchaseID := c.Query("purchase_id"); purchaseID != "" {
		filters["purchase_id"] = purchaseID
	}
	if supplierID := c.Query("supplier_id"); supplierID != "" {
		filters["supplier_id"] = supplierID
	}
	if dateFrom := c.Query("date_from"); dateFrom != "" {
		filters["date_from"] = dateFrom
	}
	if dateTo := c.Query("date_to"); dateTo != "" {
		filters["date_to"] = dateTo
	}

	returns, err := h.purchaseReturnService.GetPurchaseReturns(companyID, locationID, filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get purchase returns", err)
		return
	}

	utils.SuccessResponse(c, "Purchase returns retrieved successfully", returns)
}

// GET /purchase-returns/:id
func (h *PurchaseHandler) GetPurchaseReturn(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	returnID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid return ID", err)
		return
	}

	returnData, err := h.purchaseReturnService.GetPurchaseReturnByID(returnID, companyID)
	if err != nil {
		if err.Error() == "purchase return not found" {
			utils.NotFoundResponse(c, "Purchase return not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get purchase return", err)
		return
	}

	utils.SuccessResponse(c, "Purchase return retrieved successfully", returnData)
}

// POST /purchase-returns
func (h *PurchaseHandler) CreatePurchaseReturn(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	// Use location from context or request body
	if locationParam := c.Query("location_id"); locationParam != "" {
		if id, err := strconv.Atoi(locationParam); err == nil {
			locationID = id
		}
	}

	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	var req models.CreatePurchaseReturnRequest
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

	returnData, err := h.purchaseReturnService.CreatePurchaseReturn(companyID, locationID, userID, &req)
	if err != nil {
		if err.Error() == "purchase not found" {
			utils.NotFoundResponse(c, "Purchase not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create purchase return", err)
		return
	}

	utils.CreatedResponse(c, "Purchase return created successfully", returnData)
}

// PUT /purchases/:id/receive
func (h *PurchaseHandler) ReceivePurchase(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	purchaseID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid purchase ID", err)
		return
	}

	var req models.ReceivePurchaseRequest
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

	err = h.purchaseService.ReceivePurchase(purchaseID, companyID, userID, &req)
	if err != nil {
		if err.Error() == "purchase not found" {
			utils.NotFoundResponse(c, "Purchase not found")
			return
		}
		if err.Error() == "purchase with status RECEIVED cannot be received" ||
			err.Error() == "purchase with status CANCELLED cannot be received" {
			utils.ConflictResponse(c, err.Error())
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to receive purchase", err)
		return
	}

	utils.SuccessResponse(c, "Purchase received successfully", nil)
}

// GET /purchases/pending
func (h *PurchaseHandler) GetPendingPurchases(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	// Use location from context or query parameter
	if locationParam := c.Query("location_id"); locationParam != "" {
		if id, err := strconv.Atoi(locationParam); err == nil {
			locationID = id
		}
	}

	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	purchases, err := h.purchaseService.GetPendingPurchases(companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get pending purchases", err)
		return
	}

	utils.SuccessResponse(c, "Pending purchases retrieved successfully", purchases)
}
