package handlers

import (
	"io"
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type LoyaltyHandler struct {
	loyaltyService *services.LoyaltyService
}

func NewLoyaltyHandler() *LoyaltyHandler {
	return &LoyaltyHandler{
		loyaltyService: services.NewLoyaltyService(),
	}
}

// GET /loyalty-programs
func (h *LoyaltyHandler) GetLoyaltyPrograms(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	programs, err := h.loyaltyService.GetLoyaltyPrograms(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get loyalty programs", err)
		return
	}

	utils.SuccessResponse(c, "Loyalty programs retrieved successfully", programs)
}

// GET /loyalty-programs/:customer_id
func (h *LoyaltyHandler) GetCustomerLoyalty(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	customerID, err := strconv.Atoi(c.Param("customer_id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid customer ID", err)
		return
	}

	loyalty, err := h.loyaltyService.GetCustomerLoyalty(customerID, companyID)
	if err != nil {
		if err.Error() == "customer not found" {
			utils.NotFoundResponse(c, "Customer not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get customer loyalty", err)
		return
	}

	utils.SuccessResponse(c, "Customer loyalty retrieved successfully", loyalty)
}

// POST /loyalty-redemptions
func (h *LoyaltyHandler) RedeemPoints(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req models.CreateLoyaltyRedemptionRequest
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

	redemption, err := h.loyaltyService.RedeemPoints(companyID, &req)
	if err != nil {
		if err.Error() == "customer not found" {
			utils.NotFoundResponse(c, "Customer not found")
			return
		}
		if err.Error() == "customer has no loyalty program" {
			utils.ErrorResponse(c, http.StatusBadRequest, "Customer has no loyalty program", err)
			return
		}
		if err.Error() == "insufficient points available" {
			utils.ErrorResponse(c, http.StatusBadRequest, "Insufficient points available", err)
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to redeem points", err)
		return
	}

	utils.CreatedResponse(c, "Points redeemed successfully", redemption)
}

// GET /loyalty-redemptions
func (h *LoyaltyHandler) GetLoyaltyRedemptions(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var customerID *int
	if customerParam := c.Query("customer_id"); customerParam != "" {
		if id, err := strconv.Atoi(customerParam); err == nil {
			customerID = &id
		}
	}

	redemptions, err := h.loyaltyService.GetLoyaltyRedemptions(companyID, customerID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get loyalty redemptions", err)
		return
	}

	utils.SuccessResponse(c, "Loyalty redemptions retrieved successfully", redemptions)
}

// GET /promotions
func (h *LoyaltyHandler) GetPromotions(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	// Check if only active promotions are requested
	activeOnly := c.Query("active") == "true"

	promotions, err := h.loyaltyService.GetPromotions(companyID, activeOnly)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get promotions", err)
		return
	}

	utils.SuccessResponse(c, "Promotions retrieved successfully", promotions)
}

// POST /promotions
func (h *LoyaltyHandler) CreatePromotion(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req models.CreatePromotionRequest
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

	promotion, err := h.loyaltyService.CreatePromotion(companyID, &req)
	if err != nil {
		if err.Error() == "end date cannot be before start date" {
			utils.ErrorResponse(c, http.StatusBadRequest, "End date cannot be before start date", err)
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create promotion", err)
		return
	}

	utils.CreatedResponse(c, "Promotion created successfully", promotion)
}

// PUT /promotions/:id
func (h *LoyaltyHandler) UpdatePromotion(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	promotionID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid promotion ID", err)
		return
	}

	var req models.UpdatePromotionRequest
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

	err = h.loyaltyService.UpdatePromotion(promotionID, companyID, &req)
	if err != nil {
		if err.Error() == "promotion not found" {
			utils.NotFoundResponse(c, "Promotion not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update promotion", err)
		return
	}

	utils.SuccessResponse(c, "Promotion updated successfully", nil)
}

// DELETE /promotions/:id
func (h *LoyaltyHandler) DeletePromotion(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	promotionID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid promotion ID", err)
		return
	}

	err = h.loyaltyService.DeletePromotion(promotionID, companyID)
	if err != nil {
		if err.Error() == "promotion not found" {
			utils.NotFoundResponse(c, "Promotion not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete promotion", err)
		return
	}

	utils.SuccessResponse(c, "Promotion deleted successfully", nil)
}

func (h *LoyaltyHandler) ImportPromotions(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
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
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to open file", err)
		return
	}
	defer f.Close()

	data, err := io.ReadAll(f)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to read file", err)
		return
	}

	result, err := h.loyaltyService.ImportPromotionProductRules(companyID, userID, data)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to import promotions", err)
		return
	}
	utils.SuccessResponse(c, "Promotions import completed", result)
}

func (h *LoyaltyHandler) PromotionImportTemplate(c *gin.Context) {
	if c.GetInt("company_id") == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	data, err := h.loyaltyService.PromotionImportTemplateXLSX()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to generate template", err)
		return
	}
	c.Header("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
	c.Header("Content-Disposition", "attachment; filename=promotions_template.xlsx")
	c.Data(http.StatusOK, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", data)
}

func (h *LoyaltyHandler) PromotionImportExample(c *gin.Context) {
	if c.GetInt("company_id") == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	data, err := h.loyaltyService.PromotionImportExampleXLSX()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to generate example", err)
		return
	}
	c.Header("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
	c.Header("Content-Disposition", "attachment; filename=promotions_example.xlsx")
	c.Data(http.StatusOK, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", data)
}

// POST /promotions/check-eligibility
func (h *LoyaltyHandler) CheckPromotionEligibility(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req models.PromotionEligibilityRequest
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

	eligibility, err := h.loyaltyService.CheckPromotionEligibility(companyID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to check promotion eligibility", err)
		return
	}

	utils.SuccessResponse(c, "Promotion eligibility checked successfully", eligibility)
}

func (h *LoyaltyHandler) GetCouponSeries(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	activeOnly := c.Query("active") == "true"
	items, err := h.loyaltyService.GetCouponSeries(companyID, activeOnly)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get coupon series", err)
		return
	}
	utils.SuccessResponse(c, "Coupon series retrieved successfully", items)
}

func (h *LoyaltyHandler) CreateCouponSeries(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.CreateCouponSeriesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.loyaltyService.CreateCouponSeries(companyID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create coupon series", err)
		return
	}
	utils.CreatedResponse(c, "Coupon series created successfully", item)
}

func (h *LoyaltyHandler) UpdateCouponSeries(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid coupon series ID", err)
		return
	}
	var req models.UpdateCouponSeriesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	if err := h.loyaltyService.UpdateCouponSeries(companyID, id, &req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update coupon series", err)
		return
	}
	utils.SuccessResponse(c, "Coupon series updated successfully", nil)
}

func (h *LoyaltyHandler) DeleteCouponSeries(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid coupon series ID", err)
		return
	}
	if err := h.loyaltyService.DeleteCouponSeries(companyID, id); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete coupon series", err)
		return
	}
	utils.SuccessResponse(c, "Coupon series deleted successfully", nil)
}

func (h *LoyaltyHandler) GetCouponCodes(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid coupon series ID", err)
		return
	}
	items, err := h.loyaltyService.GetCouponCodes(companyID, id)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get coupon codes", err)
		return
	}
	utils.SuccessResponse(c, "Coupon codes retrieved successfully", items)
}

func (h *LoyaltyHandler) ValidateCouponCode(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.ValidateCouponCodeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.loyaltyService.ValidateCouponCode(companyID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to validate coupon", err)
		return
	}
	utils.SuccessResponse(c, "Coupon validated successfully", item)
}

func (h *LoyaltyHandler) GetRaffleDefinitions(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	activeOnly := c.Query("active") == "true"
	items, err := h.loyaltyService.GetRaffleDefinitions(companyID, activeOnly)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get raffle definitions", err)
		return
	}
	utils.SuccessResponse(c, "Raffle definitions retrieved successfully", items)
}

func (h *LoyaltyHandler) CreateRaffleDefinition(c *gin.Context) {
	companyID := c.GetInt("company_id")
	userID := c.GetInt("user_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.CreateRaffleDefinitionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	item, err := h.loyaltyService.CreateRaffleDefinition(companyID, userID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create raffle definition", err)
		return
	}
	utils.CreatedResponse(c, "Raffle definition created successfully", item)
}

func (h *LoyaltyHandler) UpdateRaffleDefinition(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid raffle definition ID", err)
		return
	}
	var req models.UpdateRaffleDefinitionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	if err := h.loyaltyService.UpdateRaffleDefinition(companyID, id, &req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update raffle definition", err)
		return
	}
	utils.SuccessResponse(c, "Raffle definition updated successfully", nil)
}

func (h *LoyaltyHandler) DeleteRaffleDefinition(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid raffle definition ID", err)
		return
	}
	if err := h.loyaltyService.DeleteRaffleDefinition(companyID, id); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete raffle definition", err)
		return
	}
	utils.SuccessResponse(c, "Raffle definition deleted successfully", nil)
}

func (h *LoyaltyHandler) GetRaffleCoupons(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid raffle definition ID", err)
		return
	}
	items, err := h.loyaltyService.GetRaffleCoupons(companyID, &id, nil)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get raffle coupons", err)
		return
	}
	utils.SuccessResponse(c, "Raffle coupons retrieved successfully", items)
}

func (h *LoyaltyHandler) MarkRaffleWinner(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid raffle coupon ID", err)
		return
	}
	var req models.MarkRaffleWinnerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	if err := h.loyaltyService.MarkRaffleWinner(companyID, id, &req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to mark raffle winner", err)
		return
	}
	utils.SuccessResponse(c, "Raffle winner saved successfully", nil)
}

// GET /loyalty/settings
func (h *LoyaltyHandler) GetLoyaltySettings(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	settings, err := h.loyaltyService.GetLoyaltySettings(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get loyalty settings", err)
		return
	}
	utils.SuccessResponse(c, "Loyalty settings retrieved successfully", settings)
}

// PUT /loyalty/settings
func (h *LoyaltyHandler) UpdateLoyaltySettings(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.UpdateLoyaltySettingsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	if err := h.loyaltyService.UpdateLoyaltySettings(companyID, &req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update loyalty settings", err)
		return
	}
	utils.SuccessResponse(c, "Loyalty settings updated", nil)
}

// Tiers
// GET /loyalty/tiers
func (h *LoyaltyHandler) GetTiers(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	tiers, err := h.loyaltyService.GetTiers(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get tiers", err)
		return
	}
	utils.SuccessResponse(c, "Loyalty tiers retrieved successfully", tiers)
}

// POST /loyalty/tiers
func (h *LoyaltyHandler) CreateTier(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	var req models.CreateLoyaltyTierRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	tier, err := h.loyaltyService.CreateTier(companyID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create tier", err)
		return
	}
	utils.CreatedResponse(c, "Loyalty tier created", tier)
}

// PUT /loyalty/tiers/:id
func (h *LoyaltyHandler) UpdateTier(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid tier ID", err)
		return
	}
	var req models.UpdateLoyaltyTierRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body", err)
		return
	}
	if err := utils.ValidateStruct(&req); err != nil {
		utils.ValidationErrorResponse(c, utils.GetValidationErrors(err))
		return
	}
	if err := h.loyaltyService.UpdateTier(companyID, id, &req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update tier", err)
		return
	}
	utils.SuccessResponse(c, "Loyalty tier updated", nil)
}

// DELETE /loyalty/tiers/:id
func (h *LoyaltyHandler) DeleteTier(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid tier ID", err)
		return
	}
	if err := h.loyaltyService.DeleteTier(companyID, id); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete tier", err)
		return
	}
	utils.SuccessResponse(c, "Loyalty tier deleted", nil)
}

// POST /loyalty/award-points (Internal endpoint for sales integration)
func (h *LoyaltyHandler) AwardPoints(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req struct {
		CustomerID int     `json:"customer_id" validate:"required"`
		SaleAmount float64 `json:"sale_amount" validate:"required,gt=0"`
		SaleID     int     `json:"sale_id" validate:"required"`
	}

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

	err := h.loyaltyService.AwardPoints(companyID, req.CustomerID, req.SaleAmount, req.SaleID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to award points", err)
		return
	}

	utils.SuccessResponse(c, "Points awarded successfully", nil)
}
