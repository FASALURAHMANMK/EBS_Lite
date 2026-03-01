package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"erp-backend/internal/config"

	"github.com/alicebob/miniredis/v2"
	"github.com/gin-gonic/gin"
)

func TestRateLimiterBlocksAfterLimit(t *testing.T) {
	gin.SetMode(gin.TestMode)

	redisServer, err := miniredis.Run()
	if err != nil {
		t.Fatalf("failed to start miniredis: %v", err)
	}
	defer redisServer.Close()

	cfg := &config.Config{
		RedisURL:           "redis://" + redisServer.Addr(),
		RateLimitEnabled:   true,
		RateLimitRequests:  2,
		RateLimitWindow:    200 * time.Millisecond,
		RateLimitKeyBy:     "ip",
		RateLimitKeyPrefix: "rate_limit",
		RateLimitFailOpen:  false,
	}

	router := gin.New()
	router.Use(RateLimiter(cfg))
	router.GET("/ping", func(c *gin.Context) {
		c.String(http.StatusOK, "ok")
	})

	makeRequest := func() *httptest.ResponseRecorder {
		req := httptest.NewRequest(http.MethodGet, "/ping", nil)
		req.RemoteAddr = "1.2.3.4:1234"
		recorder := httptest.NewRecorder()
		router.ServeHTTP(recorder, req)
		return recorder
	}

	if resp := makeRequest(); resp.Code != http.StatusOK {
		t.Fatalf("expected 200 on first request, got %d", resp.Code)
	}
	if resp := makeRequest(); resp.Code != http.StatusOK {
		t.Fatalf("expected 200 on second request, got %d", resp.Code)
	}
	if resp := makeRequest(); resp.Code != http.StatusTooManyRequests {
		t.Fatalf("expected 429 on third request, got %d", resp.Code)
	}
}
