package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type InventoryHandler struct {
    inventoryService *services.InventoryService
}

func NewInventoryHandler() *InventoryHandler {
	return &InventoryHandler{
		inventoryService: services.NewInventoryService(),
	}
}

// GET /inventory/stock
func (h *InventoryHandler) GetStock(c *gin.Context) {
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

	// Optional product filter
	var productID *int
	if productParam := c.Query("product_id"); productParam != "" {
		if id, err := strconv.Atoi(productParam); err == nil {
			productID = &id
		}
	}

	stock, err := h.inventoryService.GetStock(companyID, locationID, productID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get stock", err)
		return
	}

	utils.SuccessResponse(c, "Stock retrieved successfully", stock)
}

// POST /inventory/stock-adjustment
func (h *InventoryHandler) AdjustStock(c *gin.Context) {
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

	var req models.CreateStockAdjustmentRequest
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

	err := h.inventoryService.AdjustStock(companyID, locationID, userID, &req)
	if err != nil {
		if err.Error() == "product not found" {
			utils.NotFoundResponse(c, "Product not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to adjust stock", err)
		return
	}

	utils.SuccessResponse(c, "Stock adjusted successfully", nil)
}

// GET /inventory/stock-adjustments
func (h *InventoryHandler) GetStockAdjustments(c *gin.Context) {
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

	adjustments, err := h.inventoryService.GetStockAdjustments(companyID, locationID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get stock adjustments", err)
		return
	}

	utils.SuccessResponse(c, "Stock adjustments retrieved successfully", adjustments)
}

// POST /inventory/stock-adjustment-documents
func (h *InventoryHandler) CreateStockAdjustmentDocument(c *gin.Context) {
    companyID := c.GetInt("company_id")
    locationID := c.GetInt("location_id")
    userID := c.GetInt("user_id")

    if companyID == 0 {
        utils.ForbiddenResponse(c, "Company access required")
        return
    }
    if locParam := c.Query("location_id"); locParam != "" {
        if id, err := strconv.Atoi(locParam); err == nil {
            locationID = id
        }
    }
    if locationID == 0 {
        utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
        return
    }

    var req models.CreateStockAdjustmentDocumentRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
        return
    }
    if err := utils.ValidateStruct(&req); err != nil {
        ve := utils.GetValidationErrors(err)
        utils.ValidationErrorResponse(c, ve)
        return
    }

    doc, err := h.inventoryService.CreateStockAdjustmentDocument(companyID, locationID, userID, &req)
    if err != nil {
        utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create adjustment document", err)
        return
    }
    utils.SuccessResponse(c, "Stock adjustment document created", doc)
}

// GET /inventory/stock-adjustment-documents
func (h *InventoryHandler) GetStockAdjustmentDocuments(c *gin.Context) {
    companyID := c.GetInt("company_id")
    locationID := c.GetInt("location_id")
    if companyID == 0 {
        utils.ForbiddenResponse(c, "Company access required")
        return
    }
    if locParam := c.Query("location_id"); locParam != "" {
        if id, err := strconv.Atoi(locParam); err == nil {
            locationID = id
        }
    }
    if locationID == 0 {
        utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
        return
    }
    docs, err := h.inventoryService.GetStockAdjustmentDocuments(companyID, locationID)
    if err != nil {
        utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get documents", err)
        return
    }
    utils.SuccessResponse(c, "Stock adjustment documents retrieved", docs)
}

// GET /inventory/stock-adjustment-documents/:id
func (h *InventoryHandler) GetStockAdjustmentDocument(c *gin.Context) {
    companyID := c.GetInt("company_id")
    locationID := c.GetInt("location_id")
    if companyID == 0 {
        utils.ForbiddenResponse(c, "Company access required")
        return
    }
    if locParam := c.Query("location_id"); locParam != "" {
        if id, err := strconv.Atoi(locParam); err == nil {
            locationID = id
        }
    }
    if locationID == 0 {
        utils.ErrorResponse(c, http.StatusBadRequest, "Location ID required", nil)
        return
    }
    id, err := strconv.Atoi(c.Param("id"))
    if err != nil {
        utils.ErrorResponse(c, http.StatusBadRequest, "Invalid document ID", err)
        return
    }
    doc, err := h.inventoryService.GetStockAdjustmentDocument(id, companyID, locationID)
    if err != nil {
        if err.Error() == "document not found" {
            utils.NotFoundResponse(c, "Document not found")
            return
        }
        utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get document", err)
        return
    }
    utils.SuccessResponse(c, "Stock adjustment document retrieved", doc)
}

func (h *InventoryHandler) GetStockTransfers(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	// Parse query parameters for filtering
	sourceLocationID := 0
	destinationLocationID := 0
	status := c.Query("status")

	if sourceParam := c.Query("source_location_id"); sourceParam != "" {
		if id, err := strconv.Atoi(sourceParam); err == nil {
			sourceLocationID = id
		}
	}

	if destParam := c.Query("destination_location_id"); destParam != "" {
		if id, err := strconv.Atoi(destParam); err == nil {
			destinationLocationID = id
		}
	}

	// Use location from context or query parameter
	if locationParam := c.Query("location_id"); locationParam != "" {
		if id, err := strconv.Atoi(locationParam); err == nil {
			locationID = id
		}
	}

	if locationID == 0 && sourceLocationID == 0 && destinationLocationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "At least one location filter required", nil)
		return
	}

	filters := &models.StockTransferFilters{
		CompanyID:             companyID,
		LocationID:            locationID,
		SourceLocationID:      sourceLocationID,
		DestinationLocationID: destinationLocationID,
		Status:                status,
	}

	transfers, err := h.inventoryService.GetStockTransfersWithFilters(filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get stock transfers", err)
		return
	}

	utils.SuccessResponse(c, "Stock transfers retrieved successfully", transfers)
}

// GET /inventory/summary
func (h *InventoryHandler) GetInventorySummary(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	summary, err := h.inventoryService.GetInventorySummary(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get inventory summary", err)
		return
	}
	utils.SuccessResponse(c, "Inventory summary retrieved successfully", summary)
}

// POST /inventory/import
func (h *InventoryHandler) ImportInventory(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	file, err := c.FormFile("file")
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "File is required", err)
		return
	}
	f, err := file.Open()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to open file", err)
		return
	}
	defer f.Close()
	if err := h.inventoryService.ImportInventory(companyID, f); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to import inventory", err)
		return
	}
	utils.SuccessResponse(c, "Inventory imported successfully", nil)
}

// GET /inventory/export
func (h *InventoryHandler) ExportInventory(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	data, err := h.inventoryService.ExportInventory(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to export inventory", err)
		return
	}
	c.Header("Content-Disposition", "attachment; filename=inventory.xlsx")
	c.Data(http.StatusOK, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", data)
}

// POST /inventory/barcode
func (h *InventoryHandler) GenerateBarcode(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.BarcodeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	data, err := h.inventoryService.GenerateBarcode(companyID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to generate barcode", err)
		return
	}
	c.Data(http.StatusOK, "application/pdf", data)
}

func (h *InventoryHandler) GetStockTransfer(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	transferID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid transfer ID", err)
		return
	}

	transfer, err := h.inventoryService.GetStockTransfer(transferID, companyID)
	if err != nil {
		if err.Error() == "transfer not found" {
			utils.NotFoundResponse(c, "Transfer not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get transfer", err)
		return
	}

	utils.SuccessResponse(c, "Transfer retrieved successfully", transfer)
}

// DELETE /inventory/transfers/:id - Cancel pending transfer
func (h *InventoryHandler) CancelStockTransfer(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	transferID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid transfer ID", err)
		return
	}

	err = h.inventoryService.CancelStockTransfer(transferID, companyID, userID)
	if err != nil {
		if err.Error() == "transfer not found" {
			utils.NotFoundResponse(c, "Transfer not found")
			return
		}
		if err.Error() == "only pending transfers can be cancelled" {
			utils.ErrorResponse(c, http.StatusBadRequest, "Only pending transfers can be cancelled", err)
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to cancel transfer", err)
		return
	}

	utils.SuccessResponse(c, "Transfer cancelled successfully", nil)
}

// POST /inventory/transfers
func (h *InventoryHandler) CreateStockTransfer(c *gin.Context) {
	companyID := c.GetInt("company_id")
	locationID := c.GetInt("location_id")
	userID := c.GetInt("user_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	// Use location from context as source location
	if locationParam := c.Query("location_id"); locationParam != "" {
		if id, err := strconv.Atoi(locationParam); err == nil {
			locationID = id
		}
	}

	if locationID == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Source location ID required", nil)
		return
	}

	var req models.CreateStockTransferRequest
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

	transfer, err := h.inventoryService.CreateStockTransfer(companyID, locationID, userID, &req)
	if err != nil {
		if err.Error() == "invalid locations" {
			utils.ErrorResponse(c, http.StatusBadRequest, "Invalid source or destination location", err)
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create stock transfer", err)
		return
	}

	utils.CreatedResponse(c, "Stock transfer created successfully", transfer)
}

// PUT /inventory/transfers/:id/approve
func (h *InventoryHandler) ApproveStockTransfer(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	transferID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid transfer ID", err)
		return
	}

	err = h.inventoryService.ApproveStockTransfer(transferID, companyID, userID)
	if err != nil {
		if err.Error() == "transfer not found" {
			utils.NotFoundResponse(c, "Transfer not found")
			return
		}
		if err.Error() == "only pending transfers can be approved" {
			utils.ErrorResponse(c, http.StatusBadRequest, "Only pending transfers can be approved", err)
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to approve transfer", err)
		return
	}

	utils.SuccessResponse(c, "Stock transfer approved successfully", nil)
}

// PUT /inventory/transfers/:id/complete
func (h *InventoryHandler) CompleteStockTransfer(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")

	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	transferID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid transfer ID", err)
		return
	}

	err = h.inventoryService.CompleteStockTransfer(transferID, companyID, userID)
	if err != nil {
		if err.Error() == "transfer not found" {
			utils.NotFoundResponse(c, "Transfer not found")
			return
		}
		if err.Error() == "transfer is not in transit" {
			utils.ErrorResponse(c, http.StatusBadRequest, "Transfer is not in transit", err)
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to complete transfer", err)
		return
	}

	utils.SuccessResponse(c, "Stock transfer completed successfully", nil)
}
