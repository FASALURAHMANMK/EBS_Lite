package utils

import "testing"

func TestValidatePasswordAgainstPolicy(t *testing.T) {
	policy := DefaultPasswordPolicy()

	if err := ValidatePasswordAgainstPolicy("ValidPass1!", policy); err != nil {
		t.Fatalf("expected password to pass policy, got %v", err)
	}

	tests := []struct {
		name     string
		password string
	}{
		{name: "too short", password: "Ab1!"},
		{name: "missing uppercase", password: "validpass1!"},
		{name: "missing lowercase", password: "VALIDPASS1!"},
		{name: "missing number", password: "ValidPass!!"},
		{name: "missing special", password: "ValidPass12"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if err := ValidatePasswordAgainstPolicy(tt.password, policy); err == nil {
				t.Fatalf("expected password %q to fail", tt.password)
			}
		})
	}
}
