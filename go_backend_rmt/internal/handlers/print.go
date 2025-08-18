package handlers

import (
	"net/http"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

// PrintHandler triggers print operations
type PrintHandler struct {
	service *services.PrintService
}

func NewPrintHandler() *PrintHandler {
	return &PrintHandler{service: services.NewPrintService()}
}

// POST /print/receipt
func (h *PrintHandler) PrintReceipt(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req models.PrintReceiptRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	if err := h.service.PrintReceipt(req.Type, req.ReferenceID, companyID); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to print receipt", err)
		return
	}
	utils.SuccessResponse(c, "Print command sent", nil)
}
