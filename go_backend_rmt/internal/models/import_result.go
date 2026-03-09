package models

// ImportRowError represents a non-fatal error for a specific spreadsheet row.
// Row is 1-based (Excel-style).
type ImportRowError struct {
	Row     int    `json:"row"`
	Column  string `json:"column,omitempty"`
	Message string `json:"message"`
}

// ImportResult is returned by bulk import endpoints.
// Count is kept for backwards compatibility with older clients that expect "count".
type ImportResult struct {
	Count   int              `json:"count"`
	Created int              `json:"created"`
	Updated int              `json:"updated,omitempty"`
	Skipped int              `json:"skipped,omitempty"`
	Errors  []ImportRowError `json:"errors,omitempty"`
}
