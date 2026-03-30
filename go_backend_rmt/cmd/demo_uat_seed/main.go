package main

import (
	"database/sql"
	"flag"
	"fmt"
	"log"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
	"erp-backend/internal/services"

	"github.com/joho/godotenv"
)

const (
	demoPassword = "DemoPass!234"
)

type productSeed struct {
	ProductID  int
	BarcodeID  int
	Name       string
	Tracking   string
	UnitPrice  float64
	TaxID      int
	LocationID int
}

type datasetSummary struct {
	CompanyID       int
	LocationIDs     map[string]int
	Usernames       []string
	CustomerCount   int
	SupplierCount   int
	ProductCount    int
	PurchaseCount   int
	SaleCount       int
	ExpenseCount    int
	WorkflowCount   int
	CollectionCount int
}

func main() {
	var (
		databaseURL = flag.String("database-url", os.Getenv("DATABASE_URL"), "PostgreSQL connection string")
		migrations  = flag.String("migrations-dir", filepath.Join("go_backend_rmt", "migrations"), "Path to Goose migrations")
		reportOut   = flag.String("report-out", filepath.Join("docs", "DEMO_DATASET_REPORT.md"), "Markdown summary output path")
		allowRemote = flag.Bool("allow-remote", false, "Allow resetting a non-local database")
	)
	flag.Parse()

	_ = godotenv.Overload(filepath.Join("go_backend_rmt", ".env"))

	if strings.TrimSpace(*databaseURL) == "" {
		log.Fatal("DATABASE_URL is required")
	}
	if !*allowRemote {
		if err := guardLocalDatabase(*databaseURL); err != nil {
			log.Fatal(err)
		}
	}

	if _, err := database.Initialize(*databaseURL); err != nil {
		log.Fatalf("failed to connect database: %v", err)
	}
	defer database.Close()

	db := database.GetDB()
	if err := resetPublicSchema(db); err != nil {
		log.Fatalf("failed to reset schema: %v", err)
	}
	if err := database.ApplyMigrations(db, *migrations); err != nil {
		log.Fatalf("failed to apply migrations: %v", err)
	}

	summary, err := seedDemoDataset(db)
	if err != nil {
		log.Fatalf("failed to seed demo dataset: %v", err)
	}

	if err := writeReport(*reportOut, summary); err != nil {
		log.Fatalf("failed to write report: %v", err)
	}

	log.Printf("Demo/UAT dataset reset complete. Report written to %s", *reportOut)
}

func guardLocalDatabase(databaseURL string) error {
	parsed, err := url.Parse(databaseURL)
	if err != nil {
		return fmt.Errorf("invalid DATABASE_URL: %w", err)
	}
	host := strings.TrimSpace(parsed.Hostname())
	if host == "" {
		return nil
	}
	if host == "localhost" || host == "127.0.0.1" || host == "0.0.0.0" {
		return nil
	}
	if ip := net.ParseIP(host); ip != nil && ip.IsLoopback() {
		return nil
	}
	return fmt.Errorf("refusing to reset non-local database host %q without --allow-remote", host)
}

func resetPublicSchema(db *sql.DB) error {
	_, err := db.Exec(`DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;`)
	return err
}

func seedDemoDataset(db *sql.DB) (*datasetSummary, error) {
	authSvc := services.NewAuthService()
	companySvc := services.NewCompanyService()
	locationSvc := services.NewLocationService()
	roleSvc := services.NewRoleService()
	userSvc := services.NewUserService()
	settingsSvc := services.NewSettingsService()
	taxSvc := services.NewTaxService()
	customerSvc := services.NewCustomerService()
	supplierSvc := services.NewSupplierService()
	productSvc := services.NewProductService()
	purchaseSvc := services.NewPurchaseService()
	purchaseReturnSvc := services.NewPurchaseReturnService()
	salesSvc := services.NewSalesService()
	returnsSvc := services.NewReturnsService()
	posSvc := services.NewPOSService()
	collectionSvc := services.NewCollectionService()
	expenseSvc := services.NewExpenseService()
	cashSvc := services.NewCashRegisterService()
	workflowSvc := services.NewWorkflowService()
	employeeSvc := services.NewEmployeeService()
	payrollSvc := services.NewPayrollService()

	adminFirst := "Release"
	adminLast := "Admin"
	adminPhone := "+96890000001"
	adminResp, err := authSvc.Register(&models.RegisterRequest{
		Username:  "admin.demo",
		Email:     "admin.demo@example.com",
		Password:  demoPassword,
		FirstName: &adminFirst,
		LastName:  &adminLast,
		Phone:     &adminPhone,
	})
	if err != nil {
		return nil, err
	}

	address := "HQ, Muscat"
	phone := "+96824000001"
	email := "ops@ebsdemo.example.com"
	taxNumber := "OMN-ERP-DEMO-001"
	usdID, err := lookupCurrencyID(db, "USD")
	if err != nil {
		return nil, err
	}
	company, err := companySvc.CreateCompany(&models.CreateCompanyRequest{
		Name:                   "EBS Demo Retail LLC",
		Address:                &address,
		Phone:                  &phone,
		Email:                  &email,
		TaxNumber:              &taxNumber,
		CurrencyID:             &usdID,
		InventoryCostingMethod: "WAC",
	}, adminResp.UserID)
	if err != nil {
		return nil, err
	}

	hqID, err := renameDefaultLocation(db, company.CompanyID, "HQ", "HQ, Muscat")
	if err != nil {
		return nil, err
	}
	mainStoreID, err := createLocation(locationSvc, company.CompanyID, "Main Store", "Seeb")
	if err != nil {
		return nil, err
	}
	secondaryStoreID, err := createLocation(locationSvc, company.CompanyID, "Secondary Store", "Barka")
	if err != nil {
		return nil, err
	}

	if err := settingsSvc.UpdateSecurityPolicy(company.CompanyID, models.SecurityPolicySettings{
		MinPasswordLength:        12,
		RequireUppercase:         true,
		RequireLowercase:         true,
		RequireNumber:            true,
		RequireSpecial:           true,
		SessionIdleTimeoutMins:   240,
		ElevatedAccessWindowMins: 10,
	}); err != nil {
		return nil, err
	}
	if err := settingsSvc.SetMaxSessions(company.CompanyID, 3); err != nil {
		return nil, err
	}

	taxNoneID, err := lookupTaxID(db, company.CompanyID, "None")
	if err != nil {
		return nil, err
	}
	five := 5.0
	vat, err := taxSvc.CreateTax(company.CompanyID, &models.CreateTaxRequest{
		Name:       "VAT 5%",
		Percentage: &five,
		IsActive:   true,
	})
	if err != nil {
		return nil, err
	}

	paymentMethodIDs, err := seedPaymentMethods(settingsSvc, company.CompanyID)
	if err != nil {
		return nil, err
	}

	roleIDs, err := collectRoleIDs(db)
	if err != nil {
		return nil, err
	}
	viewerRoleID, err := ensureViewerRole(db, roleSvc)
	if err != nil {
		return nil, err
	}
	roleIDs["Viewer"] = viewerRoleID

	usersToCreate := []struct {
		username   string
		email      string
		firstName  string
		lastName   string
		phone      string
		roleName   string
		locationID int
	}{
		{"manager.demo", "manager.demo@example.com", "Mona", "Manager", "+96890000002", "Manager", mainStoreID},
		{"cashier.demo", "cashier.demo@example.com", "Cara", "Cashier", "+96890000003", "Sales", mainStoreID},
		{"purchaser.demo", "purchaser.demo@example.com", "Paul", "Purchaser", "+96890000004", "Purchase Manager", hqID},
		{"accountant.demo", "accountant.demo@example.com", "Amina", "Accountant", "+96890000005", "Accountant", hqID},
		{"inventory.demo", "inventory.demo@example.com", "Ivan", "Inventory", "+96890000006", "Store", secondaryStoreID},
		{"hr.demo", "hr.demo@example.com", "Hana", "HR", "+96890000007", "HR", hqID},
		{"viewer.demo", "viewer.demo@example.com", "Vera", "Viewer", "+96890000008", "Viewer", hqID},
	}
	createdUsers := []string{"admin.demo"}
	for _, item := range usersToCreate {
		roleID := roleIDs[item.roleName]
		firstName := item.firstName
		lastName := item.lastName
		phoneNumber := item.phone
		locationID := item.locationID
		if _, err := userSvc.CreateUser(&models.CreateUserRequest{
			Username:   item.username,
			Email:      item.email,
			Password:   demoPassword,
			FirstName:  &firstName,
			LastName:   &lastName,
			Phone:      &phoneNumber,
			RoleID:     &roleID,
			LocationID: &locationID,
			CompanyID:  company.CompanyID,
		}, adminResp.UserID); err != nil {
			return nil, err
		}
		createdUsers = append(createdUsers, item.username)
	}

	tierSilver, err := services.NewLoyaltyService().CreateTier(company.CompanyID, &models.CreateLoyaltyTierRequest{
		Name: "Silver", MinPoints: 0,
	})
	if err != nil {
		return nil, err
	}

	customers, err := seedCustomers(customerSvc, company.CompanyID, adminResp.UserID, tierSilver.TierID)
	if err != nil {
		return nil, err
	}
	suppliers, err := seedSuppliers(supplierSvc, company.CompanyID, adminResp.UserID)
	if err != nil {
		return nil, err
	}
	products, err := seedProducts(db, productSvc, company.CompanyID, adminResp.UserID, suppliers, taxNoneID, vat.TaxID)
	if err != nil {
		return nil, err
	}

	if _, err := cashSvc.OpenCashRegister(company.CompanyID, mainStoreID, adminResp.UserID, 500, "", "demo-open-main", nil, nil); err != nil {
		return nil, err
	}
	moveNote := "Float top-up"
	if _, err := cashSvc.RecordMovement(company.CompanyID, mainStoreID, adminResp.UserID, &models.CashRegisterMovementRequest{
		Direction:  "IN",
		Amount:     150,
		ReasonCode: "FLOAT",
		Notes:      &moveNote,
	}, "", "demo-move-main", nil, nil); err != nil {
		return nil, err
	}
	denoms := models.JSONB{"100": 4, "50": 2, "20": 5}
	if err := cashSvc.CloseCashRegister(company.CompanyID, mainStoreID, adminResp.UserID, 650, &denoms, "", "demo-close-main", nil, nil); err != nil {
		return nil, err
	}
	if _, err := cashSvc.OpenCashRegister(company.CompanyID, secondaryStoreID, adminResp.UserID, 300, "", "demo-open-secondary", nil, nil); err != nil {
		return nil, err
	}

	purchaseCount := 0
	standardPurchase, err := purchaseSvc.CreatePurchase(company.CompanyID, mainStoreID, adminResp.UserID, &models.CreatePurchaseRequest{
		SupplierID: suppliers[0],
		Items: []models.CreatePurchaseDetailRequest{
			{ProductID: products["std_01"].ProductID, BarcodeID: intPtr(products["std_01"].BarcodeID), Quantity: 40, UnitPrice: 8, TaxID: intPtr(vat.TaxID)},
			{ProductID: products["var_01"].ProductID, BarcodeID: intPtr(products["var_01"].BarcodeID), Quantity: 20, UnitPrice: 10, TaxID: intPtr(vat.TaxID)},
		},
	}, "purchase-standard-1")
	if err != nil {
		return nil, err
	}
	purchaseCount++
	if _, err := purchaseSvc.RecordGoodsReceiptDetailed(standardPurchase.PurchaseID, company.CompanyID, adminResp.UserID, &models.RecordGoodsReceiptRequest{
		PurchaseID: standardPurchase.PurchaseID,
		Items: []models.ReceivePurchaseItemRequest{
			{PurchaseDetailID: standardPurchase.Items[0].PurchaseDetailID, BarcodeID: intPtr(products["std_01"].BarcodeID), ReceivedQuantity: 40},
			{PurchaseDetailID: standardPurchase.Items[1].PurchaseDetailID, BarcodeID: intPtr(products["var_01"].BarcodeID), ReceivedQuantity: 20},
		},
	}); err != nil {
		return nil, err
	}

	batchNumber := "BATCH-001"
	expiry := time.Now().AddDate(0, 6, 0)
	batchPurchase, err := purchaseSvc.CreatePurchase(company.CompanyID, mainStoreID, adminResp.UserID, &models.CreatePurchaseRequest{
		SupplierID: suppliers[1],
		Items: []models.CreatePurchaseDetailRequest{
			{ProductID: products["batch_01"].ProductID, BarcodeID: intPtr(products["batch_01"].BarcodeID), Quantity: 30, UnitPrice: 12, TaxID: intPtr(vat.TaxID), BatchNumber: &batchNumber, ExpiryDate: &expiry},
		},
	}, "purchase-batch-1")
	if err != nil {
		return nil, err
	}
	purchaseCount++
	if _, err := purchaseSvc.RecordGoodsReceiptDetailed(batchPurchase.PurchaseID, company.CompanyID, adminResp.UserID, &models.RecordGoodsReceiptRequest{
		PurchaseID: batchPurchase.PurchaseID,
		Items: []models.ReceivePurchaseItemRequest{
			{PurchaseDetailID: batchPurchase.Items[0].PurchaseDetailID, BarcodeID: intPtr(products["batch_01"].BarcodeID), ReceivedQuantity: 30, BatchNumber: &batchNumber, ExpiryDate: &expiry},
		},
	}); err != nil {
		return nil, err
	}
	batchLotID, err := lookupLotID(db, products["batch_01"].BarcodeID, batchNumber)
	if err != nil {
		return nil, err
	}

	serialPurchase, err := purchaseSvc.CreatePurchase(company.CompanyID, secondaryStoreID, adminResp.UserID, &models.CreatePurchaseRequest{
		SupplierID: suppliers[2],
		Items: []models.CreatePurchaseDetailRequest{
			{ProductID: products["ser_01"].ProductID, BarcodeID: intPtr(products["ser_01"].BarcodeID), Quantity: 2, UnitPrice: 150, TaxID: intPtr(vat.TaxID), SerialNumbers: []string{"SER-0001", "SER-0002"}},
		},
	}, "purchase-serial-1")
	if err != nil {
		return nil, err
	}
	purchaseCount++
	if _, err := purchaseSvc.RecordGoodsReceiptDetailed(serialPurchase.PurchaseID, company.CompanyID, adminResp.UserID, &models.RecordGoodsReceiptRequest{
		PurchaseID: serialPurchase.PurchaseID,
		Items: []models.ReceivePurchaseItemRequest{
			{PurchaseDetailID: serialPurchase.Items[0].PurchaseDetailID, BarcodeID: intPtr(products["ser_01"].BarcodeID), ReceivedQuantity: 2, SerialNumbers: []string{"SER-0001", "SER-0002"}},
		},
	}); err != nil {
		return nil, err
	}

	reasonPurchaseReturn := "Damaged carton"
	if _, err := purchaseReturnSvc.CreatePurchaseReturn(company.CompanyID, mainStoreID, adminResp.UserID, &models.CreatePurchaseReturnRequest{
		PurchaseID: batchPurchase.PurchaseID,
		Reason:     &reasonPurchaseReturn,
		Items: []models.CreatePurchaseReturnDetailRequest{
			{PurchaseDetailID: intPtr(batchPurchase.Items[0].PurchaseDetailID), ProductID: products["batch_01"].ProductID, BarcodeID: intPtr(products["batch_01"].BarcodeID), Quantity: 2, UnitPrice: 12, BatchAllocations: []models.InventoryBatchSelectionInput{{LotID: batchLotID, Quantity: 2}}},
		},
	}); err != nil {
		return nil, err
	}

	saleCount := 0
	saleCash, err := salesSvc.CreateSale(company.CompanyID, mainStoreID, adminResp.UserID, &models.CreateSaleRequest{
		CustomerID:      intPtr(customers[0]),
		PaymentMethodID: intPtr(paymentMethodIDs["Cash"]),
		PaidAmount:      52.5,
		Items: []models.CreateSaleDetailRequest{
			{ProductID: intPtr(products["std_01"].ProductID), BarcodeID: intPtr(products["std_01"].BarcodeID), Quantity: 5, UnitPrice: 10, TaxID: intPtr(vat.TaxID)},
		},
	}, nil)
	if err != nil {
		return nil, err
	}
	saleCount++

	if _, err := posSvc.ProcessCheckout(company.CompanyID, mainStoreID, adminResp.UserID, &models.POSCheckoutRequest{
		CustomerID: intPtr(customers[1]),
		PaidAmount: 42,
		Items: []models.CreateSaleDetailRequest{
			{ProductID: intPtr(products["var_01"].ProductID), BarcodeID: intPtr(products["var_01"].BarcodeID), Quantity: 3, UnitPrice: 12, TaxID: intPtr(vat.TaxID)},
		},
		Payments: []models.POSPaymentLine{
			{MethodID: paymentMethodIDs["Cash"], Amount: 20},
			{MethodID: paymentMethodIDs["Card"], Amount: 22},
		},
	}, "pos-split-1"); err != nil {
		return nil, err
	}
	saleCount++

	saleCredit, err := salesSvc.CreateSale(company.CompanyID, mainStoreID, adminResp.UserID, &models.CreateSaleRequest{
		CustomerID:      intPtr(customers[2]),
		PaymentMethodID: intPtr(paymentMethodIDs["Cash"]),
		PaidAmount:      20,
		Items: []models.CreateSaleDetailRequest{
			{ProductID: intPtr(products["batch_01"].ProductID), BarcodeID: intPtr(products["batch_01"].BarcodeID), Quantity: 2, UnitPrice: 18, TaxID: intPtr(vat.TaxID), BatchAllocations: []models.InventoryBatchSelectionInput{{LotID: batchLotID, Quantity: 2}}},
		},
	}, nil)
	if err != nil {
		return nil, err
	}
	saleCount++

	if _, err := salesSvc.CreateQuote(company.CompanyID, mainStoreID, adminResp.UserID, &models.CreateQuoteRequest{
		CustomerID: intPtr(customers[3]),
		Items: []models.CreateQuoteItemRequest{
			{ProductID: intPtr(products["std_02"].ProductID), Quantity: 2, UnitPrice: 14, TaxID: intPtr(vat.TaxID)},
		},
	}); err != nil {
		return nil, err
	}

	reasonSaleReturn := "Customer exchange"
	if _, err := returnsSvc.CreateSaleReturn(company.CompanyID, adminResp.UserID, &models.CreateSaleReturnRequest{
		SaleID: saleCash.SaleID,
		Reason: &reasonSaleReturn,
		Items:  []models.CreateSaleReturnItemRequest{{ProductID: products["std_01"].ProductID, BarcodeID: intPtr(products["std_01"].BarcodeID), Quantity: 1, UnitPrice: 10}},
	}); err != nil {
		return nil, err
	}

	receivedDate := time.Now().Format("2006-01-02")
	if _, err := collectionSvc.CreateCollection(company.CompanyID, mainStoreID, adminResp.UserID, &models.CreateCollectionRequest{
		CustomerID:      customers[2],
		Amount:          20,
		PaymentMethodID: intPtr(paymentMethodIDs["Bank Transfer"]),
		ReceivedDate:    &receivedDate,
		Invoices:        []models.CollectionInvoiceRequest{{SaleID: saleCredit.SaleID, Amount: 20}},
	}, "collection-1"); err != nil {
		return nil, err
	}

	expenseCategoryID, err := expenseSvc.CreateCategory(company.CompanyID, adminResp.UserID, "Utilities")
	if err != nil {
		return nil, err
	}
	expenseDate := time.Now().Format("2006-01-02")
	if _, err := expenseSvc.CreateExpense(company.CompanyID, hqID, adminResp.UserID, &models.CreateExpenseRequest{
		CategoryID:     expenseCategoryID,
		Amount:         75,
		ExpenseDateRaw: &expenseDate,
	}, "expense-1"); err != nil {
		return nil, err
	}

	workflowReason := "Manager review seeded for release checklist"
	if _, err := workflowSvc.CreateRequest(company.CompanyID, adminResp.UserID, &models.CreateWorkflowRequest{
		LocationID:     intPtr(mainStoreID),
		Module:         "inventory",
		EntityType:     "PRODUCT",
		EntityID:       intPtr(products["std_01"].ProductID),
		ActionType:     "PRICE_REVIEW",
		Title:          "Review seeded product pricing",
		RequestReason:  &workflowReason,
		ApproverRoleID: roleIDs["Manager"],
		Priority:       "HIGH",
	}); err != nil {
		return nil, err
	}

	if err := seedEmployees(employeeSvc, payrollSvc, company.CompanyID, hqID, adminResp.UserID); err != nil {
		return nil, err
	}

	return &datasetSummary{
		CompanyID: company.CompanyID,
		LocationIDs: map[string]int{
			"HQ":              hqID,
			"Main Store":      mainStoreID,
			"Secondary Store": secondaryStoreID,
		},
		Usernames:       createdUsers,
		CustomerCount:   len(customers),
		SupplierCount:   len(suppliers),
		ProductCount:    len(products),
		PurchaseCount:   purchaseCount,
		SaleCount:       saleCount,
		ExpenseCount:    1,
		WorkflowCount:   1,
		CollectionCount: 1,
	}, nil
}

func seedPaymentMethods(settingsSvc *services.SettingsService, companyID int) (map[string]int, error) {
	methods := map[string]struct {
		name string
		typ  string
	}{
		"Cash":          {"Cash", "CASH"},
		"Card":          {"Card", "CARD"},
		"Bank Transfer": {"Bank Transfer", "BANK"},
		"Wallet":        {"Wallet", "DIGITAL"},
		"Cheque":        {"Cheque", "BANK"},
	}
	result := make(map[string]int, len(methods))
	for key, item := range methods {
		existing, err := findPaymentMethodID(settingsSvc, companyID, item.name)
		if err == nil {
			result[key] = existing
			continue
		}
		pm, createErr := settingsSvc.CreatePaymentMethod(companyID, &models.PaymentMethodRequest{
			Name:     item.name,
			Type:     item.typ,
			IsActive: true,
		})
		if createErr != nil {
			return nil, createErr
		}
		result[key] = pm.MethodID
	}
	return result, nil
}

func findPaymentMethodID(settingsSvc *services.SettingsService, companyID int, name string) (int, error) {
	methods, err := settingsSvc.GetPaymentMethods(companyID)
	if err != nil {
		return 0, err
	}
	for _, method := range methods {
		if strings.EqualFold(method.Name, name) {
			return method.MethodID, nil
		}
	}
	return 0, fmt.Errorf("payment method %s not found", name)
}

func seedCustomers(customerSvc *services.CustomerService, companyID, userID, tierID int) ([]int, error) {
	ids := make([]int, 0, 6)
	for i := 1; i <= 6; i++ {
		name := fmt.Sprintf("Customer %02d", i)
		phone := fmt.Sprintf("+96891000%03d", i)
		email := fmt.Sprintf("customer%02d@example.com", i)
		customer, err := customerSvc.CreateCustomer(companyID, userID, &models.CreateCustomerRequest{
			Name:          name,
			Phone:         &phone,
			Email:         &email,
			CreditLimit:   500,
			PaymentTerms:  30,
			IsLoyalty:     true,
			LoyaltyTierID: &tierID,
		})
		if err != nil {
			return nil, err
		}
		ids = append(ids, customer.CustomerID)
	}
	return ids, nil
}

func seedSuppliers(supplierSvc *services.SupplierService, companyID, userID int) ([]int, error) {
	ids := make([]int, 0, 4)
	for i := 1; i <= 4; i++ {
		name := fmt.Sprintf("Supplier %02d", i)
		contact := fmt.Sprintf("Contact %02d", i)
		phone := fmt.Sprintf("+96892000%03d", i)
		email := fmt.Sprintf("supplier%02d@example.com", i)
		supplier, err := supplierSvc.CreateSupplier(companyID, userID, &models.CreateSupplierRequest{
			Name:          name,
			ContactPerson: &contact,
			Phone:         &phone,
			Email:         &email,
			PaymentTerms:  intPtr(30),
			CreditLimit:   floatPtr(1000),
			IsMercantile:  boolPtr(true),
		})
		if err != nil {
			return nil, err
		}
		ids = append(ids, supplier.SupplierID)
	}
	return ids, nil
}

func seedProducts(db *sql.DB, productSvc *services.ProductService, companyID, userID int, suppliers []int, taxNoneID, vatID int) (map[string]productSeed, error) {
	piecesID, err := lookupUnitID(db, "Pieces")
	if err != nil {
		return nil, err
	}
	categoryNames := []string{"Beverages", "Electronics", "Snacks"}
	categoryIDs := make([]int, 0, len(categoryNames))
	for _, name := range categoryNames {
		category, err := productSvc.CreateCategory(companyID, userID, &models.CreateCategoryRequest{Name: name})
		if err != nil {
			return nil, err
		}
		categoryIDs = append(categoryIDs, category.CategoryID)
	}
	brandNames := []string{"North Star", "Harbor", "Summit"}
	brandIDs := make([]int, 0, len(brandNames))
	for _, name := range brandNames {
		brand, err := productSvc.CreateBrand(companyID, userID, &models.CreateBrandRequest{Name: name})
		if err != nil {
			return nil, err
		}
		brandIDs = append(brandIDs, brand.BrandID)
	}

	defs := []struct {
		key         string
		name        string
		sku         string
		barcode     string
		categoryID  int
		brandID     int
		supplierID  int
		taxID       int
		tracking    string
		serialized  bool
		selling     float64
		cost        float64
		variantCode string
	}{
		{"std_01", "Demo Cola 330ml", "STD-01", "200000000001", categoryIDs[0], brandIDs[0], suppliers[0], vatID, "VARIANT", false, 10, 8, ""},
		{"std_02", "Demo Juice 1L", "STD-02", "200000000002", categoryIDs[0], brandIDs[1], suppliers[0], vatID, "VARIANT", false, 14, 11, ""},
		{"batch_01", "Protein Bar Batch", "BAT-01", "200000000003", categoryIDs[2], brandIDs[2], suppliers[1], vatID, "BATCH", false, 18, 12, ""},
		{"ser_01", "Smartphone Serial", "SER-01", "200000000004", categoryIDs[1], brandIDs[1], suppliers[2], vatID, "SERIAL", true, 220, 150, ""},
		{"var_01", "T-Shirt Variant", "VAR-01", "200000000005", categoryIDs[2], brandIDs[0], suppliers[3], taxNoneID, "VARIANT", false, 12, 10, "Blue"},
	}

	results := make(map[string]productSeed, len(defs))
	for _, item := range defs {
		selling := item.selling
		cost := item.cost
		barcodeReq := models.ProductBarcode{
			Barcode:      item.barcode,
			PackSize:     1,
			CostPrice:    &cost,
			SellingPrice: &selling,
			IsPrimary:    true,
			IsActive:     true,
		}
		if item.variantCode != "" {
			barcodeReq.VariantName = &item.variantCode
		}
		product, err := productSvc.CreateProduct(companyID, userID, &models.CreateProductRequest{
			CategoryID:        &item.categoryID,
			BrandID:           &item.brandID,
			UnitID:            &piecesID,
			TaxID:             item.taxID,
			Name:              item.name,
			SKU:               &item.sku,
			Barcodes:          []models.ProductBarcode{barcodeReq},
			CostPrice:         &cost,
			SellingPrice:      &selling,
			TrackingType:      item.tracking,
			IsSerialized:      item.serialized,
			DefaultSupplierID: &item.supplierID,
		})
		if err != nil {
			return nil, err
		}
		barcodeID, lookupErr := lookupPrimaryBarcodeID(db, product.ProductID)
		if lookupErr != nil {
			return nil, lookupErr
		}
		results[item.key] = productSeed{
			ProductID: product.ProductID,
			BarcodeID: barcodeID,
			Name:      item.name,
			Tracking:  item.tracking,
			UnitPrice: item.selling,
			TaxID:     item.taxID,
		}
	}
	return results, nil
}

func seedEmployees(employeeSvc *services.EmployeeService, payrollSvc *services.PayrollService, companyID, locationID, userID int) error {
	baseSalary := 450.0
	hireDate := time.Now().AddDate(-1, 0, 0)
	employee, err := employeeSvc.CreateEmployee(companyID, userID, &models.CreateEmployeeRequest{
		LocationID: &locationID,
		Name:       "Nadia Operations",
		Salary:     &baseSalary,
		HireDate:   &hireDate,
	})
	if err != nil {
		return err
	}
	payroll, err := payrollSvc.CreatePayroll(companyID, &models.CreatePayrollRequest{
		EmployeeID:  employee.EmployeeID,
		Month:       time.Now().Format("2006-01"),
		BasicSalary: baseSalary,
		Allowances:  50,
		Deductions:  20,
	}, userID)
	if err != nil {
		return err
	}
	if err := payrollSvc.MarkPayrollPaid(payroll.PayrollID, companyID, userID); err != nil {
		return err
	}
	return nil
}

func createLocation(locationSvc *services.LocationService, companyID int, name, address string) (int, error) {
	location, err := locationSvc.CreateLocation(&models.CreateLocationRequest{
		CompanyID: companyID,
		Name:      name,
		Address:   &address,
	})
	if err != nil {
		return 0, err
	}
	return location.LocationID, nil
}

func renameDefaultLocation(db *sql.DB, companyID int, name, address string) (int, error) {
	var locationID int
	if err := db.QueryRow(`
		UPDATE locations
		SET name = $1, address = $2, updated_at = CURRENT_TIMESTAMP
		WHERE company_id = $3
		RETURNING location_id
	`, name, address, companyID).Scan(&locationID); err != nil {
		return 0, err
	}
	return locationID, nil
}

func collectRoleIDs(db *sql.DB) (map[string]int, error) {
	rows, err := db.Query(`SELECT name, role_id FROM roles`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := map[string]int{}
	for rows.Next() {
		var name string
		var roleID int
		if err := rows.Scan(&name, &roleID); err != nil {
			return nil, err
		}
		result[name] = roleID
	}
	return result, rows.Err()
}

func ensureViewerRole(db *sql.DB, roleSvc *services.RoleService) (int, error) {
	var roleID int
	err := db.QueryRow(`SELECT role_id FROM roles WHERE name = 'Viewer'`).Scan(&roleID)
	if err == nil {
		return roleID, nil
	}
	if err != sql.ErrNoRows {
		return 0, err
	}
	role, err := roleSvc.CreateRole(&models.CreateRoleRequest{
		Name:        "Viewer",
		Description: "Read-only demo viewer",
	})
	if err != nil {
		return 0, err
	}
	perms, err := roleSvc.GetPermissions()
	if err != nil {
		return 0, err
	}
	permissionIDs := make([]int, 0)
	for _, perm := range perms {
		if strings.HasPrefix(perm.Name, "VIEW_") {
			permissionIDs = append(permissionIDs, perm.PermissionID)
		}
	}
	if err := roleSvc.AssignPermissions(role.RoleID, &models.AssignPermissionsRequest{PermissionIDs: permissionIDs}); err != nil {
		return 0, err
	}
	return role.RoleID, nil
}

func lookupCurrencyID(db *sql.DB, code string) (int, error) {
	var id int
	err := db.QueryRow(`SELECT currency_id FROM currencies WHERE code = $1`, code).Scan(&id)
	return id, err
}

func lookupTaxID(db *sql.DB, companyID int, name string) (int, error) {
	var id int
	err := db.QueryRow(`SELECT tax_id FROM taxes WHERE company_id = $1 AND name = $2`, companyID, name).Scan(&id)
	return id, err
}

func lookupUnitID(db *sql.DB, name string) (int, error) {
	var id int
	err := db.QueryRow(`SELECT unit_id FROM units WHERE name = $1`, name).Scan(&id)
	return id, err
}

func lookupPrimaryBarcodeID(db *sql.DB, productID int) (int, error) {
	var id int
	err := db.QueryRow(`SELECT barcode_id FROM product_barcodes WHERE product_id = $1 AND is_primary = TRUE`, productID).Scan(&id)
	return id, err
}

func lookupLotID(db *sql.DB, barcodeID int, batchNumber string) (int, error) {
	var id int
	err := db.QueryRow(`
		SELECT lot_id
		FROM stock_lots
		WHERE barcode_id = $1 AND batch_number = $2
		ORDER BY lot_id DESC
		LIMIT 1
	`, barcodeID, batchNumber).Scan(&id)
	return id, err
}

func writeReport(path string, summary *datasetSummary) error {
	if summary == nil {
		return fmt.Errorf("summary is nil")
	}
	content := fmt.Sprintf(`# Demo Dataset Report

Generated at: %s

- Company ID: %d
- Locations: HQ=%d, Main Store=%d, Secondary Store=%d
- Users: %s
- Customers: %d
- Suppliers: %d
- Products: %d
- Purchases: %d
- Sales: %d
- Collections: %d
- Expenses: %d
- Workflow requests: %d

Shared demo credentials:

- Password for all seeded users: %s
`, time.Now().UTC().Format(time.RFC3339), summary.CompanyID, summary.LocationIDs["HQ"], summary.LocationIDs["Main Store"], summary.LocationIDs["Secondary Store"], strings.Join(summary.Usernames, ", "), summary.CustomerCount, summary.SupplierCount, summary.ProductCount, summary.PurchaseCount, summary.SaleCount, summary.CollectionCount, summary.ExpenseCount, summary.WorkflowCount, demoPassword)

	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(content), 0o644)
}

func intPtr(value int) *int {
	return &value
}

func floatPtr(value float64) *float64 {
	return &value
}

func boolPtr(value bool) *bool {
	return &value
}
