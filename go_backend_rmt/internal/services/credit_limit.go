package services

import "fmt"

type CreditLimitExceededError struct {
	CreditLimit    float64
	CurrentBalance float64
	AttemptedDelta float64
}

func (e *CreditLimitExceededError) Error() string {
	if e == nil {
		return "credit limit exceeded"
	}
	return fmt.Sprintf("credit limit exceeded (limit %.2f, outstanding %.2f, new %.2f)", e.CreditLimit, e.CurrentBalance, e.AttemptedDelta)
}
