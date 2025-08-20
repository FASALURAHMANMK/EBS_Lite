package middleware

import (
	"database/sql"
	"log"
	"net/http"

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

		// Set user context - handle NULL values
		c.Set("user_id", claims.UserID)
		if claims.CompanyID != nil {
			c.Set("company_id", *claims.CompanyID)
		} else {
			c.Set("company_id", 0) // Set 0 for NULL company
		}
		if claims.LocationID != nil {
			c.Set("location_id", *claims.LocationID)
		}
		if claims.RoleID != nil {
			c.Set("role_id", *claims.RoleID)
		}
               c.Set("user", user)

               // Update device session activity if session ID is present
               if claims.SessionID != "" {
                       c.Set("session_id", claims.SessionID)
                       db := database.GetDB()
                       ipAddr := c.ClientIP()
                       ua := c.GetHeader("User-Agent")
                       var ipVal interface{}
                       if ipAddr != "" {
                               ipVal = ipAddr
                       }
                       var uaVal interface{}
                       if ua != "" {
                               uaVal = ua
                       }
                       _, err := db.Exec(`UPDATE device_sessions SET last_seen = NOW(), ip_address = COALESCE($2, ip_address), user_agent = COALESCE($3, user_agent) WHERE session_id = $1`, claims.SessionID, ipVal, uaVal)
                       if err != nil {
                               log.Printf("Failed to update device session %s: %v", claims.SessionID, err)
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
		SELECT COUNT(*) 
		FROM users u
		JOIN role_permissions rp ON u.role_id = rp.role_id
		JOIN permissions p ON rp.permission_id = p.permission_id
		WHERE u.user_id = $1 AND p.name = $2 AND u.is_active = TRUE
	`

	var count int
	err := db.QueryRow(query, userID, permission).Scan(&count)
	return count > 0, err
}

func checkUserRole(roleID int, roleName string) (bool, error) {
	db := database.GetDB()

	query := `SELECT COUNT(*) FROM roles WHERE role_id = $1 AND name = $2`

	var count int
	err := db.QueryRow(query, roleID, roleName).Scan(&count)
	return count > 0, err
}
