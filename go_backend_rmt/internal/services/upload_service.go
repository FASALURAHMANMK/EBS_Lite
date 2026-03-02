package services

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"erp-backend/internal/config"

	"github.com/google/uuid"
)

var (
	ErrInvalidUploadType = errors.New("invalid upload type")
	ErrInvalidUploadExt  = errors.New("invalid upload extension")
	ErrUnsafeUploadPath  = errors.New("unsafe upload path")
)

type UploadAllowlist struct {
	AllowedContentTypes map[string]struct{}
	AllowedExtensions   map[string]struct{}
}

func AllowlistCompanyLogo() UploadAllowlist {
	return UploadAllowlist{
		AllowedContentTypes: map[string]struct{}{
			"image/png":  {},
			"image/jpeg": {},
			"image/webp": {},
		},
		AllowedExtensions: map[string]struct{}{
			".png":  {},
			".jpg":  {},
			".jpeg": {},
			".webp": {},
		},
	}
}

func AllowlistInvoiceOrReceipt() UploadAllowlist {
	return UploadAllowlist{
		AllowedContentTypes: map[string]struct{}{
			"application/pdf": {},
			"image/png":       {},
			"image/jpeg":      {},
			"image/webp":      {},
		},
		AllowedExtensions: map[string]struct{}{
			".pdf":  {},
			".png":  {},
			".jpg":  {},
			".jpeg": {},
			".webp": {},
		},
	}
}

// GetUploadPath returns the configured upload root directory.
func GetUploadPath() string {
	cfg := config.Load()
	return cfg.UploadPath
}

// SaveUploadedFile saves the provided file under basePath/subdir and returns the served path ("/uploads/...").
// It enforces the provided allowlist, stores with a random name (UUID), and never trusts client filenames.
func SaveUploadedFile(basePath, subdir string, fh *multipart.FileHeader, allow UploadAllowlist) (string, error) {
	if fh == nil {
		return "", fmt.Errorf("missing file header")
	}

	ext, err := validateExtension(fh.Filename, allow)
	if err != nil {
		return "", err
	}

	contentType, err := sniffContentType(fh)
	if err != nil {
		return "", err
	}
	if !isAllowedContentType(contentType, allow) {
		return "", fmt.Errorf("%w: %s", ErrInvalidUploadType, contentType)
	}

	normalizedExt := extensionForContentType(contentType)
	if normalizedExt == "" {
		normalizedExt = ext
	}
	if normalizedExt == "" {
		return "", fmt.Errorf("%w: missing extension", ErrInvalidUploadExt)
	}

	if err := os.MkdirAll(filepath.Join(basePath, subdir), 0o755); err != nil {
		return "", fmt.Errorf("failed to create upload directory: %w", err)
	}

	fname := uuid.NewString() + normalizedExt
	dst, err := safeJoinUnderBase(basePath, subdir, fname)
	if err != nil {
		return "", err
	}

	if err := saveMultipartFile(fh, dst); err != nil {
		return "", err
	}

	served := filepath.ToSlash(filepath.Join("/uploads", subdir, fname))
	return served, nil
}

func validateExtension(filename string, allow UploadAllowlist) (string, error) {
	ext := strings.ToLower(filepath.Ext(filename))
	if ext == "" {
		return "", fmt.Errorf("%w: missing file extension", ErrInvalidUploadExt)
	}
	if allow.AllowedExtensions != nil {
		if _, ok := allow.AllowedExtensions[ext]; !ok {
			return "", fmt.Errorf("%w: %s", ErrInvalidUploadExt, ext)
		}
	}
	return ext, nil
}

func isAllowedContentType(ct string, allow UploadAllowlist) bool {
	ct = strings.ToLower(strings.TrimSpace(ct))
	if ct == "" {
		return false
	}
	if allow.AllowedContentTypes == nil {
		return true
	}
	_, ok := allow.AllowedContentTypes[ct]
	return ok
}

func sniffContentType(fh *multipart.FileHeader) (string, error) {
	f, err := fh.Open()
	if err != nil {
		return "", fmt.Errorf("failed to open uploaded file: %w", err)
	}
	defer f.Close()

	head := make([]byte, 512)
	n, _ := io.ReadFull(f, head)
	if n < 0 {
		n = 0
	}
	head = head[:n]

	if ct := contentTypeFromMagic(head); ct != "" {
		return ct, nil
	}

	if len(head) == 0 {
		return "", fmt.Errorf("%w: empty file", ErrInvalidUploadType)
	}
	return http.DetectContentType(head), nil
}

func contentTypeFromMagic(head []byte) string {
	if len(head) >= 5 && bytes.Equal(head[:5], []byte("%PDF-")) {
		return "application/pdf"
	}
	if len(head) >= 8 && bytes.Equal(head[:8], []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}) {
		return "image/png"
	}
	if len(head) >= 3 && head[0] == 0xFF && head[1] == 0xD8 && head[2] == 0xFF {
		return "image/jpeg"
	}
	if len(head) >= 12 && bytes.Equal(head[:4], []byte("RIFF")) && bytes.Equal(head[8:12], []byte("WEBP")) {
		return "image/webp"
	}
	return ""
}

func extensionForContentType(ct string) string {
	switch strings.ToLower(strings.TrimSpace(ct)) {
	case "application/pdf":
		return ".pdf"
	case "image/png":
		return ".png"
	case "image/jpeg":
		return ".jpg"
	case "image/webp":
		return ".webp"
	default:
		return ""
	}
}

func safeJoinUnderBase(basePath, subdir, fname string) (string, error) {
	baseAbs, err := filepath.Abs(basePath)
	if err != nil {
		return "", fmt.Errorf("failed to resolve upload base: %w", err)
	}
	baseAbs = filepath.Clean(baseAbs)

	dst := filepath.Join(baseAbs, subdir, fname)
	dstAbs, err := filepath.Abs(dst)
	if err != nil {
		return "", fmt.Errorf("failed to resolve upload dest: %w", err)
	}
	dstAbs = filepath.Clean(dstAbs)

	prefix := baseAbs
	if !strings.HasSuffix(prefix, string(os.PathSeparator)) {
		prefix += string(os.PathSeparator)
	}
	if !strings.HasPrefix(dstAbs, prefix) && dstAbs != baseAbs {
		return "", fmt.Errorf("%w: %s", ErrUnsafeUploadPath, dstAbs)
	}
	return dstAbs, nil
}

// saveMultipartFile is a small wrapper because gin.Context.SaveUploadedFile isn't available here.
func saveMultipartFile(fh *multipart.FileHeader, dst string) error {
	src, err := fh.Open()
	if err != nil {
		return fmt.Errorf("failed to open uploaded file: %w", err)
	}
	defer src.Close()

	out, err := os.OpenFile(dst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err != nil {
		return fmt.Errorf("failed to create dest file: %w", err)
	}
	defer out.Close()

	if _, err := io.Copy(out, src); err != nil {
		return fmt.Errorf("failed to write file: %w", err)
	}
	return nil
}
