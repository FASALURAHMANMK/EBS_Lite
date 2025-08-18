package handlers

import (
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

// GET /loyalty/settings
func (h *LoyaltyHandler) GetLoyaltySettings(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	// For now, return default settings
	// In a real implementation, you'd have company-specific settings
	settings := models.LoyaltySettingsResponse{
		PointsPerCurrency:   1.0,  // 1 point per $1
		PointValue:          0.01, // 1 point = $0.01
		MinRedemptionPoints: 100,  // Minimum 100 points to redeem
		PointsExpiryDays:    365,  // Points expire after 1 year
	}

	utils.SuccessResponse(c, "Loyalty settings retrieved successfully", settings)
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

	err := h.loyaltyService.AwardPoints(req.CustomerID, req.SaleAmount, req.SaleID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to award points", err)
		return
	}

	utils.SuccessResponse(c, "Points awarded successfully", nil)
}
