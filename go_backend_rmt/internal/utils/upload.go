package utils

import "strings"

// IsRequestBodyTooLarge returns true when the given error represents an exceeded
// http.MaxBytesReader limit during multipart parsing.
func IsRequestBodyTooLarge(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "request body too large")
}
