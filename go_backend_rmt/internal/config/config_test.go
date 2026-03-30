package config

import "testing"

func TestProductionReadinessIssues(t *testing.T) {
	cfg := &Config{
		Environment:             "production",
		JWTSecret:               "change_me_in_production",
		AllowedOrigins:          []string{"http://localhost:3000", "*"},
		FrontendBaseURL:         "http://localhost:3000",
		RateLimitEnabled:        true,
		RateLimitFailOpen:       true,
		SessionLastSeenUseRedis: true,
	}

	issues := cfg.ProductionReadinessIssues()
	if len(issues) < 4 {
		t.Fatalf("expected multiple production issues, got %v", issues)
	}
}

func TestValidateProductionReadiness_SucceedsForStrictConfig(t *testing.T) {
	cfg := &Config{
		Environment:             "production",
		JWTSecret:               "12345678901234567890123456789012",
		AllowedOrigins:          []string{"https://app.example.com"},
		FrontendBaseURL:         "https://app.example.com",
		RateLimitEnabled:        true,
		RateLimitFailOpen:       false,
		RedisURL:                "redis://cache.example.com:6379",
		SessionLastSeenUseRedis: true,
		ReadyCheckRedis:         true,
	}

	if err := cfg.ValidateProductionReadiness(); err != nil {
		t.Fatalf("expected config to pass validation, got %v", err)
	}
}
