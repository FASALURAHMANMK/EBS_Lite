package services

import (
    "fmt"
    "io"
    "mime/multipart"
    "os"
    "path/filepath"
    "strings"
    "time"

    "erp-backend/internal/config"
)

// GetUploadPath returns the configured upload root directory
func GetUploadPath() string {
    cfg := config.GetConfig()
    return cfg.UploadPath
}

// SaveUploadedFile saves the provided file under basePath/subdir and returns the served path ("/uploads/...")
func SaveUploadedFile(basePath, subdir string, fh *multipart.FileHeader) (string, error) {
    if err := os.MkdirAll(filepath.Join(basePath, subdir), 0o755); err != nil {
        return "", fmt.Errorf("failed to create upload directory: %w", err)
    }
    ext := filepath.Ext(fh.Filename)
    name := strings.TrimSuffix(filepath.Base(fh.Filename), ext)
    ts := time.Now().Unix()
    fname := fmt.Sprintf("%s_%d%s", name, ts, ext)
    dst := filepath.Join(basePath, subdir, fname)
    if err := saveMultipartFile(fh, dst); err != nil {
        return "", err
    }
    // Served URL path
    served := filepath.ToSlash(filepath.Join("/uploads", subdir, fname))
    return served, nil
}

// saveMultipartFile is a small wrapper because gin.Context.SaveUploadedFile isn't available here
func saveMultipartFile(fh *multipart.FileHeader, dst string) error {
    // Open source
    src, err := fh.Open()
    if err != nil {
        return fmt.Errorf("failed to open uploaded file: %w", err)
    }
    defer src.Close()
    // Create destination
    out, err := os.Create(dst)
    if err != nil {
        return fmt.Errorf("failed to create dest file: %w", err)
    }
    defer out.Close()
    if _, err := io.Copy(out, src); err != nil {
        return fmt.Errorf("failed to write file: %w", err)
    }
    return nil
}
