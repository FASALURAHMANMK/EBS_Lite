package middleware

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

func RequireAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			utils.UnauthorizedResponse(c, "Authorization header required")
			c.Abort()
			return
		}

		tokenString := utils.ExtractTokenFromHeader(authHeader)
		if tokenString == "" {
			utils.UnauthorizedResponse(c, "Invalid authorization header format")
			c.Abort()
			return
		}

		claims, err := utils.ValidateToken(tokenString)
		if err != nil {
			utils.UnauthorizedResponse(c, "Invalid or expired token")
			c.Abort()
			return
		}

		if claims.Type != "access" {
			utils.UnauthorizedResponse(c, "Invalid token type")
			c.Abort()
			return
		}

		user, err := getUserByID(claims.UserID)
		if err != nil {
			utils.UnauthorizedResponse(c, "User not found")
			c.Abort()
			return
		}

		if !user.IsActive || user.IsLocked {
			utils.UnauthorizedResponse(c, "User account is inactive or locked")
			c.Abort()
			return
		}

		if claims.SessionID != "" {
			if err := validateSessionState(claims.SessionID, user.UserID, user.CompanyID); err != nil {
				utils.UnauthorizedResponse(c, err.Error())
				c.Abort()
				return
			}
		}

		// Set user context from DB (authoritative; avoids stale JWT role/company/location IDs)
		c.Set("user_id", user.UserID)
		if user.CompanyID != nil {
			c.Set("company_id", *user.CompanyID)
		} else {
			c.Set("company_id", 0)
		}
		if user.LocationID != nil {
			c.Set("location_id", *user.LocationID)
		}
		if user.RoleID != nil {
			c.Set("role_id", *user.RoleID)
		}
		c.Set("user", user)

		// Update device session activity if session ID is present (throttled)
		if claims.SessionID != "" {
			c.Set("session_id", claims.SessionID)
			limiter := getSessionLastSeenLimiter()
			shouldUpdate := true
			if limiter != nil {
				allowed, err := limiter.Allow(c.Request.Context(), claims.SessionID)
				if err != nil {
					log.Printf("Failed to evaluate session last_seen throttle for %s: %v", claims.SessionID, err)
					shouldUpdate = false
				} else {
					shouldUpdate = allowed
				}
			}
			if shouldUpdate {
				db := database.GetDB()
				sessionID := claims.SessionID
				ipAddr := c.ClientIP()
				ua := c.GetHeader("User-Agent")
				go func(sessionID, ipAddr, ua string) {
					var ipVal interface{}
					if ipAddr != "" {
						ipVal = ipAddr
					}
					var uaVal interface{}
					if ua != "" {
						uaVal = ua
					}
					_, err := db.Exec(`UPDATE device_sessions SET last_seen = NOW(), ip_address = COALESCE($2, ip_address), user_agent = COALESCE($3, user_agent) WHERE session_id = $1`, sessionID, ipVal, uaVal)
					if err != nil {
						log.Printf("Failed to update device session %s: %v", sessionID, err)
					}
				}(sessionID, ipAddr, ua)
			}
		} else {
			log.Println("No session ID in JWT claims")
		}

		c.Next()
	}
}

// RequirePermission middleware checks if user has specific permission
func RequirePermission(permission string) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetInt("user_id")
		if userID == 0 {
			utils.UnauthorizedResponse(c, "Authentication required")
			c.Abort()
			return
		}

		hasPermission, err := checkUserPermission(userID, permission)
		if err != nil {
			utils.InternalServerErrorResponse(c, "Failed to check permissions", err)
			c.Abort()
			return
		}

		if !hasPermission {
			utils.ForbiddenResponse(c, "Insufficient permissions")
			c.Abort()
			return
		}

		c.Next()
	}
}

// RequireRole middleware checks if user has specific role
func RequireRole(roleName string) gin.HandlerFunc {
	return func(c *gin.Context) {
		roleID := c.GetInt("role_id")
		if roleID == 0 {
			utils.ForbiddenResponse(c, "Role required")
			c.Abort()
			return
		}

		hasRole, err := checkUserRole(roleID, roleName)
		if err != nil {
			utils.InternalServerErrorResponse(c, "Failed to check role", err)
			c.Abort()
			return
		}

		if !hasRole {
			utils.ForbiddenResponse(c, "Insufficient role permissions")
			c.Abort()
			return
		}

		c.Next()
	}
}

// RequireAnyRole middleware checks if user has any of the specified roles.
func RequireAnyRole(roleNames ...string) gin.HandlerFunc {
	return func(c *gin.Context) {
		roleID := c.GetInt("role_id")
		if roleID == 0 {
			utils.ForbiddenResponse(c, "Role required")
			c.Abort()
			return
		}
		if len(roleNames) == 0 {
			utils.InternalServerErrorResponse(c, "No roles configured", nil)
			c.Abort()
			return
		}

		roleName, err := getRoleNameByID(roleID)
		if err != nil {
			utils.InternalServerErrorResponse(c, "Failed to check role", err)
			c.Abort()
			return
		}

		for _, allowed := range roleNames {
			if strings.EqualFold(roleName, allowed) {
				c.Next()
				return
			}
		}

		utils.ForbiddenResponse(c, "Insufficient role permissions")
		c.Abort()
	}
}

// RequireCompanyAccess middleware ensures user can only access their company data
// func RequireCompanyAccess() gin.HandlerFunc {
// 	return func(c *gin.Context) {
// 		userCompanyID := c.GetInt("company_id")
// 		if userCompanyID == 0 {
// 			utils.UnauthorizedResponse(c, "Company context required")
// 			c.Abort()
// 			return
// 		}

// 		// Set company filter for queries
// 		c.Set("company_filter", userCompanyID)
// 		c.Next()
// 	}
// }

func RequireCompanyAccess() gin.HandlerFunc {
	return func(c *gin.Context) {
		userCompanyID := c.GetInt("company_id")
		if userCompanyID == 0 {
			utils.ErrorResponse(c, http.StatusForbidden, "Please create your company first", nil)
			c.Abort()
			return
		}

		c.Set("company_filter", userCompanyID)
		c.Next()
	}
}

// RequireLocationAccess middleware ensures user can only access their location data
func RequireLocationAccess() gin.HandlerFunc {
	return func(c *gin.Context) {
		userLocationID := c.GetInt("location_id")
		if userLocationID == 0 {
			utils.ForbiddenResponse(c, "Location access required")
			c.Abort()
			return
		}

		// Set location filter for queries
		c.Set("location_filter", userLocationID)
		c.Next()
	}
}

// Helper functions
func getUserByID(userID int) (*models.User, error) {
	db := database.GetDB()

	query := `
		SELECT user_id, company_id, location_id, role_id, username, email, 
			   first_name, last_name, phone, preferred_language, secondary_language,
			   max_allowed_devices, is_locked, is_active, last_login, sync_status,
			   created_at, updated_at, is_deleted
		FROM users 
		WHERE user_id = $1 AND is_deleted = FALSE
	`

	var user models.User
	err := db.QueryRow(query, userID).Scan(
		&user.UserID, &user.CompanyID, &user.LocationID, &user.RoleID,
		&user.Username, &user.Email, &user.FirstName, &user.LastName,
		&user.Phone, &user.PreferredLanguage, &user.SecondaryLanguage,
		&user.MaxAllowedDevices, &user.IsLocked, &user.IsActive,
		&user.LastLogin, &user.SyncStatus, &user.CreatedAt,
		&user.UpdatedAt, &user.IsDeleted,
	)

	if err == sql.ErrNoRows {
		return nil, err
	}

	return &user, err
}

func checkUserPermission(userID int, permission string) (bool, error) {
	db := database.GetDB()

	query := `
		SELECT (
			EXISTS (
				SELECT 1
				FROM users u
				JOIN roles r ON u.role_id = r.role_id
				WHERE u.user_id = $1
					AND u.is_active = TRUE
					AND u.is_deleted = FALSE
					AND LOWER(r.name) IN ('super admin', 'admin')
			)
			OR EXISTS (
				SELECT 1
				FROM users u
				JOIN role_permissions rp ON u.role_id = rp.role_id
				JOIN permissions p ON rp.permission_id = p.permission_id
				WHERE u.user_id = $1
					AND u.is_active = TRUE
					AND u.is_deleted = FALSE
					AND p.name = $2
			)
		) AS has_permission
	`

	var has bool
	err := db.QueryRow(query, userID, permission).Scan(&has)
	return has, err
}

func checkUserRole(roleID int, roleName string) (bool, error) {
	db := database.GetDB()

	query := `SELECT COUNT(*) FROM roles WHERE role_id = $1 AND LOWER(name) = LOWER($2)`

	var count int
	err := db.QueryRow(query, roleID, roleName).Scan(&count)
	return count > 0, err
}

func getRoleNameByID(roleID int) (string, error) {
	db := database.GetDB()
	var name string
	err := db.QueryRow(`SELECT name FROM roles WHERE role_id = $1`, roleID).Scan(&name)
	return name, err
}

func validateSessionState(sessionID string, userID int, companyID *int) error {
	db := database.GetDB()

	var isActive bool
	var lastSeen time.Time
	err := db.QueryRow(`
		SELECT is_active, COALESCE(last_seen, created_at)
		FROM device_sessions
		WHERE session_id = $1 AND user_id = $2
	`, sessionID, userID).Scan(&isActive, &lastSeen)
	if err == sql.ErrNoRows {
		return fmt.Errorf("session not found")
	}
	if err != nil {
		return fmt.Errorf("failed to validate session")
	}
	if !isActive {
		return fmt.Errorf("session is inactive")
	}

	idleTimeout := time.Duration(utils.DefaultPasswordPolicy().SessionIdleTimeoutMins) * time.Minute
	if companyID != nil && *companyID > 0 {
		idleTimeout = resolveCompanySessionIdleTimeout(db, *companyID)
	}
	if idleTimeout > 0 && time.Since(lastSeen.UTC()) > idleTimeout {
		_, _ = db.Exec(`UPDATE device_sessions SET is_active = FALSE WHERE session_id = $1`, sessionID)
		return fmt.Errorf("session expired due to inactivity")
	}
	return nil
}

func resolveCompanySessionIdleTimeout(db *sql.DB, companyID int) time.Duration {
	defaultTimeout := time.Duration(utils.DefaultPasswordPolicy().SessionIdleTimeoutMins) * time.Minute
	if db == nil || companyID == 0 {
		return defaultTimeout
	}

	var value models.JSONB
	err := db.QueryRow(`SELECT value FROM settings WHERE company_id = $1 AND key = 'security_policy'`, companyID).Scan(&value)
	if err != nil {
		return defaultTimeout
	}

	raw, err := json.Marshal(value)
	if err != nil {
		return defaultTimeout
	}

	var policy models.SecurityPolicySettings
	if err := json.Unmarshal(raw, &policy); err != nil {
		return defaultTimeout
	}
	normalized := utils.NormalizePasswordPolicy(utils.PasswordPolicy{
		SessionIdleTimeoutMins: policy.SessionIdleTimeoutMins,
	})
	return time.Duration(normalized.SessionIdleTimeoutMins) * time.Minute
}
