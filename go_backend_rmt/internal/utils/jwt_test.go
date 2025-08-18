package utils

import (
	"strconv"
	"testing"
	"time"

	"erp-backend/internal/models"
)

func TestGenerateAccessToken_SubjectIsNumeric(t *testing.T) {
	InitializeJWT("test-secret")
	user := &models.User{UserID: 123, Email: "user@example.com"}
	token, err := GenerateAccessToken(user, "sess", time.Minute)
	if err != nil {
		t.Fatalf("GenerateAccessToken returned error: %v", err)
	}
	claims, err := ValidateToken(token)
	if err != nil {
		t.Fatalf("ValidateToken returned error: %v", err)
	}
	expected := strconv.Itoa(user.UserID)
	if claims.Subject != expected {
		t.Fatalf("expected subject %s, got %s", expected, claims.Subject)
	}
}

func TestGenerateRefreshToken_SubjectIsNumeric(t *testing.T) {
	InitializeJWT("test-secret")
	user := &models.User{UserID: 456, Email: "user@example.com"}
	token, err := GenerateRefreshToken(user, "sess", time.Minute)
	if err != nil {
		t.Fatalf("GenerateRefreshToken returned error: %v", err)
	}
	claims, err := ValidateToken(token)
	if err != nil {
		t.Fatalf("ValidateToken returned error: %v", err)
	}
	expected := strconv.Itoa(user.UserID)
	if claims.Subject != expected {
		t.Fatalf("expected subject %s, got %s", expected, claims.Subject)
	}
}
