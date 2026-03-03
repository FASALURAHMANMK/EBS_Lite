package utils

import (
	"testing"
	"time"
)

func TestManagerOverrideToken_RoundTrip(t *testing.T) {
	InitializeJWT("test-secret")

	token, err := GenerateManagerOverrideToken(10, 20, []string{"DELETE_SALES"}, 2*time.Minute)
	if err != nil {
		t.Fatalf("GenerateManagerOverrideToken error: %v", err)
	}

	claims, err := ValidateManagerOverrideToken(token)
	if err != nil {
		t.Fatalf("ValidateManagerOverrideToken error: %v", err)
	}
	if claims.UserID != 10 || claims.CompanyID != 20 || claims.Type != "override" {
		t.Fatalf("unexpected claims: %#v", claims)
	}
	if len(claims.Permissions) != 1 || claims.Permissions[0] != "DELETE_SALES" {
		t.Fatalf("unexpected permissions: %#v", claims.Permissions)
	}
}
