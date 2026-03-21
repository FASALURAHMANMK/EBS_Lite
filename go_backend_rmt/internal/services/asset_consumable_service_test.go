package services

import "testing"

func TestParseReportOrTxnDate(t *testing.T) {
	testCases := []string{
		"2026-03-21",
		"2026-03-21 13:55:22",
		"2026-03-21T13:55:22",
		"2026-03-21T13:55:22.123",
		"2026-03-21T13:55:22.123456",
		"2026-03-21T13:55:22.123456789",
		"2026-03-21T13:55:22Z",
		"2026-03-21T13:55:22+04:00",
	}

	for _, input := range testCases {
		if _, err := parseReportOrTxnDate(input); err != nil {
			t.Fatalf("expected %q to parse, got error: %v", input, err)
		}
	}
}

func TestStringArrayOrEmpty(t *testing.T) {
	if got := stringArrayOrEmpty(nil); got == nil || len(got) != 0 {
		t.Fatalf("expected empty non-nil slice for nil input, got %#v", got)
	}

	input := []string{"A1"}
	got := stringArrayOrEmpty(input)
	if len(got) != 1 || got[0] != "A1" {
		t.Fatalf("expected original values to be preserved, got %#v", got)
	}
}
