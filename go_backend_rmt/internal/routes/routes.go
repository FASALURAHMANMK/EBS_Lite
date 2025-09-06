package routes

import (
	"net/http"

	"erp-backend/internal/config"
	"erp-backend/internal/handlers"
	"erp-backend/internal/middleware"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

func Initialize(router *gin.Engine, cfg *config.Config) {

	// Initialize JWT utils
	utils.InitializeJWT(cfg.JWTSecret)

	// Initialize validator
	utils.InitializeValidator()

	// Initialize handlers
	authHandler := handlers.NewAuthHandler()
	userHandler := handlers.NewUserHandler()
	deviceSessionHandler := handlers.NewDeviceSessionHandler()
	companyHandler := handlers.NewCompanyHandler(cfg)
	locationHandler := handlers.NewLocationHandler()
	roleHandler := handlers.NewRoleHandler()
	productHandler := handlers.NewProductHandler()
	inventoryHandler := handlers.NewInventoryHandler()
	productAttributeHandler := handlers.NewProductAttributeHandler()
	salesHandler := handlers.NewSalesHandler()
	posHandler := handlers.NewPOSHandler()
	loyaltyHandler := handlers.NewLoyaltyHandler()
	returnsHandler := handlers.NewReturnsHandler()
	purchaseHandler := handlers.NewPurchaseHandler()
	purchaseOrderHandler := handlers.NewPurchaseOrderHandler()
	goodsReceiptHandler := handlers.NewGoodsReceiptHandler()
    supplierHandler := handlers.NewSupplierHandler()
    paymentHandler := handlers.NewPaymentHandler()
	customerHandler := handlers.NewCustomerHandler()
	collectionHandler := handlers.NewCollectionHandler()
	cashRegisterHandler := handlers.NewCashRegisterHandler()
	expenseHandler := handlers.NewExpenseHandler()
	voucherHandler := handlers.NewVoucherHandler()
	ledgerHandler := handlers.NewLedgerHandler()
	reportsHandler := handlers.NewReportsHandler()
	employeeHandler := handlers.NewEmployeeHandler()
	payrollHandler := handlers.NewPayrollHandler()
	attendanceHandler := handlers.NewAttendanceHandler()
	workflowHandler := handlers.NewWorkflowHandler()
	settingsHandler := handlers.NewSettingsHandler()
	auditLogHandler := handlers.NewAuditLogHandler()
	dashboardHandler := handlers.NewDashboardHandler()
	languageHandler := handlers.NewLanguageHandler()
	translationHandler := handlers.NewTranslationHandler()
	printHandler := handlers.NewPrintHandler()
	numberingSequenceHandler := handlers.NewNumberingSequenceHandler()
	invoiceTemplateHandler := handlers.NewInvoiceTemplateHandler()
	currencyHandler := handlers.NewCurrencyHandler()
	taxHandler := handlers.NewTaxHandler()
	userPreferencesHandler := handlers.NewUserPreferencesHandler()
	// Health check endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"message": "Server is running",
		})
	})

	// API version 1 routes
	v1 := router.Group("/api/v1")
	{
		// Public authentication routes
		auth := v1.Group("/auth")
		{
			auth.POST("/login", authHandler.Login)
			auth.POST("/register", authHandler.Register)
			auth.POST("/forgot-password", authHandler.ForgotPassword)
			auth.POST("/reset-password", authHandler.ResetPassword)
			auth.POST("/refresh-token", authHandler.RefreshToken)
		}

		v1.GET("/languages", languageHandler.GetLanguages)

		// Protected routes (require authentication)
		protected := v1.Group("")
		protected.Use(middleware.RequireAuth())
		{
			// Auth routes that require authentication. These routes do not
			// enforce company access so any authenticated user can retrieve
			// their profile or terminate their session.
			authProtected := protected.Group("/auth")
			{
				authProtected.GET("/me", authHandler.GetMe)
				authProtected.POST("/logout", authHandler.Logout)
			}

			// Device session routes
			deviceSessions := protected.Group("/device-sessions")
			deviceSessions.Use(middleware.RequireCompanyAccess())
			{
				deviceSessions.GET("", deviceSessionHandler.GetDeviceSessions)
				deviceSessions.DELETE("/:session_id", deviceSessionHandler.RevokeSession)
			}

			// Dashboard routes
			dashboard := protected.Group("/dashboard")
			dashboard.Use(middleware.RequireCompanyAccess())
			{
				dashboard.GET("/metrics", middleware.RequirePermission("VIEW_DASHBOARD"), dashboardHandler.GetMetrics)
				dashboard.GET("/quick-actions", middleware.RequirePermission("VIEW_DASHBOARD"), dashboardHandler.GetQuickActions)
			}

			// User management routes
			users := protected.Group("/users")
			users.Use(middleware.RequireCompanyAccess()) // Ensure company isolation
			{
				users.GET("", middleware.RequirePermission("VIEW_USERS"), userHandler.GetUsers)
				users.POST("", middleware.RequirePermission("CREATE_USERS"), userHandler.CreateUser)
				users.PUT("/:id", middleware.RequirePermission("UPDATE_USERS"), userHandler.UpdateUser)
				users.DELETE("/:id", middleware.RequirePermission("DELETE_USERS"), userHandler.DeleteUser)
			}

			// Company management routes (admin only)
			// companies := protected.Group("/companies")
			// companies.Use(middleware.RequireRole("Admin")) // Only admins can manage companies
			// {
			// 	companies.GET("", companyHandler.GetCompanies)
			// 	companies.POST("", companyHandler.CreateCompany)
			// 	companies.PUT("/:id", companyHandler.UpdateCompany)
			// 	companies.DELETE("/:id", companyHandler.DeleteCompany)
			// }

            companies := protected.Group("/companies")
            {
                companies.GET("", middleware.RequirePermission("VIEW_COMPANIES"), companyHandler.GetCompanies)
                companies.POST("", companyHandler.CreateCompany) // No admin requirement for CREATE only
                companies.PUT("/:id", middleware.RequirePermission("MANAGE_SETTINGS"), companyHandler.UpdateCompany)
                companies.DELETE("/:id", middleware.RequireRole("Admin"), companyHandler.DeleteCompany)
                companies.POST("/:id/logo", middleware.RequirePermission("MANAGE_SETTINGS"), companyHandler.UploadCompanyLogo)
            }

			// Location management routes
			locations := protected.Group("/locations")
			locations.Use(middleware.RequireCompanyAccess()) // Ensure company isolation
			{
				locations.GET("", middleware.RequirePermission("VIEW_LOCATIONS"), locationHandler.GetLocations)
				locations.POST("", middleware.RequirePermission("CREATE_LOCATIONS"), locationHandler.CreateLocation)
				locations.PUT("/:id", middleware.RequirePermission("UPDATE_LOCATIONS"), locationHandler.UpdateLocation)
				locations.DELETE("/:id", middleware.RequirePermission("DELETE_LOCATIONS"), locationHandler.DeleteLocation)
			}

			// Role and permission management routes
			roles := protected.Group("/roles")
			roles.Use(middleware.RequireRole("Admin")) // Only admins can manage roles
			{
				roles.GET("", roleHandler.GetRoles)
				roles.POST("", roleHandler.CreateRole)
				roles.PUT("/:id", roleHandler.UpdateRole)
				roles.DELETE("/:id", roleHandler.DeleteRole)
				roles.GET("/:id/permissions", roleHandler.GetRolePermissions)
				roles.POST("/:id/permissions", roleHandler.AssignPermissions)
			}

			// Permissions routes (read-only for role management)
			permissions := protected.Group("/permissions")
			permissions.Use(middleware.RequireRole("Admin"))
			{
				permissions.GET("", roleHandler.GetPermissions)
			}

			// Product management routes (require company)
			products := protected.Group("/products")
			products.Use(middleware.RequireCompanyAccess())
			{
				products.GET("", middleware.RequirePermission("VIEW_PRODUCTS"), productHandler.GetProducts)
				products.GET("/:id", middleware.RequirePermission("VIEW_PRODUCTS"), productHandler.GetProduct)
				products.GET("/:id/summary", middleware.RequirePermission("VIEW_PRODUCTS"), productHandler.GetProductSummary)
				products.POST("", middleware.RequirePermission("CREATE_PRODUCTS"), productHandler.CreateProduct)
				products.PUT("/:id", middleware.RequirePermission("UPDATE_PRODUCTS"), productHandler.UpdateProduct)
				products.DELETE("/:id", middleware.RequirePermission("DELETE_PRODUCTS"), productHandler.DeleteProduct)
			}

			// Category management routes (require company)
			categories := protected.Group("/categories")
			categories.Use(middleware.RequireCompanyAccess())
			{
				categories.GET("", middleware.RequirePermission("VIEW_PRODUCTS"), productHandler.GetCategories)
				categories.POST("", middleware.RequirePermission("CREATE_PRODUCTS"), productHandler.CreateCategory)
				categories.PUT("/:id", middleware.RequirePermission("UPDATE_PRODUCTS"), productHandler.UpdateCategory)
				categories.DELETE("/:id", middleware.RequirePermission("DELETE_PRODUCTS"), productHandler.DeleteCategory)
			}

			// Brand management routes (require company)
			brands := protected.Group("/brands")
			brands.Use(middleware.RequireCompanyAccess())
			{
				brands.GET("", middleware.RequirePermission("VIEW_PRODUCTS"), productHandler.GetBrands)
				brands.POST("", middleware.RequirePermission("CREATE_PRODUCTS"), productHandler.CreateBrand)
				brands.PUT("/:id", middleware.RequirePermission("UPDATE_PRODUCTS"), productHandler.UpdateBrand)
				brands.DELETE("/:id", middleware.RequirePermission("DELETE_PRODUCTS"), productHandler.DeleteBrand)
			}

			// Unit management routes (global)
			units := protected.Group("/units")
			{
				units.GET("", productHandler.GetUnits)
				units.POST("", middleware.RequireRole("Admin"), productHandler.CreateUnit)
			}

			// Product attribute definition management routes
			attrDefs := protected.Group("/product-attribute-definitions")
			attrDefs.Use(middleware.RequireCompanyAccess())
			{
				attrDefs.GET("", middleware.RequirePermission("VIEW_PRODUCTS"), productAttributeHandler.GetDefinitions)
				attrDefs.POST("", middleware.RequirePermission("CREATE_PRODUCTS"), productAttributeHandler.CreateDefinition)
				attrDefs.PUT("/:id", middleware.RequirePermission("UPDATE_PRODUCTS"), productAttributeHandler.UpdateDefinition)
				attrDefs.DELETE("/:id", middleware.RequirePermission("DELETE_PRODUCTS"), productAttributeHandler.DeleteDefinition)
			}

			// ADD THESE NEW INVENTORY ROUTES:
			// Inventory management routes (require company and location)
            inventory := protected.Group("/inventory")
            inventory.Use(middleware.RequireCompanyAccess())
            {
                inventory.GET("/stock", middleware.RequirePermission("VIEW_INVENTORY"), inventoryHandler.GetStock)
                inventory.POST("/stock-adjustment", middleware.RequirePermission("ADJUST_STOCK"), inventoryHandler.AdjustStock)
                inventory.GET("/stock-adjustments", middleware.RequirePermission("VIEW_INVENTORY"), inventoryHandler.GetStockAdjustments)
                // Stock adjustment documents
                inventory.POST("/stock-adjustment-documents", middleware.RequirePermission("ADJUST_STOCK"), inventoryHandler.CreateStockAdjustmentDocument)
                inventory.GET("/stock-adjustment-documents", middleware.RequirePermission("VIEW_INVENTORY"), inventoryHandler.GetStockAdjustmentDocuments)
                inventory.GET("/stock-adjustment-documents/:id", middleware.RequirePermission("VIEW_INVENTORY"), inventoryHandler.GetStockAdjustmentDocument)
                inventory.GET("/summary", middleware.RequirePermission("VIEW_INVENTORY"), inventoryHandler.GetInventorySummary)
                inventory.POST("/import", middleware.RequirePermission("ADJUST_STOCK"), inventoryHandler.ImportInventory)
                inventory.GET("/export", middleware.RequirePermission("VIEW_INVENTORY"), inventoryHandler.ExportInventory)
                inventory.POST("/barcode", middleware.RequirePermission("VIEW_INVENTORY"), inventoryHandler.GenerateBarcode)
                inventory.GET("/transfers", middleware.RequirePermission("VIEW_INVENTORY"), inventoryHandler.GetStockTransfers)
                inventory.GET("/transfers/:id", middleware.RequirePermission("VIEW_INVENTORY"), inventoryHandler.GetStockTransfer)
                inventory.POST("/transfers", middleware.RequirePermission("CREATE_TRANSFERS"), inventoryHandler.CreateStockTransfer)
                inventory.PUT("/transfers/:id/approve", middleware.RequirePermission("APPROVE_TRANSFERS"), inventoryHandler.ApproveStockTransfer)
                inventory.PUT("/transfers/:id/complete", middleware.RequirePermission("APPROVE_TRANSFERS"), inventoryHandler.CompleteStockTransfer)
                inventory.DELETE("/transfers/:id", middleware.RequirePermission("CREATE_TRANSFERS"), inventoryHandler.CancelStockTransfer)
                inventory.GET("/product-transactions", middleware.RequirePermission("VIEW_INVENTORY"), inventoryHandler.GetProductTransactions)
            }

			// Sales management routes (require company and location)
			sales := protected.Group("/sales")
			sales.Use(middleware.RequireCompanyAccess())
			{
				sales.GET("", middleware.RequirePermission("VIEW_SALES"), salesHandler.GetSales)
				sales.GET("/history", middleware.RequirePermission("VIEW_SALES"), salesHandler.GetSalesHistory)
				sales.GET("/history/export", middleware.RequirePermission("VIEW_SALES"), salesHandler.ExportInvoices)
				sales.GET("/:id", middleware.RequirePermission("VIEW_SALES"), salesHandler.GetSale)
				sales.POST("", middleware.RequirePermission("CREATE_SALES"), salesHandler.CreateSale)
				sales.PUT("/:id", middleware.RequirePermission("UPDATE_SALES"), salesHandler.UpdateSale)
				sales.DELETE("/:id", middleware.RequirePermission("DELETE_SALES"), salesHandler.DeleteSale)
				sales.POST("/:id/hold", middleware.RequirePermission("CREATE_SALES"), salesHandler.HoldSale)
				sales.POST("/:id/resume", middleware.RequirePermission("CREATE_SALES"), salesHandler.ResumeSale)
				sales.POST("/quick", middleware.RequirePermission("CREATE_SALES"), salesHandler.CreateQuickSale)

				quotes := sales.Group("/quotes")
				{
					quotes.GET("", middleware.RequirePermission("VIEW_SALES"), salesHandler.GetQuotes)
					quotes.GET("/export", middleware.RequirePermission("VIEW_SALES"), salesHandler.ExportQuotes)
					quotes.GET("/:id", middleware.RequirePermission("VIEW_SALES"), salesHandler.GetQuote)
					quotes.POST("", middleware.RequirePermission("CREATE_SALES"), salesHandler.CreateQuote)
					quotes.PUT("/:id", middleware.RequirePermission("UPDATE_SALES"), salesHandler.UpdateQuote)
					quotes.DELETE("/:id", middleware.RequirePermission("DELETE_SALES"), salesHandler.DeleteQuote)
					quotes.POST("/:id/print", middleware.RequirePermission("PRINT_INVOICES"), salesHandler.PrintQuote)
					quotes.POST("/:id/share", middleware.RequirePermission("VIEW_SALES"), salesHandler.ShareQuote)
				}
			}

			// POS specific routes (require company and location)
			pos := protected.Group("/pos")
			pos.Use(middleware.RequireCompanyAccess())
			{
				pos.GET("/products", middleware.RequirePermission("VIEW_PRODUCTS"), posHandler.GetPOSProducts)
				pos.GET("/customers", middleware.RequirePermission("VIEW_CUSTOMERS"), posHandler.GetPOSCustomers)
				pos.POST("/checkout", middleware.RequirePermission("CREATE_SALES"), posHandler.ProcessCheckout)
				pos.POST("/print", middleware.RequirePermission("PRINT_INVOICES"), posHandler.PrintInvoice)
				pos.GET("/held-sales", middleware.RequirePermission("VIEW_SALES"), posHandler.GetHeldSales)
				pos.GET("/payment-methods", middleware.RequirePermission("VIEW_SALES"), posHandler.GetPaymentMethods)
				pos.GET("/sales-summary", middleware.RequirePermission("VIEW_REPORTS"), posHandler.GetSalesSummary)
				pos.GET("/receipt/:id", middleware.RequirePermission("VIEW_SALES"), posHandler.GetReceiptData)
			}

			loyalty := protected.Group("/loyalty-programs")
			loyalty.Use(middleware.RequireCompanyAccess())
			{
				loyalty.GET("", middleware.RequirePermission("VIEW_LOYALTY"), loyaltyHandler.GetLoyaltyPrograms)
				loyalty.GET("/:customer_id", middleware.RequirePermission("VIEW_LOYALTY"), loyaltyHandler.GetCustomerLoyalty)
			}

			// Loyalty Redemptions routes
			loyaltyRedemptions := protected.Group("/loyalty-redemptions")
			loyaltyRedemptions.Use(middleware.RequireCompanyAccess())
			{
				loyaltyRedemptions.GET("", middleware.RequirePermission("VIEW_LOYALTY"), loyaltyHandler.GetLoyaltyRedemptions)
				loyaltyRedemptions.POST("", middleware.RequirePermission("REDEEM_POINTS"), loyaltyHandler.RedeemPoints)
			}

			// Loyalty Settings and Award Points
			loyaltyGeneral := protected.Group("/loyalty")
			loyaltyGeneral.Use(middleware.RequireCompanyAccess())
			{
				loyaltyGeneral.GET("/settings", middleware.RequirePermission("VIEW_LOYALTY"), loyaltyHandler.GetLoyaltySettings)
				loyaltyGeneral.POST("/award-points", middleware.RequirePermission("AWARD_POINTS"), loyaltyHandler.AwardPoints)
			}

			// Promotions routes
			promotions := protected.Group("/promotions")
			promotions.Use(middleware.RequireCompanyAccess())
			{
				promotions.GET("", middleware.RequirePermission("VIEW_PROMOTIONS"), loyaltyHandler.GetPromotions)
				promotions.POST("", middleware.RequirePermission("CREATE_PROMOTIONS"), loyaltyHandler.CreatePromotion)
				promotions.PUT("/:id", middleware.RequirePermission("UPDATE_PROMOTIONS"), loyaltyHandler.UpdatePromotion)
				promotions.DELETE("/:id", middleware.RequirePermission("DELETE_PROMOTIONS"), loyaltyHandler.DeletePromotion)
				promotions.POST("/check-eligibility", middleware.RequirePermission("VIEW_PROMOTIONS"), loyaltyHandler.CheckPromotionEligibility)
			}

			// Sale Returns routes (separate from sales module for better organization)
			saleReturns := protected.Group("/sale-returns")
			saleReturns.Use(middleware.RequireCompanyAccess())
			{
				saleReturns.GET("", middleware.RequirePermission("VIEW_RETURNS"), returnsHandler.GetSaleReturns)
				saleReturns.GET("/:id", middleware.RequirePermission("VIEW_RETURNS"), returnsHandler.GetSaleReturn)
				saleReturns.POST("", middleware.RequirePermission("CREATE_RETURNS"), returnsHandler.CreateSaleReturn)
				saleReturns.PUT("/:id", middleware.RequirePermission("UPDATE_RETURNS"), returnsHandler.UpdateSaleReturn)
				saleReturns.DELETE("/:id", middleware.RequirePermission("DELETE_RETURNS"), returnsHandler.DeleteSaleReturn)
				saleReturns.GET("/summary", middleware.RequirePermission("VIEW_REPORTS"), returnsHandler.GetReturnsSummary)
				saleReturns.GET("/search/:sale_id", middleware.RequirePermission("VIEW_RETURNS"), returnsHandler.SearchReturnableSale)
				saleReturns.POST("/process/:sale_id", middleware.RequirePermission("CREATE_RETURNS"), returnsHandler.ProcessQuickReturn)
			}

			// Purchase management routes (require company and location)
			purchases := protected.Group("/purchases")
			purchases.Use(middleware.RequireCompanyAccess())
			{
				purchases.GET("", middleware.RequirePermission("VIEW_PURCHASES"), purchaseHandler.GetPurchases)
				purchases.GET("/history", middleware.RequirePermission("VIEW_PURCHASES"), purchaseHandler.GetPurchaseHistory)
				purchases.GET("/pending", middleware.RequirePermission("VIEW_PURCHASES"), purchaseHandler.GetPendingPurchases)
				purchases.GET("/:id", middleware.RequirePermission("VIEW_PURCHASES"), purchaseHandler.GetPurchase)
				purchases.POST("", middleware.RequirePermission("CREATE_PURCHASES"), purchaseHandler.CreatePurchase)
				purchases.POST("/quick", middleware.RequirePermission("CREATE_PURCHASES"), purchaseHandler.CreateQuickPurchase)
				purchases.PUT("/:id", middleware.RequirePermission("UPDATE_PURCHASES"), purchaseHandler.UpdatePurchase)
                purchases.PUT("/:id/receive", middleware.RequirePermission("RECEIVE_PURCHASES"), purchaseHandler.ReceivePurchase)
                purchases.POST("/:id/invoice", middleware.RequirePermission("UPDATE_PURCHASES"), purchaseHandler.UploadPurchaseInvoice)
				purchases.DELETE("/:id", middleware.RequirePermission("DELETE_PURCHASES"), purchaseHandler.DeletePurchase)
			}

			purchaseOrders := protected.Group("/purchase-orders")
			purchaseOrders.Use(middleware.RequireCompanyAccess())
			{
				purchaseOrders.POST("", middleware.RequirePermission("CREATE_PURCHASES"), purchaseOrderHandler.CreatePurchaseOrder)
				purchaseOrders.PUT("/:id", middleware.RequirePermission("UPDATE_PURCHASES"), purchaseOrderHandler.UpdatePurchaseOrder)
				purchaseOrders.DELETE("/:id", middleware.RequirePermission("DELETE_PURCHASES"), purchaseOrderHandler.DeletePurchaseOrder)
				purchaseOrders.PUT("/:id/approve", middleware.RequirePermission("UPDATE_PURCHASES"), purchaseOrderHandler.ApprovePurchaseOrder)
			}

            goodsReceipts := protected.Group("/goods-receipts")
            goodsReceipts.Use(middleware.RequireCompanyAccess())
            {
                goodsReceipts.GET("", middleware.RequirePermission("VIEW_PURCHASES"), goodsReceiptHandler.GetGoodsReceipts)
                goodsReceipts.GET("/:id", middleware.RequirePermission("VIEW_PURCHASES"), goodsReceiptHandler.GetGoodsReceipt)
                goodsReceipts.POST("", middleware.RequirePermission("RECEIVE_PURCHASES"), goodsReceiptHandler.RecordGoodsReceipt)
            }

			// Purchase Returns management routes (require company and location)
            purchaseReturns := protected.Group("/purchase-returns")
            purchaseReturns.Use(middleware.RequireCompanyAccess())
            {
                purchaseReturns.GET("", middleware.RequirePermission("VIEW_PURCHASE_RETURNS"), purchaseHandler.GetPurchaseReturns)
                purchaseReturns.GET("/:id", middleware.RequirePermission("VIEW_PURCHASE_RETURNS"), purchaseHandler.GetPurchaseReturn)
                purchaseReturns.POST("", middleware.RequirePermission("CREATE_PURCHASE_RETURNS"), purchaseHandler.CreatePurchaseReturn)
                purchaseReturns.PUT("/:id", middleware.RequirePermission("UPDATE_PURCHASE_RETURNS"), purchaseHandler.UpdatePurchaseReturn)
                purchaseReturns.DELETE("/:id", middleware.RequirePermission("DELETE_PURCHASE_RETURNS"), purchaseHandler.DeletePurchaseReturn)
                purchaseReturns.POST("/:id/receipt", middleware.RequirePermission("UPDATE_PURCHASE_RETURNS"), purchaseHandler.UploadPurchaseReturnReceipt)
            }

			// Customer management routes (require company)
			customers := protected.Group("/customers")
			customers.Use(middleware.RequireCompanyAccess())
			{
				customers.GET("", middleware.RequirePermission("VIEW_CUSTOMERS"), customerHandler.GetCustomers)
				customers.GET("/:id/summary", middleware.RequirePermission("VIEW_CUSTOMERS"), customerHandler.GetCustomerSummary)
				customers.POST("", middleware.RequirePermission("CREATE_CUSTOMERS"), customerHandler.CreateCustomer)
				customers.POST("/import", middleware.RequirePermission("CREATE_CUSTOMERS"), customerHandler.ImportCustomers)
				customers.GET("/export", middleware.RequirePermission("VIEW_CUSTOMERS"), customerHandler.ExportCustomers)
				customers.PUT("/:id", middleware.RequirePermission("UPDATE_CUSTOMERS"), customerHandler.UpdateCustomer)
				customers.DELETE("/:id", middleware.RequirePermission("DELETE_CUSTOMERS"), customerHandler.DeleteCustomer)

				credit := customers.Group("/:id/credit")
				{
					credit.GET("", middleware.RequirePermission("VIEW_CUSTOMERS"), customerHandler.GetCreditHistory)
					credit.POST("", middleware.RequirePermission("UPDATE_CUSTOMERS"), customerHandler.RecordCreditTransaction)
				}
			}

			// Employee management routes (require company)
			employees := protected.Group("/employees")
			employees.Use(middleware.RequireCompanyAccess())
			{
				employees.GET("", middleware.RequirePermission("VIEW_EMPLOYEES"), employeeHandler.GetEmployees)
				employees.POST("", middleware.RequirePermission("CREATE_EMPLOYEES"), employeeHandler.CreateEmployee)
				employees.PUT("/:id", middleware.RequirePermission("UPDATE_EMPLOYEES"), employeeHandler.UpdateEmployee)
				employees.DELETE("/:id", middleware.RequirePermission("DELETE_EMPLOYEES"), employeeHandler.DeleteEmployee)
			}

			// Attendance routes (require company)
			attendance := protected.Group("/attendance")
			attendance.Use(middleware.RequireCompanyAccess())
			{
				attendance.POST("/check-in", middleware.RequirePermission("MANAGE_ATTENDANCE"), attendanceHandler.CheckIn)
				attendance.POST("/check-out", middleware.RequirePermission("MANAGE_ATTENDANCE"), attendanceHandler.CheckOut)
				attendance.POST("/leave", middleware.RequirePermission("MANAGE_ATTENDANCE"), attendanceHandler.ApplyLeave)
				attendance.GET("/holidays", middleware.RequirePermission("VIEW_ATTENDANCE"), attendanceHandler.GetHolidays)
				attendance.GET("/records", middleware.RequirePermission("VIEW_ATTENDANCE"), attendanceHandler.GetAttendanceRecords)
			}

			// Payroll routes (require company)
			payrolls := protected.Group("/payrolls")
			payrolls.Use(middleware.RequireCompanyAccess())
			{
				payrolls.GET("", middleware.RequirePermission("VIEW_PAYROLLS"), payrollHandler.GetPayrolls)
				payrolls.POST("", middleware.RequirePermission("CREATE_PAYROLLS"), payrollHandler.CreatePayroll)
				payrolls.PUT("/:id/mark-paid", middleware.RequirePermission("PROCESS_PAYROLLS"), payrollHandler.MarkPayrollPaid)
				payrolls.POST("/:id/components", middleware.RequirePermission("CREATE_PAYROLLS"), payrollHandler.AddSalaryComponent)
				payrolls.POST("/:id/advances", middleware.RequirePermission("CREATE_PAYROLLS"), payrollHandler.RecordAdvance)
				payrolls.POST("/:id/deductions", middleware.RequirePermission("CREATE_PAYROLLS"), payrollHandler.RecordDeduction)
				payrolls.GET("/:id/payslip", middleware.RequirePermission("VIEW_PAYROLLS"), payrollHandler.GeneratePayslip)
			}

			// Collection routes (require company)
			collections := protected.Group("/collections")
			collections.Use(middleware.RequireCompanyAccess())
			{
				collections.GET("", middleware.RequirePermission("VIEW_COLLECTIONS"), collectionHandler.GetCollections)
				collections.POST("", middleware.RequirePermission("CREATE_COLLECTIONS"), collectionHandler.CreateCollection)
				collections.GET("/outstanding", middleware.RequirePermission("VIEW_COLLECTIONS"), collectionHandler.GetOutstanding)
				collections.GET("/:id/receipt", middleware.RequirePermission("VIEW_COLLECTIONS"), collectionHandler.GetCollectionReceipt)
				collections.DELETE("/:id", middleware.RequirePermission("DELETE_COLLECTIONS"), collectionHandler.DeleteCollection)
			}

			expenses := protected.Group("/expenses")
			expenses.Use(middleware.RequireCompanyAccess())
			{
				expenses.GET("", middleware.RequirePermission("VIEW_EXPENSES"), expenseHandler.GetExpenses)
				expenses.GET("/:id", middleware.RequirePermission("VIEW_EXPENSES"), expenseHandler.GetExpense)
				expenses.POST("", middleware.RequirePermission("CREATE_EXPENSES"), expenseHandler.CreateExpense)
				categories := expenses.Group("/categories")
				{
					categories.GET("", middleware.RequirePermission("VIEW_EXPENSES"), expenseHandler.GetCategories)
					categories.POST("", middleware.RequirePermission("CREATE_EXPENSES"), expenseHandler.CreateCategory)
					categories.PUT("/:id", middleware.RequirePermission("UPDATE_EXPENSES"), expenseHandler.UpdateCategory)
					categories.DELETE("/:id", middleware.RequirePermission("DELETE_EXPENSES"), expenseHandler.DeleteCategory)
				}
			}

			vouchers := protected.Group("/vouchers")
			vouchers.Use(middleware.RequireCompanyAccess())
			{
				vouchers.GET("", middleware.RequirePermission("VIEW_VOUCHERS"), voucherHandler.ListVouchers)
				vouchers.GET("/:id", middleware.RequirePermission("VIEW_VOUCHERS"), voucherHandler.GetVoucher)
				vouchers.POST("/:type", middleware.RequirePermission("MANAGE_VOUCHERS"), voucherHandler.CreateVoucher)
			}

			ledgers := protected.Group("/ledgers")
			ledgers.Use(middleware.RequireCompanyAccess())
			{
				ledgers.GET("", middleware.RequirePermission("VIEW_LEDGER"), ledgerHandler.GetBalances)
				ledgers.GET("/:account_id/entries", middleware.RequirePermission("VIEW_LEDGER_DETAILS"), ledgerHandler.GetEntries)
			}

			cashRegisters := protected.Group("/cash-registers")
			cashRegisters.Use(middleware.RequireCompanyAccess())
			{
				cashRegisters.GET("", middleware.RequirePermission("VIEW_CASH_REGISTERS"), cashRegisterHandler.GetCashRegisters)
				cashRegisters.POST("/open", middleware.RequirePermission("OPEN_CASH_REGISTER"), cashRegisterHandler.OpenCashRegister)
				cashRegisters.POST("/close", middleware.RequirePermission("CLOSE_CASH_REGISTER"), cashRegisterHandler.CloseCashRegister)
				cashRegisters.POST("/tally", middleware.RequirePermission("TALLY_CASH_REGISTER"), cashRegisterHandler.RecordTally)
			}

			reports := protected.Group("/reports")
			reports.Use(middleware.RequireCompanyAccess())
			{
				reports.GET("/sales-summary", middleware.RequirePermission("VIEW_REPORTS"), reportsHandler.GetSalesSummary)
				reports.GET("/stock-summary", middleware.RequirePermission("VIEW_REPORTS"), reportsHandler.GetStockSummary)
				reports.GET("/top-products", middleware.RequirePermission("VIEW_REPORTS"), reportsHandler.GetTopProducts)
				reports.GET("/customer-balances", middleware.RequirePermission("VIEW_REPORTS"), reportsHandler.GetCustomerBalances)
				reports.GET("/expenses-summary", middleware.RequirePermission("VIEW_REPORTS"), reportsHandler.GetExpensesSummary)
				reports.GET("/item-movement", middleware.RequirePermission("VIEW_REPORTS"), reportsHandler.GetItemMovement)
				reports.GET("/valuation", middleware.RequirePermission("VIEW_REPORTS"), reportsHandler.GetValuationReport)
				reports.GET("/purchase-vs-returns", middleware.RequirePermission("VIEW_REPORTS"), reportsHandler.GetPurchaseVsReturns)
				reports.GET("/supplier", middleware.RequirePermission("VIEW_REPORTS"), reportsHandler.GetSupplierReport)
				reports.GET("/daily-cash", middleware.RequirePermission("VIEW_REPORTS"), reportsHandler.GetDailyCashReport)
				reports.GET("/income-expense", middleware.RequirePermission("VIEW_REPORTS"), reportsHandler.GetIncomeExpenseReport)
				reports.GET("/general-ledger", middleware.RequirePermission("VIEW_REPORTS"), reportsHandler.GetGeneralLedger)
				reports.GET("/trial-balance", middleware.RequirePermission("VIEW_REPORTS"), reportsHandler.GetTrialBalance)
				reports.GET("/profit-loss", middleware.RequirePermission("VIEW_REPORTS"), reportsHandler.GetProfitLoss)
				reports.GET("/balance-sheet", middleware.RequirePermission("VIEW_REPORTS"), reportsHandler.GetBalanceSheet)
				reports.GET("/outstanding", middleware.RequirePermission("VIEW_REPORTS"), reportsHandler.GetOutstandingReport)
				reports.GET("/tax", middleware.RequirePermission("VIEW_REPORTS"), reportsHandler.GetTaxReport)
				reports.GET("/top-performers", middleware.RequirePermission("VIEW_REPORTS"), reportsHandler.GetTopPerformers)
			}

			// Supplier management routes (require company)
            suppliers := protected.Group("/suppliers")
            suppliers.Use(middleware.RequireCompanyAccess())
            {
                suppliers.GET("", middleware.RequirePermission("VIEW_SUPPLIERS"), supplierHandler.GetSuppliers)
                suppliers.POST("/import", middleware.RequirePermission("CREATE_SUPPLIERS"), supplierHandler.ImportSuppliers)
                suppliers.GET("/export", middleware.RequirePermission("VIEW_SUPPLIERS"), supplierHandler.ExportSuppliers)
                suppliers.GET("/:id/summary", middleware.RequirePermission("VIEW_SUPPLIERS"), supplierHandler.GetSupplierSummary)
                suppliers.GET("/:id", middleware.RequirePermission("VIEW_SUPPLIERS"), supplierHandler.GetSupplier)
                suppliers.POST("", middleware.RequirePermission("CREATE_SUPPLIERS"), supplierHandler.CreateSupplier)
                suppliers.PUT("/:id", middleware.RequirePermission("UPDATE_SUPPLIERS"), supplierHandler.UpdateSupplier)
                suppliers.DELETE("/:id", middleware.RequirePermission("DELETE_SUPPLIERS"), supplierHandler.DeleteSupplier)
            }

            // Payments (supplier) routes
            payments := protected.Group("/payments")
            payments.Use(middleware.RequireCompanyAccess())
            {
                payments.GET("", middleware.RequirePermission("VIEW_PURCHASES"), paymentHandler.GetPayments)
            }

			// Currency routes
			currencies := protected.Group("/currencies")
			currencies.Use(middleware.RequireCompanyAccess())
			{
				currencies.GET("", middleware.RequirePermission("VIEW_SETTINGS"), currencyHandler.GetCurrencies)
				currencies.POST("", middleware.RequirePermission("MANAGE_SETTINGS"), currencyHandler.CreateCurrency)
				currencies.PUT("/:id", middleware.RequirePermission("MANAGE_SETTINGS"), currencyHandler.UpdateCurrency)
				currencies.PATCH("/:id", middleware.RequirePermission("MANAGE_SETTINGS"), currencyHandler.UpdateCurrency)
				currencies.DELETE("/:id", middleware.RequirePermission("MANAGE_SETTINGS"), currencyHandler.DeleteCurrency)
			}

			// Tax routes
            taxes := protected.Group("/taxes")
            taxes.Use(middleware.RequireCompanyAccess())
            {
                // Allow viewing taxes with VIEW_SETTINGS, but restrict modifications
                taxes.GET("", middleware.RequirePermission("VIEW_SETTINGS"), taxHandler.GetTaxes)
                taxes.POST("", middleware.RequirePermission("MANAGE_SETTINGS"), taxHandler.CreateTax)
                taxes.PUT("/:id", middleware.RequirePermission("MANAGE_SETTINGS"), taxHandler.UpdateTax)
                taxes.DELETE("/:id", middleware.RequirePermission("MANAGE_SETTINGS"), taxHandler.DeleteTax)
            }

			// Settings routes
			settings := protected.Group("/settings")
			settings.Use(middleware.RequireCompanyAccess())
			{
				settings.GET("", middleware.RequirePermission("VIEW_SETTINGS"), settingsHandler.GetSettings)
				settings.PUT("", middleware.RequirePermission("MANAGE_SETTINGS"), settingsHandler.UpdateSettings)

				settings.GET("/company", middleware.RequirePermission("VIEW_SETTINGS"), settingsHandler.GetCompanySettings)
				settings.PUT("/company", middleware.RequirePermission("MANAGE_SETTINGS"), settingsHandler.UpdateCompanySettings)

				settings.GET("/invoice", middleware.RequirePermission("VIEW_SETTINGS"), settingsHandler.GetInvoiceSettings)
				settings.PUT("/invoice", middleware.RequirePermission("MANAGE_SETTINGS"), settingsHandler.UpdateInvoiceSettings)

				settings.GET("/tax", middleware.RequirePermission("VIEW_SETTINGS"), settingsHandler.GetTaxSettings)
				settings.PUT("/tax", middleware.RequirePermission("MANAGE_SETTINGS"), settingsHandler.UpdateTaxSettings)

				settings.GET("/device-control", middleware.RequirePermission("VIEW_SETTINGS"), settingsHandler.GetDeviceControlSettings)
				settings.PUT("/device-control", middleware.RequirePermission("MANAGE_SETTINGS"), settingsHandler.UpdateDeviceControlSettings)

				settings.GET("/session-limit", middleware.RequirePermission("VIEW_SETTINGS"), settingsHandler.GetSessionLimit)
				settings.POST("/session-limit", middleware.RequirePermission("MANAGE_SETTINGS"), settingsHandler.SetSessionLimit)
				settings.PUT("/session-limit", middleware.RequirePermission("MANAGE_SETTINGS"), settingsHandler.SetSessionLimit)
				settings.DELETE("/session-limit", middleware.RequirePermission("MANAGE_SETTINGS"), settingsHandler.DeleteSessionLimit)

				settings.GET("/payment-methods", middleware.RequirePermission("VIEW_SETTINGS"), settingsHandler.GetPaymentMethods)
				settings.POST("/payment-methods", middleware.RequirePermission("MANAGE_SETTINGS"), settingsHandler.CreatePaymentMethod)
				settings.PUT("/payment-methods/:id", middleware.RequirePermission("MANAGE_SETTINGS"), settingsHandler.UpdatePaymentMethod)
				settings.DELETE("/payment-methods/:id", middleware.RequirePermission("MANAGE_SETTINGS"), settingsHandler.DeletePaymentMethod)
				// currencies mapping for payment methods
				settings.GET("/payment-methods/currencies", middleware.RequirePermission("VIEW_SETTINGS"), settingsHandler.GetPaymentMethodCurrencies)
				settings.PUT("/payment-methods/:id/currencies", middleware.RequirePermission("MANAGE_SETTINGS"), settingsHandler.SetPaymentMethodCurrencies)

				settings.GET("/printer", middleware.RequirePermission("VIEW_SETTINGS"), settingsHandler.GetPrinters)
				settings.POST("/printer", middleware.RequirePermission("MANAGE_SETTINGS"), settingsHandler.CreatePrinter)
				settings.PUT("/printer/:id", middleware.RequirePermission("MANAGE_SETTINGS"), settingsHandler.UpdatePrinter)
				settings.DELETE("/printer/:id", middleware.RequirePermission("MANAGE_SETTINGS"), settingsHandler.DeletePrinter)
			}

			// Audit log routes
			audit := protected.Group("/audit-logs")
			audit.Use(middleware.RequireCompanyAccess())
			{
				audit.GET("", middleware.RequirePermission("VIEW_AUDIT_LOGS"), auditLogHandler.GetAuditLogs)
			}

			// Language routes
			languages := protected.Group("/languages")
			languages.Use(middleware.RequireRole("Admin"))
			{
				languages.PUT("/:code", languageHandler.UpdateLanguageStatus)
			}

			// Translation routes
			translations := protected.Group("/translations")
			translations.Use(middleware.RequireCompanyAccess())
			{
				translations.GET("", middleware.RequirePermission("VIEW_TRANSLATIONS"), translationHandler.GetTranslations)
				translations.PUT("", middleware.RequirePermission("MANAGE_TRANSLATIONS"), translationHandler.UpdateTranslations)
			}

			// User preferences routes
			userPrefs := protected.Group("/user-preferences")
			{
				userPrefs.GET("", userPreferencesHandler.GetPreferences)
				userPrefs.PUT("", userPreferencesHandler.UpsertPreference)
				userPrefs.PATCH("", userPreferencesHandler.UpsertPreference)
				userPrefs.DELETE("/:key", userPreferencesHandler.DeletePreference)
			}

			// Numbering sequence routes
			numberingSequences := protected.Group("/numbering-sequences")
			numberingSequences.Use(middleware.RequireCompanyAccess())
			{
				numberingSequences.GET("", middleware.RequirePermission("VIEW_SETTINGS"), numberingSequenceHandler.GetNumberingSequences)
				numberingSequences.GET("/:id", middleware.RequirePermission("VIEW_SETTINGS"), numberingSequenceHandler.GetNumberingSequence)
				numberingSequences.POST("", middleware.RequirePermission("MANAGE_SETTINGS"), numberingSequenceHandler.CreateNumberingSequence)
				numberingSequences.PUT("/:id", middleware.RequirePermission("MANAGE_SETTINGS"), numberingSequenceHandler.UpdateNumberingSequence)
				numberingSequences.DELETE("/:id", middleware.RequirePermission("MANAGE_SETTINGS"), numberingSequenceHandler.DeleteNumberingSequence)
			}

			// Invoice template routes
			invoiceTemplates := protected.Group("/invoice-templates")
			invoiceTemplates.Use(middleware.RequireCompanyAccess())
			{
				invoiceTemplates.GET("", middleware.RequirePermission("VIEW_SETTINGS"), invoiceTemplateHandler.GetInvoiceTemplates)
				invoiceTemplates.GET("/:id", middleware.RequirePermission("VIEW_SETTINGS"), invoiceTemplateHandler.GetInvoiceTemplate)
				invoiceTemplates.POST("", middleware.RequirePermission("MANAGE_SETTINGS"), invoiceTemplateHandler.CreateInvoiceTemplate)
				invoiceTemplates.PUT("/:id", middleware.RequirePermission("MANAGE_SETTINGS"), invoiceTemplateHandler.UpdateInvoiceTemplate)
				invoiceTemplates.DELETE("/:id", middleware.RequirePermission("MANAGE_SETTINGS"), invoiceTemplateHandler.DeleteInvoiceTemplate)
			}

			// Printing routes
			printGroup := protected.Group("/print")
			printGroup.Use(middleware.RequireCompanyAccess())
			{
				printGroup.POST("/receipt", middleware.RequirePermission("PRINT_RECEIPTS"), printHandler.PrintReceipt)
			}

			// Workflow & Approvals routes
			workflow := protected.Group("/workflow-requests")
			workflow.Use(middleware.RequireCompanyAccess())
			{
				workflow.GET("", middleware.RequirePermission("VIEW_WORKFLOWS"), workflowHandler.GetWorkflowRequests)
				workflow.POST("", middleware.RequirePermission("CREATE_WORKFLOWS"), workflowHandler.CreateWorkflowRequest)
				workflow.PUT("/:id/approve", middleware.RequirePermission("APPROVE_WORKFLOWS"), workflowHandler.ApproveWorkflowRequest)
				workflow.PUT("/:id/reject", middleware.RequirePermission("APPROVE_WORKFLOWS"), workflowHandler.RejectWorkflowRequest)
			}
		}
	}

	// Handle 404
	router.NoRoute(func(c *gin.Context) {
		utils.NotFoundResponse(c, "Endpoint not found")
	})

	// Handle 405 Method Not Allowed
	router.NoMethod(func(c *gin.Context) {
		c.JSON(http.StatusMethodNotAllowed, gin.H{
			"success": false,
			"message": "Method not allowed",
		})
	})
    // Serve uploaded files
    router.Static("/uploads", cfg.UploadPath)
}
