package services

import (
	"fmt"
	"strings"

	"erp-backend/internal/utils"
)

type OverrideRequiredError struct {
	Message             string
	RequiredPermissions []string
	ReasonRequired      bool
}

func (e *OverrideRequiredError) Error() string {
	if e == nil {
		return "override required"
	}
	if e.Message != "" {
		return e.Message
	}
	return "override required"
}

type OverrideContext struct {
	ApproverUserID int
	Permissions    map[string]struct{}
}

func ValidateOverrideToken(tokenString string, companyID int, requiredPermissions []string) (*OverrideContext, error) {
	tokenString = strings.TrimSpace(tokenString)
	if tokenString == "" {
		return nil, fmt.Errorf("override token is empty")
	}
	claims, err := utils.ValidateManagerOverrideToken(tokenString)
	if err != nil {
		return nil, err
	}
	if claims.CompanyID != companyID {
		return nil, fmt.Errorf("override token company mismatch")
	}

	perms := make(map[string]struct{}, len(claims.Permissions))
	for _, p := range claims.Permissions {
		p = strings.TrimSpace(p)
		if p != "" {
			perms[p] = struct{}{}
		}
	}

	for _, rp := range requiredPermissions {
		rp = strings.TrimSpace(rp)
		if rp == "" {
			continue
		}
		if _, ok := perms[rp]; !ok {
			return nil, fmt.Errorf("override token missing required permission")
		}
	}

	return &OverrideContext{ApproverUserID: claims.UserID, Permissions: perms}, nil
}
