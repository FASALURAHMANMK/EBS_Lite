package middleware

import (
	"fmt"
	"log"

	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Logger middleware logs HTTP requests
func Logger() gin.HandlerFunc {
	return gin.LoggerWithFormatter(func(param gin.LogFormatterParams) string {
		requestID := ""
		if param.Keys != nil {
			if value, ok := param.Keys["request_id"]; ok {
				if typed, ok := value.(string); ok {
					requestID = typed
				}
			}
		}
		if requestID == "" && param.Request != nil {
			requestID = param.Request.Header.Get("X-Request-ID")
		}

		return fmt.Sprintf("[%s] request_id=%s %s %s %s %d %s %s\n",
			param.TimeStamp.Format("2006-01-02 15:04:05"),
			requestID,
			param.ClientIP,
			param.Method,
			param.Path,
			param.StatusCode,
			param.Latency,
			param.ErrorMessage,
		)
	})
}

// Recovery middleware recovers from panics
func Recovery() gin.HandlerFunc {
	return gin.CustomRecovery(func(c *gin.Context, recovered interface{}) {
		requestID := c.GetString("request_id")
		if requestID == "" {
			requestID = c.GetHeader("X-Request-ID")
		}
		log.Printf("request_id=%s panic recovered: %v", requestID, recovered)
		utils.InternalServerErrorResponse(c, "Internal server error", nil)
	})
}

// RequestID middleware adds a unique request ID
func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		requestID := c.GetHeader("X-Request-ID")
		if requestID == "" {
			requestID = uuid.NewString()
		}

		c.Request.Header.Set("X-Request-ID", requestID)
		c.Header("X-Request-ID", requestID)
		c.Set("request_id", requestID)
		c.Next()
	}
}
