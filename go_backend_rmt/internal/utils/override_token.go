package utils

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// ManagerOverrideClaims is a short-lived token used to authorize a single
// high-risk action (discount override, void, etc.) without switching the active
// cashier session.
//
// It is intentionally separate from access/refresh tokens and must be validated
// explicitly by the endpoint that consumes it.
type ManagerOverrideClaims struct {
	Type        string   `json:"type"` // "override"
	UserID      int      `json:"user_id"`
	CompanyID   int      `json:"company_id"`
	Permissions []string `json:"permissions"`
	jwt.RegisteredClaims
}

func GenerateManagerOverrideToken(userID, companyID int, permissions []string, expiry time.Duration) (string, error) {
	if userID == 0 || companyID == 0 {
		return "", errors.New("invalid override subject")
	}
	if len(jwtSecret) == 0 {
		return "", errors.New("jwt secret not initialized")
	}
	claims := &ManagerOverrideClaims{
		Type:        "override",
		UserID:      userID,
		CompanyID:   companyID,
		Permissions: permissions,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(expiry)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(jwtSecret)
}

func ValidateManagerOverrideToken(tokenString string) (*ManagerOverrideClaims, error) {
	if len(jwtSecret) == 0 {
		return nil, errors.New("jwt secret not initialized")
	}
	token, err := jwt.ParseWithClaims(tokenString, &ManagerOverrideClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("invalid signing method")
		}
		return jwtSecret, nil
	})
	if err != nil {
		return nil, err
	}
	claims, ok := token.Claims.(*ManagerOverrideClaims)
	if !ok || !token.Valid {
		return nil, errors.New("invalid override token")
	}
	if claims.Type != "override" {
		return nil, errors.New("invalid override token type")
	}
	if claims.UserID == 0 || claims.CompanyID == 0 {
		return nil, errors.New("invalid override token subject")
	}
	return claims, nil
}
