package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type CollectionHandler struct {
	collectionService *services.CollectionService
}

func NewCollectionHandler() *CollectionHandler {
	return &CollectionHandler{collectionService: services.NewCollectionService()}
}

// GET /collections
func (h *CollectionHandler) GetCollections(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	// Parse filters
	filters := map[string]string{}
	if v := c.Query("customer_id"); v != "" {
		filters["customer_id"] = v
	}
	if v := c.Query("date_from"); v != "" {
		filters["date_from"] = v
	}
	if v := c.Query("date_to"); v != "" {
		filters["date_to"] = v
	}

	collections, err := h.collectionService.GetCollections(companyID, filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get collections", err)
		return
	}

	utils.SuccessResponse(c, "Collections retrieved successfully", collections)
}

// POST /collections
func (h *CollectionHandler) CreateCollection(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	if locationID == 0 {
		if v := c.Query("location_id"); v != "" {
			if id, err := strconv.Atoi(v); err == nil {
				locationID = id
			}
		}
	}
	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
		return
	}

	var req models.CreateCollectionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	col, err := h.collectionService.CreateCollection(companyID, locationID, userID, &req)
	if err != nil {
		if err.Error() == "customer not found" || err.Error() == "customer does not belong to company" {
			utils.NotFoundResponse(c, err.Error())
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create collection", err)
		return
	}

	utils.CreatedResponse(c, "Collection recorded successfully", col)
}

// DELETE /collections/:id
func (h *CollectionHandler) DeleteCollection(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	collectionID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid collection ID", err)
		return
	}

	if err := h.collectionService.DeleteCollection(collectionID, companyID); err != nil {
		if err.Error() == "collection not found" {
			utils.NotFoundResponse(c, "Collection not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to delete collection", err)
		return
	}

	utils.SuccessResponse(c, "Collection deleted successfully", nil)
}

// GET /collections/:id/receipt
func (h *CollectionHandler) GetCollectionReceipt(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	collectionID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid collection ID", err)
		return
	}

	col, err := h.collectionService.GetCollectionByID(collectionID, companyID)
	if err != nil {
		if err.Error() == "collection not found" {
			utils.NotFoundResponse(c, "Collection not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get collection", err)
		return
	}

	receipt := map[string]interface{}{
		"collection_id":     col.CollectionID,
		"collection_number": col.CollectionNumber,
		"collection_date":   col.CollectionDate,
		"customer_id":       col.CustomerID,
		"amount":            col.Amount,
		"payment_method":    col.PaymentMethod,
		"reference_number":  col.ReferenceNumber,
		"notes":             col.Notes,
		"invoices":          col.Invoices,
	}

	utils.SuccessResponse(c, "Collection receipt data retrieved successfully", receipt)
}
