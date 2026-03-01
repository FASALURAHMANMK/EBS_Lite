package services

import "testing"

func TestBuildResetLink(t *testing.T) {
	tests := []struct {
		name     string
		baseURL  string
		token    string
		expected string
	}{
		{
			name:     "base without path",
			baseURL:  "https://example.com",
			token:    "abc123",
			expected: "https://example.com/reset-password?token=abc123",
		},
		{
			name:     "base with trailing slash",
			baseURL:  "https://example.com/",
			token:    "abc123",
			expected: "https://example.com/reset-password?token=abc123",
		},
		{
			name:     "base with path",
			baseURL:  "https://example.com/app",
			token:    "abc123",
			expected: "https://example.com/app/reset-password?token=abc123",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			link, err := buildResetLink(tt.baseURL, tt.token)
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if link != tt.expected {
				t.Fatalf("expected %q, got %q", tt.expected, link)
			}
		})
	}
}
