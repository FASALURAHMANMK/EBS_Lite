package utils

import (
	"crypto/tls"
	"fmt"
	"net/smtp"

	"erp-backend/internal/config"
)

// SendEmail sends an email using configured SMTP credentials with STARTTLS support.
func SendEmail(to, subject, body string) error {
	cfg := config.Load()
	if cfg.SMTPHost == "" {
		return fmt.Errorf("smtp host not configured")
	}

	addr := fmt.Sprintf("%s:%d", cfg.SMTPHost, cfg.SMTPPort)
	auth := smtp.PlainAuth("", cfg.SMTPUsername, cfg.SMTPPassword, cfg.SMTPHost)

	msg := []byte(fmt.Sprintf(
		"To: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=\"UTF-8\"\r\n\r\n%s",
		to, subject, body,
	))

	// Use STARTTLS for port 587 (submission). For port 465 (implicit TLS)
	// a separate dial-with-TLS path would be needed, but 587 is the default.
	if cfg.SMTPPort == 587 {
		tlsConf := &tls.Config{
			ServerName: cfg.SMTPHost,
		}
		conn, err := smtp.Dial(addr)
		if err != nil {
			return fmt.Errorf("failed to connect to smtp server: %w", err)
		}
		defer conn.Close()

		if err := conn.StartTLS(tlsConf); err != nil {
			return fmt.Errorf("failed to start tls: %w", err)
		}
		if err := conn.Auth(auth); err != nil {
			return fmt.Errorf("failed to authenticate: %w", err)
		}
		if err := conn.Mail(cfg.FromEmail); err != nil {
			return fmt.Errorf("failed to set sender: %w", err)
		}
		if err := conn.Rcpt(to); err != nil {
			return fmt.Errorf("failed to set recipient: %w", err)
		}
		w, err := conn.Data()
		if err != nil {
			return fmt.Errorf("failed to open data writer: %w", err)
		}
		if _, err := w.Write(msg); err != nil {
			return fmt.Errorf("failed to write message: %w", err)
		}
		if err := w.Close(); err != nil {
			return fmt.Errorf("failed to close data writer: %w", err)
		}
		return conn.Quit()
	}

	// Fallback for non-587 ports (e.g., 25). This uses the standard library's
	// smtp.SendMail which does NOT perform STARTTLS. Production should use 587.
	return smtp.SendMail(addr, auth, cfg.FromEmail, []string{to}, msg)
}

// CheckSMTPConnectivity verifies that the configured SMTP server is reachable
// and authentication succeeds. This is a lightweight check for the /ready endpoint.
func CheckSMTPConnectivity() error {
	cfg := config.Load()
	if cfg.SMTPHost == "" {
		// SMTP not configured -- not an error for readiness if password reset is not required.
		// Return a sentinel error so the readiness endpoint can report it.
		return fmt.Errorf("smtp not configured")
	}

	addr := fmt.Sprintf("%s:%d", cfg.SMTPHost, cfg.SMTPPort)
	conn, err := smtp.Dial(addr)
	if err != nil {
		return fmt.Errorf("smtp connection failed: %w", err)
	}
	defer conn.Close()

	if cfg.SMTPPort == 587 {
		if err := conn.StartTLS(&tls.Config{ServerName: cfg.SMTPHost}); err != nil {
			return fmt.Errorf("smtp starttls failed: %w", err)
		}
	}

	auth := smtp.PlainAuth("", cfg.SMTPUsername, cfg.SMTPPassword, cfg.SMTPHost)
	if err := conn.Auth(auth); err != nil {
		return fmt.Errorf("smtp auth failed: %w", err)
	}

	return conn.Quit()
}
