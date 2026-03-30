package handlers

import (
	"net/http/httptest"
	"testing"
	"time"

	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

func TestRequireSecurityStepUp(t *testing.T) {
	gin.SetMode(gin.TestMode)
	utils.InitializeJWT("12345678901234567890123456789012")

	t.Run("missing header is rejected", func(t *testing.T) {
		recorder := httptest.NewRecorder()
		ctx, _ := gin.CreateTestContext(recorder)
		ctx.Request = httptest.NewRequest("PUT", "/api/v1/settings/security-policy", nil)

		if ok := requireSecurityStepUp(ctx, 9); ok {
			t.Fatalf("expected missing step-up token to be rejected")
		}
		if recorder.Code != 403 {
			t.Fatalf("expected 403, got %d", recorder.Code)
		}
	})

	t.Run("valid token passes", func(t *testing.T) {
		token, err := utils.GenerateManagerOverrideToken(7, 9, []string{"MANAGE_SETTINGS"}, time.Minute)
		if err != nil {
			t.Fatalf("failed to create override token: %v", err)
		}

		recorder := httptest.NewRecorder()
		ctx, _ := gin.CreateTestContext(recorder)
		ctx.Request = httptest.NewRequest("PUT", "/api/v1/settings/security-policy", nil)
		ctx.Request.Header.Set("X-Step-Up-Token", token)

		if ok := requireSecurityStepUp(ctx, 9); !ok {
			t.Fatalf("expected valid token to pass")
		}
	})

	t.Run("wrong permission is rejected", func(t *testing.T) {
		token, err := utils.GenerateManagerOverrideToken(7, 9, []string{"VIEW_SETTINGS"}, time.Minute)
		if err != nil {
			t.Fatalf("failed to create override token: %v", err)
		}

		recorder := httptest.NewRecorder()
		ctx, _ := gin.CreateTestContext(recorder)
		ctx.Request = httptest.NewRequest("PUT", "/api/v1/settings/security-policy", nil)
		ctx.Request.Header.Set("X-Step-Up-Token", token)

		if ok := requireSecurityStepUp(ctx, 9); ok {
			t.Fatalf("expected token without MANAGE_SETTINGS to fail")
		}
		if recorder.Code != 401 {
			t.Fatalf("expected 401, got %d", recorder.Code)
		}
	})
}
