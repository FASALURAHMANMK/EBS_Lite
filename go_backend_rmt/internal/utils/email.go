package utils

import (
	"fmt"
	"net/smtp"

	"erp-backend/internal/config"
)

// SendEmail sends an email using configured SMTP credentials
func SendEmail(to, subject, body string) error {
	cfg := config.Load()
	if cfg.SMTPHost == "" {
		return fmt.Errorf("smtp host not configured")
	}

	addr := fmt.Sprintf("%s:%d", cfg.SMTPHost, cfg.SMTPPort)
	auth := smtp.PlainAuth("", cfg.SMTPUsername, cfg.SMTPPassword, cfg.SMTPHost)

	msg := []byte(fmt.Sprintf("To: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=\"UTF-8\"\r\n\r\n%s", to, subject, body))

	return smtp.SendMail(addr, auth, cfg.FromEmail, []string{to}, msg)
}
