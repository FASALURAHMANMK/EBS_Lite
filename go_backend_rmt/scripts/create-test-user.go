package main

import (
	"crypto/rand"
	"database/sql"
	"encoding/base64"
	"fmt"
	"log"
	"os"

	_ "github.com/lib/pq"
	"golang.org/x/crypto/argon2"
)

// Simple password hashing function matching our utils
func hashPassword(password string) (string, error) {
	// Generate salt
	salt := make([]byte, 16)
	_, err := rand.Read(salt)
	if err != nil {
		return "", err
	}

	// Hash password with Argon2
	hash := argon2.IDKey([]byte(password), salt, 3, 64*1024, 2, 32)

	// Encode to base64
	b64Salt := base64.RawStdEncoding.EncodeToString(salt)
	b64Hash := base64.RawStdEncoding.EncodeToString(hash)

	// Format as expected by our backend
	encodedHash := fmt.Sprintf("$argon2id$v=%d$m=%d,t=%d,p=%d$%s$%s",
		argon2.Version, 64*1024, 3, 2, b64Salt, b64Hash)

	return encodedHash, nil
}

func main() {
	fmt.Println("🛠️  ERP Backend - Test User Creator")
	fmt.Println("=====================================")
	fmt.Println()

	// Get database URL from environment or use default
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		databaseURL = "postgres://postgres:root@localhost:5432/ebs_db?sslmode=disable"
		fmt.Println("📝 Using default database URL")
	}

	// Connect to database
	fmt.Println("🔌 Connecting to database...")
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		log.Fatal("❌ Failed to connect to database:", err)
	}
	defer db.Close()

	// Test connection
	if err := db.Ping(); err != nil {
		log.Fatal("❌ Database connection failed:", err)
	}
	fmt.Println("✅ Database connection successful!")

	// Ensure we have required data
	fmt.Println("🏢 Setting up test company...")

	// Insert test company (if not exists)
	_, err = db.Exec(`
		INSERT INTO companies (name, logo, address, phone, email, is_active) 
		VALUES ('ACME Corporation', NULL, '123 Main Street', '555-0123', 'contact@acme.com', TRUE)
		ON CONFLICT DO NOTHING
	`)
	if err != nil {
		log.Fatal("❌ Failed to create test company:", err)
	}

	// Insert test location (if not exists)
	_, err = db.Exec(`
		INSERT INTO locations (company_id, name, address, is_active)
		VALUES (1, 'Main Office', '123 Main Street', TRUE)
		ON CONFLICT DO NOTHING
	`)
	if err != nil {
		log.Fatal("❌ Failed to create test location:", err)
	}

	// Hash the test password
	fmt.Println("🔐 Generating password hash...")
	hashedPassword, err := hashPassword("admin123")
	if err != nil {
		log.Fatal("❌ Failed to hash password:", err)
	}

	// Create test user
	fmt.Println("👤 Creating test user...")
	query := `
		INSERT INTO users (
			company_id, 
			location_id,
			role_id, 
			username, 
			email, 
			password_hash, 
			first_name, 
			last_name, 
			is_active
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		ON CONFLICT (email) DO UPDATE SET 
			password_hash = EXCLUDED.password_hash,
			updated_at = CURRENT_TIMESTAMP
		RETURNING user_id, username, email
	`

	var userID int
	var username, email string
	err = db.QueryRow(query,
		1,                // company_id
		1,                // location_id
		1,                // role_id (Admin role)
		"admin",          // username
		"admin@test.com", // email
		hashedPassword,   // password_hash
		"Test",           // first_name
		"Admin",          // last_name
		true,             // is_active
	).Scan(&userID, &username, &email)

	if err != nil {
		log.Fatal("❌ Failed to create user:", err)
	}

	// Create additional test user (Manager role)
	hashedPassword2, _ := hashPassword("manager123")
	var userID2 int
	err = db.QueryRow(`
		INSERT INTO users (
			company_id, location_id, role_id, username, email, password_hash, 
			first_name, last_name, is_active
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		ON CONFLICT (email) DO UPDATE SET 
			password_hash = EXCLUDED.password_hash,
			updated_at = CURRENT_TIMESTAMP
		RETURNING user_id
	`, 1, 1, 3, "manager", "manager@test.com", hashedPassword2, "Test", "Manager", true).Scan(&userID2)

	if err != nil {
		fmt.Printf("⚠️  Note: Could not create manager user (may already exist): %v\n", err)
	}

	fmt.Println()
	fmt.Println("🎉 Test users created successfully!")
	fmt.Println("==================================")
	fmt.Println()
	fmt.Printf("👨‍💼 Admin User:\n")
	fmt.Printf("   📧 Email: admin@test.com\n")
	fmt.Printf("   🔑 Password: admin123\n")
	fmt.Printf("   🆔 User ID: %d\n", userID)
	fmt.Printf("   🏢 Company: ACME Corporation\n")
	fmt.Printf("   🎭 Role: Admin (Full Access)\n")
	fmt.Println()
	fmt.Printf("👩‍💼 Manager User:\n")
	fmt.Printf("   📧 Email: manager@test.com\n")
	fmt.Printf("   🔑 Password: manager123\n")
	fmt.Printf("   🆔 User ID: %d\n", userID2)
	fmt.Printf("   🏢 Company: ACME Corporation\n")
	fmt.Printf("   🎭 Role: Manager\n")
	fmt.Println()
	fmt.Println("🚀 Ready to test! Try logging in with:")
	fmt.Println()
	fmt.Println("curl -X POST http://localhost:8080/api/v1/auth/login \\")
	fmt.Println("  -H \"Content-Type: application/json\" \\")
	fmt.Println("  -d \"{\\\"email\\\":\\\"admin@test.com\\\",\\\"password\\\":\\\"admin123\\\"}\"")
	fmt.Println()
	fmt.Println("💡 Tip: Use Postman for easier API testing!")
}
