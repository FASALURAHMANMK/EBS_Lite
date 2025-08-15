package handlers

import (
	"net/http"
	"strconv"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type ProductHandler struct {
	productService   *services.ProductService
	inventoryService *services.InventoryService
}

func NewProductHandler() *ProductHandler {
	return &ProductHandler{
		productService:   services.NewProductService(),
		inventoryService: services.NewInventoryService(),
	}
}

// GET /products
func (h *ProductHandler) GetProducts(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	// Parse query filters
	filters := make(map[string]string)
	if categoryID := c.Query("category_id"); categoryID != "" {
		filters["category_id"] = categoryID
	}
	if brandID := c.Query("brand_id"); brandID != "" {
		filters["brand_id"] = brandID
	}
	if isActive := c.Query("is_active"); isActive != "" {
		filters["is_active"] = isActive
	}

	products, err := h.productService.GetProducts(companyID, filters)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get products", err)
		return
	}

	utils.SuccessResponse(c, "Products retrieved successfully", products)
}

// GET /products/:id
func (h *ProductHandler) GetProduct(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	productID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid product ID", err)
		return
	}

	product, err := h.productService.GetProductByID(productID, companyID)
	if err != nil {
		if err.Error() == "product not found" {
			utils.NotFoundResponse(c, "Product not found")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get product", err)
		return
	}

	utils.SuccessResponse(c, "Product retrieved successfully", product)
}

// POST /products
func (h *ProductHandler) CreateProduct(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req models.CreateProductRequest
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

	product, err := h.productService.CreateProduct(companyID, &req)
	if err != nil {
		if err.Error() == "product with this SKU or barcode already exists" {
			utils.ConflictResponse(c, "Product with this SKU or barcode already exists")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create product", err)
		return
	}

	utils.CreatedResponse(c, "Product created successfully", product)
}

// PUT /products/:id
func (h *ProductHandler) UpdateProduct(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	productID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid product ID", err)
		return
	}

	var req models.UpdateProductRequest
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

	err = h.productService.UpdateProduct(productID, companyID, &req)
	if err != nil {
		if err.Error() == "product not found" {
			utils.NotFoundResponse(c, "Product not found")
			return
		}
		if err.Error() == "product with this SKU or barcode already exists" {
			utils.ConflictResponse(c, "Product with this SKU or barcode already exists")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to update product", err)
		return
	}

	utils.SuccessResponse(c, "Product updated successfully", nil)
}

// DELETE /products/:id
func (h *ProductHandler) DeleteProduct(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	productID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid product ID", err)
		return
	}

	err = h.productService.DeleteProduct(productID, companyID)
	if err != nil {
		if err.Error() == "product not found" {
			utils.NotFoundResponse(c, "Product not found")
			return
		}
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to delete product", err)
		return
	}

	utils.SuccessResponse(c, "Product deleted successfully", nil)
}

// GET /products/:id/summary
func (h *ProductHandler) GetProductSummary(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}
	productID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid product ID", err)
		return
	}
	summary, err := h.inventoryService.GetProductSummary(companyID, productID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get product summary", err)
		return
	}
	utils.SuccessResponse(c, "Product summary retrieved successfully", summary)
}

// GET /categories
func (h *ProductHandler) GetCategories(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	categories, err := h.productService.GetCategories(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get categories", err)
		return
	}

	utils.SuccessResponse(c, "Categories retrieved successfully", categories)
}

// POST /categories
func (h *ProductHandler) CreateCategory(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req models.CreateCategoryRequest
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

	category, err := h.productService.CreateCategory(companyID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create category", err)
		return
	}

	utils.CreatedResponse(c, "Category created successfully", category)
}

// GET /brands
func (h *ProductHandler) GetBrands(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	brands, err := h.productService.GetBrands(companyID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get brands", err)
		return
	}

	utils.SuccessResponse(c, "Brands retrieved successfully", brands)
}

// POST /brands
func (h *ProductHandler) CreateBrand(c *gin.Context) {
	companyID := c.GetInt("company_id")
	if companyID == 0 {
		utils.ForbiddenResponse(c, "Company access required")
		return
	}

	var req models.CreateBrandRequest
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

	brand, err := h.productService.CreateBrand(companyID, &req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create brand", err)
		return
	}

	utils.CreatedResponse(c, "Brand created successfully", brand)
}

// GET /units
func (h *ProductHandler) GetUnits(c *gin.Context) {
	units, err := h.productService.GetUnits()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Failed to get units", err)
		return
	}

	utils.SuccessResponse(c, "Units retrieved successfully", units)
}

// POST /units
func (h *ProductHandler) CreateUnit(c *gin.Context) {
	var req models.CreateUnitRequest
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

	unit, err := h.productService.CreateUnit(&req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Failed to create unit", err)
		return
	}

	utils.CreatedResponse(c, "Unit created successfully", unit)
}
