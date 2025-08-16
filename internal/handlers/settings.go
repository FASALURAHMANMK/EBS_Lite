package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

// SettingsHandler handles HTTP requests for system settings
type SettingsHandler struct {
	service *services.SettingsService
}

func NewSettingsHandler() *SettingsHandler {
	return &SettingsHandler{service: services.NewSettingsService()}
}

// GET /settings
func (h *SettingsHandler) GetSettings(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	settings, err := h.service.GetSettings(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get settings", err)
		return
	}
	utils.SuccessResponse(c, "Settings retrieved successfully", settings)
}

// PUT /settings
func (h *SettingsHandler) UpdateSettings(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req models.UpdateSettingsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}

	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}

	if err := h.service.UpdateSettings(companyID, req.Settings); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update settings", err)
		return
	}

	utils.SuccessResponse(c, "Settings updated successfully", nil)
}

// Company settings
func (h *SettingsHandler) GetCompanySettings(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	settings, err := h.service.GetCompanySettings(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get company settings", err)
		return
	}
	utils.SuccessResponse(c, "Company settings retrieved successfully", settings)
}

func (h *SettingsHandler) UpdateCompanySettings(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.CompanySettings
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := h.service.UpdateCompanySettings(companyID, req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update company settings", err)
		return
	}
	utils.SuccessResponse(c, "Company settings updated successfully", nil)
}

// Invoice settings
func (h *SettingsHandler) GetInvoiceSettings(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	settings, err := h.service.GetInvoiceSettings(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get invoice settings", err)
		return
	}
	utils.SuccessResponse(c, "Invoice settings retrieved successfully", settings)
}

func (h *SettingsHandler) UpdateInvoiceSettings(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.InvoiceSettings
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := h.service.UpdateInvoiceSettings(companyID, req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update invoice settings", err)
		return
	}
	utils.SuccessResponse(c, "Invoice settings updated successfully", nil)
}

// Tax settings
func (h *SettingsHandler) GetTaxSettings(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	settings, err := h.service.GetTaxSettings(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get tax settings", err)
		return
	}
	utils.SuccessResponse(c, "Tax settings retrieved successfully", settings)
}

func (h *SettingsHandler) UpdateTaxSettings(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.TaxSettings
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := h.service.UpdateTaxSettings(companyID, req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update tax settings", err)
		return
	}
	utils.SuccessResponse(c, "Tax settings updated successfully", nil)
}

// Device control settings
func (h *SettingsHandler) GetDeviceControlSettings(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	settings, err := h.service.GetDeviceControlSettings(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get device control settings", err)
		return
	}
	utils.SuccessResponse(c, "Device control settings retrieved successfully", settings)
}

func (h *SettingsHandler) UpdateDeviceControlSettings(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.DeviceControlSettings
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := h.service.UpdateDeviceControlSettings(companyID, req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update device control settings", err)
		return
	}
	utils.SuccessResponse(c, "Device control settings updated successfully", nil)
}

// Session limit settings
func (h *SettingsHandler) GetSessionLimit(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	max, err := h.service.GetMaxSessions(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get session limit", err)
		return
	}
	utils.SuccessResponse(c, "Session limit retrieved successfully", gin.H{"max_sessions": max})
}

func (h *SettingsHandler) SetSessionLimit(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.SessionLimitRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	if err := h.service.SetMaxSessions(companyID, req.MaxSessions); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update session limit", err)
		return
	}
	utils.SuccessResponse(c, "Session limit updated successfully", nil)
}

func (h *SettingsHandler) DeleteSessionLimit(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	if err := h.service.DeleteMaxSessions(companyID); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete session limit", err)
		return
	}
	utils.SuccessResponse(c, "Session limit deleted successfully", nil)
}

// Payment methods CRUD
func (h *SettingsHandler) GetPaymentMethods(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	methods, err := h.service.GetPaymentMethods(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get payment methods", err)
		return
	}
	utils.SuccessResponse(c, "Payment methods retrieved successfully", methods)
}

func (h *SettingsHandler) CreatePaymentMethod(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.PaymentMethodRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	pm, err := h.service.CreatePaymentMethod(companyID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create payment method", err)
		return
	}
	utils.CreatedResponse(c, "Payment method created successfully", pm)
}

func (h *SettingsHandler) UpdatePaymentMethod(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid payment method ID", err)
		return
	}
	var req models.PaymentMethodRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	if err := h.service.UpdatePaymentMethod(companyID, id, &req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update payment method", err)
		return
	}
	utils.SuccessResponse(c, "Payment method updated successfully", nil)
}

func (h *SettingsHandler) DeletePaymentMethod(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid payment method ID", err)
		return
	}
	if err := h.service.DeletePaymentMethod(companyID, id); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete payment method", err)
		return
	}
	utils.SuccessResponse(c, "Payment method deleted successfully", nil)
}

// Printer profiles CRUD
func (h *SettingsHandler) GetPrinters(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	printers, err := h.service.GetPrinters(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get printers", err)
		return
	}
	utils.SuccessResponse(c, "Printers retrieved successfully", printers)
}

func (h *SettingsHandler) CreatePrinter(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.PrinterProfile
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	printer, err := h.service.CreatePrinter(companyID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create printer", err)
		return
	}
	utils.CreatedResponse(c, "Printer created successfully", printer)
}

func (h *SettingsHandler) UpdatePrinter(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid printer ID", err)
		return
	}
	var req models.PrinterProfile
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	if err := h.service.UpdatePrinter(companyID, id, &req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update printer", err)
		return
	}
	utils.SuccessResponse(c, "Printer updated successfully", nil)
}

func (h *SettingsHandler) DeletePrinter(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid printer ID", err)
		return
	}
	if err := h.service.DeletePrinter(companyID, id); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete printer", err)
		return
	}
	utils.SuccessResponse(c, "Printer deleted successfully", nil)
}
