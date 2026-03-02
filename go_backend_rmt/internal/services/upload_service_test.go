package services

import (
	"bytes"
	"fmt"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/textproto"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

func fileHeaderFromMultipart(t *testing.T, filename string, contentType string, content []byte) *multipart.FileHeader {
	t.Helper()

	body := &bytes.Buffer{}
	w := multipart.NewWriter(body)

	h := make(textproto.MIMEHeader)
	h.Set("Content-Disposition", fmt.Sprintf(`form-data; name="file"; filename="%s"`, filename))
	if contentType != "" {
		h.Set("Content-Type", contentType)
	}
	part, err := w.CreatePart(h)
	if err != nil {
		t.Fatalf("CreatePart: %v", err)
	}
	if _, err := part.Write(content); err != nil {
		t.Fatalf("Write: %v", err)
	}
	if err := w.Close(); err != nil {
		t.Fatalf("Close: %v", err)
	}

	req := httptest.NewRequest(http.MethodPost, "/upload", bytes.NewReader(body.Bytes()))
	req.Header.Set("Content-Type", w.FormDataContentType())
	if err := req.ParseMultipartForm(10 << 20); err != nil {
		t.Fatalf("ParseMultipartForm: %v", err)
	}
	fhs := req.MultipartForm.File["file"]
	if len(fhs) != 1 {
		t.Fatalf("expected 1 file header, got %d", len(fhs))
	}
	return fhs[0]
}

func TestSaveUploadedFileCompanyLogoAllowsPngAndRandomizesName(t *testing.T) {
	tmp := t.TempDir()

	png := append(
		[]byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A},
		bytes.Repeat([]byte{0x00}, 64)...,
	)

	fh := fileHeaderFromMultipart(t, "logo.png", "image/png", png)
	served, err := SaveUploadedFile(tmp, "logos", fh, AllowlistCompanyLogo())
	if err != nil {
		t.Fatalf("SaveUploadedFile: %v", err)
	}

	if !strings.HasPrefix(served, "/uploads/logos/") {
		t.Fatalf("unexpected served path: %s", served)
	}
	if !strings.HasSuffix(served, ".png") {
		t.Fatalf("expected .png served path, got: %s", served)
	}

	base := filepath.Base(served)
	if strings.Contains(base, "logo") {
		t.Fatalf("expected randomized filename, got: %s", base)
	}
	if ok, _ := regexp.MatchString(`^[0-9a-fA-F-]{36}\.png$`, base); !ok {
		t.Fatalf("expected uuid filename, got: %s", base)
	}

	dst := filepath.Join(tmp, "logos", base)
	if _, err := os.Stat(dst); err != nil {
		t.Fatalf("expected file saved at %s: %v", dst, err)
	}
}

func TestSaveUploadedFileRejectsBadExtension(t *testing.T) {
	tmp := t.TempDir()

	png := append(
		[]byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A},
		bytes.Repeat([]byte{0x00}, 8)...,
	)
	fh := fileHeaderFromMultipart(t, "logo.exe", "image/png", png)

	_, err := SaveUploadedFile(tmp, "logos", fh, AllowlistCompanyLogo())
	if err == nil || !strings.Contains(err.Error(), ErrInvalidUploadExt.Error()) {
		t.Fatalf("expected ErrInvalidUploadExt, got: %v", err)
	}
}

func TestSaveUploadedFileRejectsBadContentType(t *testing.T) {
	tmp := t.TempDir()

	pdf := append([]byte("%PDF-"), bytes.Repeat([]byte("x"), 64)...)
	fh := fileHeaderFromMultipart(t, "logo.png", "image/png", pdf)

	_, err := SaveUploadedFile(tmp, "logos", fh, AllowlistCompanyLogo())
	if err == nil || !strings.Contains(err.Error(), ErrInvalidUploadType.Error()) {
		t.Fatalf("expected ErrInvalidUploadType, got: %v", err)
	}
}
