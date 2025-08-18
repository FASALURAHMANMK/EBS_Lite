package utils

import (
	"reflect"
	"strings"

	"github.com/go-playground/validator/v10"
)

var validate *validator.Validate

// InitializeValidator sets up the validator
func InitializeValidator() {
	validate = validator.New()

	// Use JSON tag name instead of struct field name
	validate.RegisterTagNameFunc(func(fld reflect.StructField) string {
		name := strings.SplitN(fld.Tag.Get("json"), ",", 2)[0]
		if name == "-" {
			return ""
		}
		return name
	})
}

// ValidateStruct validates a struct
func ValidateStruct(s interface{}) error {
	return validate.Struct(s)
}

// GetValidationErrors returns formatted validation errors
func GetValidationErrors(err error) map[string]string {
	errors := make(map[string]string)

	if validationErrors, ok := err.(validator.ValidationErrors); ok {
		for _, fieldError := range validationErrors {
			field := strings.ToLower(fieldError.Field())
			switch fieldError.Tag() {
			case "required":
				errors[field] = field + " is required"
			case "email":
				errors[field] = field + " must be a valid email address"
			case "min":
				errors[field] = field + " must be at least " + fieldError.Param() + " characters long"
			case "max":
				errors[field] = field + " must be no more than " + fieldError.Param() + " characters long"
			default:
				errors[field] = field + " is invalid"
			}
		}
	}

	return errors
}
