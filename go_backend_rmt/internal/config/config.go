package config

import (
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	// Database
	DatabaseURL string

	// JWT
	JWTSecret        string
	JWTExpiry        time.Duration
	JWTRefreshExpiry time.Duration

	// Server
	Port        string
	Environment string

	// CORS
	AllowedOrigins []string
	AllowedMethods []string
	AllowedHeaders []string

	// Rate Limiting
	RateLimitEnabled   bool
	RateLimitRequests  int
	RateLimitWindow    time.Duration
	RateLimitKeyBy     string
	RateLimitKeyPrefix string
	RateLimitFailOpen  bool

	// MQTT
	MQTTBroker   string
	MQTTClientID string
	MQTTUsername string
	MQTTPassword string

	// Redis
	RedisURL string

	// Session activity
	SessionLastSeenThrottle time.Duration
	SessionLastSeenUseRedis bool

	// File Upload
	MaxUploadSize int64
	UploadPath    string

	// Migrations
	RunMigrations bool
	MigrationsDir string

	// Operational / support
	SupportBundleEnabled  bool
	SupportBundleLogLines int
	ReadyCheckRedis       bool
	ReadyCheckTimeout     time.Duration

	// Email
	SMTPHost        string
	SMTPPort        int
	SMTPUsername    string
	SMTPPassword    string
	FromEmail       string
	FrontendBaseURL string

	// Printing
	DefaultPrinter string
	TemplatePath   string
}

func Load() *Config {
	return &Config{
		// Database
		DatabaseURL: getEnv("DATABASE_URL", "postgres://localhost:5432/ebs_db?sslmode=disable"),

		// JWT
		JWTSecret:        getEnv("JWT_SECRET", "your-super-secret-jwt-key-change-this-in-production"),
		JWTExpiry:        parseDuration("JWT_EXPIRY", "24h"),
		JWTRefreshExpiry: parseDuration("JWT_REFRESH_EXPIRY", "168h"),

		// Server
		Port:        getEnv("PORT", "8080"),
		Environment: getEnv("ENVIRONMENT", "development"),

		// CORS
		AllowedOrigins: parseCSV("ALLOWED_ORIGINS", "http://localhost:3000"),
		AllowedMethods: []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders: []string{"Content-Type", "Authorization", "Accept", "company_id", "location_id"},

		// Rate Limiting
		RateLimitEnabled:   parseBool("RATE_LIMIT_ENABLED", true),
		RateLimitRequests:  parseInt("RATE_LIMIT_REQUESTS", 100),
		RateLimitWindow:    parseDuration("RATE_LIMIT_WINDOW", "1h"),
		RateLimitKeyBy:     getEnv("RATE_LIMIT_KEY_BY", "ip"),
		RateLimitKeyPrefix: getEnv("RATE_LIMIT_KEY_PREFIX", "rate_limit"),
		RateLimitFailOpen:  parseBool("RATE_LIMIT_FAIL_OPEN", true),

		// MQTT
		MQTTBroker:   getEnv("MQTT_BROKER", "tcp://localhost:1883"),
		MQTTClientID: getEnv("MQTT_CLIENT_ID", "erp-backend"),
		MQTTUsername: getEnv("MQTT_USERNAME", ""),
		MQTTPassword: getEnv("MQTT_PASSWORD", ""),

		// Redis
		RedisURL: getEnv("REDIS_URL", "redis://localhost:6379"),

		// Session activity
		SessionLastSeenThrottle: parseDuration("SESSION_LAST_SEEN_THROTTLE", "60s"),
		SessionLastSeenUseRedis: parseBool("SESSION_LAST_SEEN_USE_REDIS", true),

		// File Upload
		MaxUploadSize: parseSize("MAX_UPLOAD_SIZE", "10MB"),
		UploadPath:    getEnv("UPLOAD_PATH", "./uploads"),

		// Migrations
		RunMigrations: parseBool("RUN_MIGRATIONS", true),
		MigrationsDir: getEnv("MIGRATIONS_DIR", "migrations"),

		// Operational / support
		SupportBundleEnabled:  parseBool("SUPPORT_BUNDLE_ENABLED", false),
		SupportBundleLogLines: parseInt("SUPPORT_BUNDLE_LOG_LINES", 200),
		ReadyCheckRedis:       parseBool("READY_CHECK_REDIS", true),
		ReadyCheckTimeout:     parseDuration("READY_CHECK_TIMEOUT", "2s"),

		// Email
		SMTPHost:        getEnv("SMTP_HOST", ""),
		SMTPPort:        parseInt("SMTP_PORT", 587),
		SMTPUsername:    getEnv("SMTP_USERNAME", ""),
		SMTPPassword:    getEnv("SMTP_PASSWORD", ""),
		FromEmail:       getEnv("FROM_EMAIL", "noreply@company.com"),
		FrontendBaseURL: getEnv("FRONTEND_BASE_URL", "http://localhost:3000"),

		// Printing
		DefaultPrinter: getEnv("DEFAULT_PRINTER", "default"),
		TemplatePath:   getEnv("TEMPLATE_PATH", "./templates"),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func parseInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if parsed, err := strconv.Atoi(value); err == nil {
			return parsed
		}
	}
	return defaultValue
}

func parseBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		if parsed, err := strconv.ParseBool(value); err == nil {
			return parsed
		}
	}
	return defaultValue
}

func parseDuration(key, defaultValue string) time.Duration {
	if value := os.Getenv(key); value != "" {
		if parsed, err := time.ParseDuration(value); err == nil {
			return parsed
		}
	}
	parsed, _ := time.ParseDuration(defaultValue)
	return parsed
}

func parseSize(key, defaultValue string) int64 {
	value := getEnv(key, defaultValue)
	// Simple size parsing (MB)
	if len(value) > 2 && value[len(value)-2:] == "MB" {
		if size, err := strconv.Atoi(value[:len(value)-2]); err == nil {
			return int64(size) * 1024 * 1024
		}
	}
	return 10 * 1024 * 1024 // 10MB default
}

func parseCSV(key, defaultValue string) []string {
	value := getEnv(key, defaultValue)
	parts := strings.Split(value, ",")
	result := make([]string, 0, len(parts))
	for _, p := range parts {
		if trimmed := strings.TrimSpace(p); trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}
