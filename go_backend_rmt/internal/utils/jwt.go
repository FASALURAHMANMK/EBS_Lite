package utils

import (
	"errors"
	"strconv"
	"time"

	"erp-backend/internal/models"

	"github.com/golang-jwt/jwt/v5"
)

type Claims struct {
	models.JWTClaims
	jwt.RegisteredClaims
}

var jwtSecret []byte

// InitializeJWT sets the JWT secret
func InitializeJWT(secret string) {
	jwtSecret = []byte(secret)
}

// GenerateAccessToken creates a new access token
func GenerateAccessToken(user *models.User, sessionID string, expiry time.Duration) (string, error) {
	claims := &Claims{
		JWTClaims: models.JWTClaims{
			SessionID:  sessionID,
			UserID:     user.UserID,
			CompanyID:  user.CompanyID,
			LocationID: user.LocationID,
			RoleID:     user.RoleID,
			Email:      user.Email,
			Type:       "access",
		},
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(expiry)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Subject:   strconv.Itoa(user.UserID),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(jwtSecret)
}

// GenerateRefreshToken creates a new refresh token
func GenerateRefreshToken(user *models.User, sessionID string, expiry time.Duration) (string, error) {
	claims := &Claims{
		JWTClaims: models.JWTClaims{
			SessionID:  sessionID,
			UserID:     user.UserID,
			CompanyID:  user.CompanyID,
			LocationID: user.LocationID,
			RoleID:     user.RoleID,
			Email:      user.Email,
			Type:       "refresh",
		},
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(expiry)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Subject:   strconv.Itoa(user.UserID),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(jwtSecret)
}

// ValidateToken validates and parses a JWT token
func ValidateToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("invalid signing method")
		}
		return jwtSecret, nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}

	return nil, errors.New("invalid token")
}

// ExtractTokenFromHeader extracts JWT token from Authorization header
func ExtractTokenFromHeader(authHeader string) string {
	if len(authHeader) > 7 && authHeader[:7] == "Bearer " {
		return authHeader[7:]
	}
	return ""
}
