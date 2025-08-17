package handlers

import (
	"net/http"
	"strconv"

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

// GET /vouchers
func (h *VoucherHandler) ListVouchers(c *gin.Context) {
	companyID := c.GetInt("company_id")

	filters := map[string]string{}
	if v := c.Query("type"); v != "" {
		filters["type"] = v
	}
	if v := c.Query("date_from"); v != "" {
		filters["date_from"] = v
	}
	if v := c.Query("date_to"); v != "" {
		filters["date_to"] = v
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	perPage, _ := strconv.Atoi(c.DefaultQuery("per_page", "20"))

	vouchers, total, err := h.service.ListVouchers(companyID, filters, page, perPage)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get vouchers", err)
		return
	}

	totalPages := 0
	if perPage > 0 {
		totalPages = (total + perPage - 1) / perPage
	}

	meta := &models.Meta{Page: page, PerPage: perPage, Total: total, TotalPages: totalPages}
	utils.PaginatedResponse(c, "Vouchers retrieved", vouchers, meta)
}

// GET /vouchers/:id
func (h *VoucherHandler) GetVoucher(c *gin.Context) {
	companyID := c.GetInt("company_id")
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid voucher ID", err)
		return
	}

	voucher, err := h.service.GetVoucher(companyID, id)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "Voucher not found", err)
		return
	}
	utils.SuccessResponse(c, "Voucher retrieved", voucher)
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
