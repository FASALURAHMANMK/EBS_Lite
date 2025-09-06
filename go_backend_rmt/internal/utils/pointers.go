package utils

// EmptyToNil returns nil if the input string is empty, otherwise returns a pointer to the string.
func EmptyToNil(s string) *string {
    if s == "" {
        return nil
    }
    return &s
}

