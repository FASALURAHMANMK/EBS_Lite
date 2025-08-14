package handlers

import (
	"net/http"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type VoucherHandler struct {
	service *services.VoucherService
}

func NewVoucherHandler() *VoucherHandler {
	return &VoucherHandler{service: services.NewVoucherService()}
}

// POST /vouchers/:type (payment, receipt, journal)
func (h *VoucherHandler) CreateVoucher(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	vType := c.Param("type")

	var req models.CreateVoucherRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		validationErrors := utils.GetValidationErrors(err)
		utils.ValidationErrorResponse(c, validationErrors)
		return
	}

	id, err := h.service.CreateVoucher(companyID, userID, vType, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to create voucher", err)
		return
	}
	utils.CreatedResponse(c, "Voucher created", gin.H{"voucher_id": id})
}
