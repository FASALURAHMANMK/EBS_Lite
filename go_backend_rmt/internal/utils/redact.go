package utils

import "regexp"

var (
	kvSecretRe = regexp.MustCompile(`(?i)\b(JWT_SECRET|SMTP_PASSWORD|DATABASE_URL|REDIS_URL|ACCESS_TOKEN|REFRESH_TOKEN|PASSWORD)\s*=\s*([^\s]+)`)
	bearerRe   = regexp.MustCompile(`(?i)\bBearer\s+([A-Za-z0-9\-._~+/]+=*)`)
	postgresRe = regexp.MustCompile(`(?i)\b(postgres(?:ql)?://[^:\s/]+):[^@\s]+@`)
)

func RedactSecrets(s string) string {
	if s == "" {
		return s
	}
	s = kvSecretRe.ReplaceAllString(s, "$1=REDACTED")
	s = bearerRe.ReplaceAllString(s, "Bearer REDACTED")
	s = postgresRe.ReplaceAllString(s, "$1:REDACTED@")
	return s
}
