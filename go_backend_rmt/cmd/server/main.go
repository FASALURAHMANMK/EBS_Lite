package main

import (
	"context"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"erp-backend/internal/config"
	"erp-backend/internal/database"
	"erp-backend/internal/middleware"
	"erp-backend/internal/routes"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using system environment variables")
	}

	// Load configuration
	cfg := config.Load()

	// Capture recent logs for support bundles.
	logBuffer := utils.InitDefaultLogBuffer(cfg.SupportBundleLogLines)
	log.SetOutput(io.MultiWriter(os.Stdout, logBuffer))
	gin.DefaultWriter = io.MultiWriter(os.Stdout, logBuffer)
	gin.DefaultErrorWriter = io.MultiWriter(os.Stderr, logBuffer)

	// Initialize database
	if _, err := database.Initialize(cfg.DatabaseURL); err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer database.Close()

	if cfg.RunMigrations {
		if err := database.ApplyMigrations(database.GetDB(), cfg.MigrationsDir); err != nil {
			log.Fatal("Migrations failed:", err)
		}
	}

	if err := database.ValidateSchema(database.GetDB()); err != nil {
		log.Fatal("Schema validation failed:", err)
	}

	// Set Gin mode
	if cfg.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	if cfg.Environment == "production" && isWeakJWTSecret(cfg.JWTSecret) {
		log.Fatal("Refusing to start: JWT_SECRET is weak or default in production")
	}

	// Initialize Gin router
	router := gin.New()

	// Apply global middleware
	router.Use(middleware.RequestID())
	router.Use(middleware.Logger())
	router.Use(middleware.Recovery())
	router.Use(middleware.CORS(cfg))
	router.Use(middleware.RateLimiter(cfg))
	router.Use(middleware.UploadSizeLimiter(cfg.MaxUploadSize))

	// Initialize routes
	routes.Initialize(router, cfg)

	// Start server with graceful shutdown
	server := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           router,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	go func() {
		log.Printf("Server starting on port %s", cfg.Port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("Failed to start server:", err)
		}
	}()

	shutdownCtx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	<-shutdownCtx.Done()

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := server.Shutdown(ctx); err != nil {
		log.Printf("Graceful shutdown failed: %v", err)
	}
	log.Println("Server stopped")
}

func isWeakJWTSecret(secret string) bool {
	trimmed := strings.TrimSpace(secret)
	if trimmed == "" {
		return true
	}
	if trimmed == "your-super-secret-jwt-key-change-this-in-production" {
		return true
	}
	return len(trimmed) < 32
}
