package handlers

import (
	"database/sql"
	"fmt"
	"path/filepath"
	"strings"

	"erp-backend/internal/database"
	"erp-backend/internal/services"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

// UploadHandler serves uploaded files with authorization checks.
type UploadHandler struct{}

// NewUploadHandler creates a new upload file server handler.
func NewUploadHandler() *UploadHandler {
	return &UploadHandler{}
}

// ServeFile serves an uploaded file after verifying the requester is authenticated
// and the file belongs to their company. The path pattern is /uploads/:subdir/:filename.
func (h *UploadHandler) ServeFile(c *gin.Context) {
	userID := c.GetInt("user_id")
	companyID := c.GetInt("company_id")
	if userID == 0 || companyID == 0 {
		utils.UnauthorizedResponse(c, "Authentication required")
		return
	}

	subdir := c.Param("subdir")
	filename := c.Param("filename")
	if subdir == "" || filename == "" {
		utils.NotFoundResponse(c, "File not found")
		return
	}

	// Only allow known subdirectories
	switch subdir {
	case "invoices", "returns", "logos":
	default:
		utils.ForbiddenResponse(c, "Access denied")
		return
	}

	// Verify the file path is safe (no traversal)
	cleanName := filepath.Base(filename)
	if cleanName != filename || strings.Contains(subdir, "..") {
		utils.NotFoundResponse(c, "File not found")
		return
	}

	// Verify the file belongs to the user's company
	if !h.fileBelongsToCompany(companyID, subdir, cleanName) {
		utils.ForbiddenResponse(c, "Access denied")
		return
	}

	// Serve the file
	uploadPath := services.GetUploadPath()
	physicalPath := filepath.Join(uploadPath, subdir, cleanName)
	c.File(physicalPath)
}

// fileBelongsToCompany checks whether a file stored under subdir/filename
// is associated with the given company_id via the owning database row.
func (h *UploadHandler) fileBelongsToCompany(companyID int, subdir, filename string) bool {
	db := database.GetDB()
	relativePath := filepath.ToSlash(filepath.Join("/uploads", subdir, filename))

	var exists bool
	var err error

	switch subdir {
	case "invoices":
		// purchases.invoice_file -> suppliers.company_id
		err = db.QueryRow(`
			SELECT EXISTS(
				SELECT 1 FROM purchases p
				JOIN suppliers s ON p.supplier_id = s.supplier_id
				WHERE s.company_id = $1 AND p.invoice_file = $2 AND p.is_deleted = FALSE
			)
		`, companyID, relativePath).Scan(&exists)
	case "returns":
		// purchase_returns.receipt_file -> purchases -> suppliers.company_id
		err = db.QueryRow(`
			SELECT EXISTS(
				SELECT 1 FROM purchase_returns pr
				JOIN purchases p ON pr.purchase_id = p.purchase_id
				JOIN suppliers s ON p.supplier_id = s.supplier_id
				WHERE s.company_id = $1 AND pr.receipt_file = $2 AND pr.is_deleted = FALSE
			)
		`, companyID, relativePath).Scan(&exists)
	case "logos":
		// companies.logo
		err = db.QueryRow(`
			SELECT EXISTS(
				SELECT 1 FROM companies WHERE company_id = $1 AND logo = $2
			)
		`, companyID, relativePath).Scan(&exists)
	default:
		return false
	}

	if err != nil {
		if err == sql.ErrNoRows {
			return false
		}
		// Log but don't expose DB errors
		fmt.Printf("upload_handler: failed to verify file ownership for %s: %v\n", relativePath, err)
		return false
	}

	return exists
}
