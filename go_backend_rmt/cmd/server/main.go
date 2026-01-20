package main

import (
	"log"
	"os"

	"erp-backend/internal/config"
	"erp-backend/internal/database"
	"erp-backend/internal/middleware"
	"erp-backend/internal/routes"

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

	// Initialize database
	if _, err := database.Initialize(cfg.DatabaseURL); err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer database.Close()
	if err := database.ValidateSchema(database.GetDB()); err != nil {
		log.Fatal("Schema validation failed:", err)
	}

	// Set Gin mode
	if cfg.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	// Initialize Gin router
	router := gin.New()

	// Apply global middleware
	router.Use(middleware.Logger())
	router.Use(middleware.Recovery())
	router.Use(middleware.CORS(cfg))

	// Initialize routes
	routes.Initialize(router, cfg)

	// Start server
	port := os.Getenv("S_PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port %s", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}
