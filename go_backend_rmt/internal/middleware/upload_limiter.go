package middleware

import (
	"errors"
	"net/http"
	"strings"

	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

var ErrUploadTooLarge = errors.New("upload exceeds MAX_UPLOAD_SIZE")

// UploadSizeLimiter applies a request body size limit to multipart uploads.
// It is safe to register globally; it only activates for multipart/form-data requests.
func UploadSizeLimiter(maxBytes int64) gin.HandlerFunc {
	if maxBytes <= 0 {
		return func(c *gin.Context) { c.Next() }
	}

	return func(c *gin.Context) {
		ct := strings.ToLower(c.GetHeader("Content-Type"))
		if !strings.HasPrefix(ct, "multipart/form-data") {
			c.Next()
			return
		}

		// Fail fast when Content-Length is known.
		if c.Request != nil && c.Request.ContentLength > maxBytes {
			utils.ErrorResponse(c, http.StatusRequestEntityTooLarge, "Upload too large", ErrUploadTooLarge)
			c.Abort()
			return
		}

		if c.Request != nil && c.Request.Body != nil {
			c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBytes)
		}

		c.Next()
	}
}
