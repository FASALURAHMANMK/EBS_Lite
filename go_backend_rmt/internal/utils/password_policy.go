package utils

import (
	"fmt"
	"strings"
	"unicode"
)

type PasswordPolicy struct {
	MinPasswordLength        int
	RequireUppercase         bool
	RequireLowercase         bool
	RequireNumber            bool
	RequireSpecial           bool
	SessionIdleTimeoutMins   int
	ElevatedAccessWindowMins int
}

func DefaultPasswordPolicy() PasswordPolicy {
	return PasswordPolicy{
		MinPasswordLength:        10,
		RequireUppercase:         true,
		RequireLowercase:         true,
		RequireNumber:            true,
		RequireSpecial:           true,
		SessionIdleTimeoutMins:   480,
		ElevatedAccessWindowMins: 5,
	}
}

func NormalizePasswordPolicy(policy PasswordPolicy) PasswordPolicy {
	defaults := DefaultPasswordPolicy()
	if policy.MinPasswordLength < 8 {
		policy.MinPasswordLength = defaults.MinPasswordLength
	}
	if policy.SessionIdleTimeoutMins <= 0 {
		policy.SessionIdleTimeoutMins = defaults.SessionIdleTimeoutMins
	}
	if policy.ElevatedAccessWindowMins <= 0 {
		policy.ElevatedAccessWindowMins = defaults.ElevatedAccessWindowMins
	}
	return policy
}

func ValidatePasswordPolicyConfig(policy PasswordPolicy) error {
	policy = NormalizePasswordPolicy(policy)
	if policy.MinPasswordLength < 8 || policy.MinPasswordLength > 128 {
		return fmt.Errorf("min_password_length must be between 8 and 128")
	}
	if policy.SessionIdleTimeoutMins < 5 || policy.SessionIdleTimeoutMins > 7*24*60 {
		return fmt.Errorf("session_idle_timeout_mins must be between 5 and 10080")
	}
	if policy.ElevatedAccessWindowMins < 1 || policy.ElevatedAccessWindowMins > 60 {
		return fmt.Errorf("elevated_access_window_mins must be between 1 and 60")
	}
	return nil
}

func ValidatePasswordAgainstPolicy(password string, policy PasswordPolicy) error {
	policy = NormalizePasswordPolicy(policy)
	password = strings.TrimSpace(password)
	if len(password) < policy.MinPasswordLength {
		return fmt.Errorf("password must be at least %d characters", policy.MinPasswordLength)
	}

	var hasUpper, hasLower, hasNumber, hasSpecial bool
	for _, r := range password {
		switch {
		case unicode.IsUpper(r):
			hasUpper = true
		case unicode.IsLower(r):
			hasLower = true
		case unicode.IsDigit(r):
			hasNumber = true
		case unicode.IsPunct(r) || unicode.IsSymbol(r):
			hasSpecial = true
		}
	}

	if policy.RequireUppercase && !hasUpper {
		return fmt.Errorf("password must include at least one uppercase letter")
	}
	if policy.RequireLowercase && !hasLower {
		return fmt.Errorf("password must include at least one lowercase letter")
	}
	if policy.RequireNumber && !hasNumber {
		return fmt.Errorf("password must include at least one number")
	}
	if policy.RequireSpecial && !hasSpecial {
		return fmt.Errorf("password must include at least one special character")
	}
	return nil
}
