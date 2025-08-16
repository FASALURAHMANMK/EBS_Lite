package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"

	"erp-backend/internal/models"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"
)

// TestCreateSale_PaidAmountExceedsTotal ensures the handler returns a validation
// error when the paid amount is greater than the total amount.
func TestCreateSale_PaidAmountExceedsTotal(t *testing.T) {
	gin.SetMode(gin.TestMode)
	utils.InitializeValidator()

	handler := &SalesHandler{salesService: &services.SalesService{}}

	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)

	body := []byte(`{"items":[{"quantity":1,"unit_price":10}],"paid_amount":20}`)
	req, _ := http.NewRequest(http.MethodPost, "/sales", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	c.Request = req

	c.Set("company_id", 1)
	c.Set("location_id", 1)
	c.Set("user_id", 1)

	handler.CreateSale(c)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", w.Code)
	}

	var resp models.APIResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if resp.Message != "Validation failed" {
		t.Fatalf("unexpected message: %s", resp.Message)
	}

	data, ok := resp.Data.(map[string]interface{})
	if !ok {
		t.Fatalf("expected data map, got %T", resp.Data)
	}

	if v, ok := data["paid_amount"].(string); !ok || v != "cannot exceed total_amount" {
		t.Fatalf("unexpected validation error: %v", resp.Data)
	}
}
