package models

type Location struct {
	LocationID int     `json:"location_id" db:"location_id"`
	CompanyID  int     `json:"company_id" db:"company_id" validate:"required"`
	Name       string  `json:"name" db:"name" validate:"required,min=2,max=255"`
	Address    *string `json:"address,omitempty" db:"address"`
	Phone      *string `json:"phone,omitempty" db:"phone"`
	IsActive   bool    `json:"is_active" db:"is_active"`
	BaseModel
}

type CreateLocationRequest struct {
	CompanyID int     `json:"company_id" validate:"required"`
	Name      string  `json:"name" validate:"required,min=2,max=255"`
	Address   *string `json:"address,omitempty"`
	Phone     *string `json:"phone,omitempty"`
}

type UpdateLocationRequest struct {
	Name     *string `json:"name,omitempty" validate:"omitempty,min=2,max=255"`
	Address  *string `json:"address,omitempty"`
	Phone    *string `json:"phone,omitempty"`
	IsActive *bool   `json:"is_active,omitempty"`
}
