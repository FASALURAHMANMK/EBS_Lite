# API Documentation

## GET /health

### Headers
- None

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/auth/login

### Headers
- Content-Type: application/json

### Request Body
**LoginRequest**
  - Username           string
  - Email              string
  - Password           string
  - DeviceID           string
  - DeviceName         *string
  - IncludePreferences bool

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (LoginResponse)
    - access_token (string)
    - refresh_token (string)
    - session_id (string)
    - user (UserResponse)
    - company,omitempty (*Company)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/auth/register

### Headers
- Content-Type: application/json

### Request Body
**RegisterRequest**
  - Username          string
  - Email             string
  - Password          string
  - FirstName         *string
  - LastName          *string
  - Phone             *string
  - PreferredLanguage *string
  - SecondaryLanguage *string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (RegisterResponse)
    - user_id (int)
    - username (string)
    - email (string)
    - message (string)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/auth/forgot-password

### Headers
- Content-Type: application/json

### Request Body
**ForgotPasswordRequest**
  - Email string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/auth/reset-password

### Headers
- Content-Type: application/json

### Request Body
**ResetPasswordRequest**
  - Token       string
  - NewPassword string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/auth/refresh-token

### Headers
- Content-Type: application/json

### Request Body
**RefreshTokenRequest**
  - RefreshToken string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
 - data (RefreshTokenResponse)
    - access_token (string)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/languages

### Headers
- None

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
 - data ([]Language)
    - language_code (string)
    - language_name (string)
    - is_active (bool)
    - created_at (time.Time)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/auth/me

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/auth/logout

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/device-sessions

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (DeviceSession)
    - session_id (string)
    - user_id (int)
    - device_id (string)
    - device_name,omitempty (*string)
    - ip_address,omitempty (*string)
    - user_agent,omitempty (*string)
    - last_seen (time.Time)
    - last_sync_time,omitempty (*time.Time)
    - is_active (bool)
    - is_stale (bool)
    - created_at (time.Time)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/device-sessions/:session_id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (DeviceSession)
    - session_id (string)
    - user_id (int)
    - device_id (string)
    - device_name,omitempty (*string)
    - ip_address,omitempty (*string)
    - user_agent,omitempty (*string)
    - last_seen (time.Time)
    - last_sync_time,omitempty (*time.Time)
    - is_active (bool)
    - is_stale (bool)
    - created_at (time.Time)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/dashboard/metrics

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/dashboard/quick-actions

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/users

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (User)
    - user_id (int)
    - company_id,omitempty (*int)
    - location_id,omitempty (*int)
    - role_id,omitempty (*int)
    - username (string)
    - email (string)
    - first_name,omitempty (*string)
    - last_name,omitempty (*string)
    - phone,omitempty (*string)
    - preferred_language,omitempty (*string)
    - secondary_language,omitempty (*string)
    - max_allowed_devices (int)
    - is_locked (bool)
    - is_active (bool)
    - last_login,omitempty (*time.Time)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/users

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateUserRequest**
  - Username          string
  - Email             string
  - Password          string
  - FirstName         *string
  - LastName          *string
  - Phone             *string
  - RoleID            *int
  - LocationID        *int
  - CompanyID         int
  - PreferredLanguage *string
  - SecondaryLanguage *string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (User)
    - user_id (int)
    - company_id,omitempty (*int)
    - location_id,omitempty (*int)
    - role_id,omitempty (*int)
    - username (string)
    - email (string)
    - first_name,omitempty (*string)
    - last_name,omitempty (*string)
    - phone,omitempty (*string)
    - preferred_language,omitempty (*string)
    - secondary_language,omitempty (*string)
    - max_allowed_devices (int)
    - is_locked (bool)
    - is_active (bool)
    - last_login,omitempty (*time.Time)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/users/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateUserRequest**
  - FirstName         *string
  - LastName          *string
  - Phone             *string
  - IsActive          *bool
  - IsLocked          *bool
  - RoleID            *int
  - LocationID        *int
  - PreferredLanguage *string
  - SecondaryLanguage *string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (User)
    - user_id (int)
    - company_id,omitempty (*int)
    - location_id,omitempty (*int)
    - role_id,omitempty (*int)
    - username (string)
    - email (string)
    - first_name,omitempty (*string)
    - last_name,omitempty (*string)
    - phone,omitempty (*string)
    - preferred_language,omitempty (*string)
    - secondary_language,omitempty (*string)
    - max_allowed_devices (int)
    - is_locked (bool)
    - is_active (bool)
    - last_login,omitempty (*time.Time)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/users/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (User)
    - user_id (int)
    - company_id,omitempty (*int)
    - location_id,omitempty (*int)
    - role_id,omitempty (*int)
    - username (string)
    - email (string)
    - first_name,omitempty (*string)
    - last_name,omitempty (*string)
    - phone,omitempty (*string)
    - preferred_language,omitempty (*string)
    - secondary_language,omitempty (*string)
    - max_allowed_devices (int)
    - is_locked (bool)
    - is_active (bool)
    - last_login,omitempty (*time.Time)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/companies

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/companies

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateCompanyRequest**
  - Name       string
  - Logo       *string
  - Address    *string
  - Phone      *string
  - Email      *string
  - TaxNumber  *string
  - CurrencyID *int

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/companies/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateCompanyRequest**
  - Name       *string
  - Logo       *string
  - Address    *string
  - Phone      *string
  - Email      *string
  - TaxNumber  *string
  - CurrencyID *int
  - IsActive   *bool

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/companies/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)
## GET /api/v1/locations

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Location)
    - location_id (int)
    - company_id (int)
    - name (string)
    - address,omitempty (*string)
    - phone,omitempty (*string)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/locations

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateLocationRequest**
  - CompanyID int
  - Name      string
  - Address   *string
  - Phone     *string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Location)
    - location_id (int)
    - company_id (int)
    - name (string)
    - address,omitempty (*string)
    - phone,omitempty (*string)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/locations/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateLocationRequest**
  - Name     *string
  - Address  *string
  - Phone    *string
  - IsActive *bool

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Location)
    - location_id (int)
    - company_id (int)
    - name (string)
    - address,omitempty (*string)
    - phone,omitempty (*string)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/locations/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Location)
    - location_id (int)
    - company_id (int)
    - name (string)
    - address,omitempty (*string)
    - phone,omitempty (*string)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/roles

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Role)
    - role_id (int)
    - name (string)
    - description (string)
    - is_system_role (bool)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/roles

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateRoleRequest**
  - Name        string
  - Description string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Role)
    - role_id (int)
    - name (string)
    - description (string)
    - is_system_role (bool)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/roles/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateRoleRequest**
  - Name        *string
  - Description *string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Role)
    - role_id (int)
    - name (string)
    - description (string)
    - is_system_role (bool)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/roles/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Role)
    - role_id (int)
    - name (string)
    - description (string)
    - is_system_role (bool)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/roles/:id/permissions

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Permission)
    - permission_id (int)
    - name (string)
    - description (string)
    - module (string)
    - action (string)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/roles/:id/permissions

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**AssignPermissionsRequest**
  - PermissionIDs []int

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Permission)
    - permission_id (int)
    - name (string)
    - description (string)
    - module (string)
    - action (string)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/permissions

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data ([]Permission)
    - permission_id (int)
    - name (string)
    - description (string)
    - module (string)
    - action (string)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/products

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Product)
    - product_id (int)
    - company_id (int)
    - category_id,omitempty (*int)
    - brand_id,omitempty (*int)
    - unit_id,omitempty (*int)
    - name (string)
    - sku,omitempty (*string)
    - barcodes,omitempty ([]ProductBarcode)
    - description,omitempty (*string)
    - cost_price,omitempty (*float64)
    - selling_price,omitempty (*float64)
    - reorder_level (int)
    - weight,omitempty (*float64)
    - dimensions,omitempty (*string)
    - is_serialized (bool)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
    - attributes,omitempty ([]ProductAttributeValue)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/products/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Product)
    - product_id (int)
    - company_id (int)
    - category_id,omitempty (*int)
    - brand_id,omitempty (*int)
    - unit_id,omitempty (*int)
    - name (string)
    - sku,omitempty (*string)
    - barcodes,omitempty ([]ProductBarcode)
    - description,omitempty (*string)
    - cost_price,omitempty (*float64)
    - selling_price,omitempty (*float64)
    - reorder_level (int)
    - weight,omitempty (*float64)
    - dimensions,omitempty (*string)
    - is_serialized (bool)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
    - attributes,omitempty ([]ProductAttributeValue)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/products/:id/summary

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/products

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateProductRequest**
  - CategoryID   *int
  - BrandID      *int
  - UnitID       *int
  - Name         string
  - SKU          *string
  - Barcodes     []ProductBarcode
  - Description  *string
  - CostPrice    *float64
  - SellingPrice *float64
  - ReorderLevel int
  - Weight       *float64
  - Dimensions   *string
  - IsSerialized bool
  - Attributes   map[int]string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Product)
    - product_id (int)
    - company_id (int)
    - category_id,omitempty (*int)
    - brand_id,omitempty (*int)
    - unit_id,omitempty (*int)
    - name (string)
    - sku,omitempty (*string)
    - barcodes,omitempty ([]ProductBarcode)
    - description,omitempty (*string)
    - cost_price,omitempty (*float64)
    - selling_price,omitempty (*float64)
    - reorder_level (int)
    - weight,omitempty (*float64)
    - dimensions,omitempty (*string)
    - is_serialized (bool)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
    - attributes,omitempty ([]ProductAttributeValue)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/products/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateProductRequest**
  - CategoryID   *int
  - BrandID      *int
  - UnitID       *int
  - Name         *string
  - SKU          *string
  - Barcodes     []ProductBarcode
  - Description  *string
  - CostPrice    *float64
  - SellingPrice *float64
  - ReorderLevel *int
  - Weight       *float64
  - Dimensions   *string
  - IsSerialized *bool
  - IsActive     *bool
  - Attributes   map[int]string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Product)
    - product_id (int)
    - company_id (int)
    - category_id,omitempty (*int)
    - brand_id,omitempty (*int)
    - unit_id,omitempty (*int)
    - name (string)
    - sku,omitempty (*string)
    - barcodes,omitempty ([]ProductBarcode)
    - description,omitempty (*string)
    - cost_price,omitempty (*float64)
    - selling_price,omitempty (*float64)
    - reorder_level (int)
    - weight,omitempty (*float64)
    - dimensions,omitempty (*string)
    - is_serialized (bool)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
    - attributes,omitempty ([]ProductAttributeValue)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/products/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Product)
    - product_id (int)
    - company_id (int)
    - category_id,omitempty (*int)
    - brand_id,omitempty (*int)
    - unit_id,omitempty (*int)
    - name (string)
    - sku,omitempty (*string)
    - barcodes,omitempty ([]ProductBarcode)
    - description,omitempty (*string)
    - cost_price,omitempty (*float64)
    - selling_price,omitempty (*float64)
    - reorder_level (int)
    - weight,omitempty (*float64)
    - dimensions,omitempty (*string)
    - is_serialized (bool)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
    - attributes,omitempty ([]ProductAttributeValue)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/categories

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Category)
    - category_id (int)
    - company_id (int)
    - name (string)
    - description,omitempty (*string)
    - parent_id,omitempty (*int)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/categories

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateCategoryRequest**
  - Name        string
  - Description *string
  - ParentID    *int

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Category)
    - category_id (int)
    - company_id (int)
    - name (string)
    - description,omitempty (*string)
    - parent_id,omitempty (*int)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/categories/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateCategoryRequest**
  - Name        *string
  - Description *string
  - ParentID    *int
  - IsActive    *bool

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Category)
    - category_id (int)
    - company_id (int)
    - name (string)
    - description,omitempty (*string)
    - parent_id,omitempty (*int)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/categories/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Category)
    - category_id (int)
    - company_id (int)
    - name (string)
    - description,omitempty (*string)
    - parent_id,omitempty (*int)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/brands

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Brand)
    - brand_id (int)
    - company_id (int)
    - name (string)
    - description,omitempty (*string)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/brands

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateBrandRequest**
  - Name        string
  - Description *string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Brand)
    - brand_id (int)
    - company_id (int)
    - name (string)
    - description,omitempty (*string)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/units

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Unit)
    - unit_id (int)
    - name (string)
    - symbol,omitempty (*string)
    - base_unit_id,omitempty (*int)
    - conversion_factor,omitempty (*float64)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/units

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateUnitRequest**
  - Name             string
  - Symbol           *string
  - BaseUnitID       *int
  - ConversionFactor *float64

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Unit)
    - unit_id (int)
    - name (string)
    - symbol,omitempty (*string)
    - base_unit_id,omitempty (*int)
    - conversion_factor,omitempty (*float64)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/product-attribute-definitions

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (ProductAttributeDefinition)
    - attribute_id (int)
    - company_id (int)
    - name (string)
    - type (string)
    - is_required (bool)
    - options,omitempty (*string)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/product-attribute-definitions

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (ProductAttributeDefinition)
    - attribute_id (int)
    - company_id (int)
    - name (string)
    - type (string)
    - is_required (bool)
    - options,omitempty (*string)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/product-attribute-definitions/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (ProductAttributeDefinition)
    - attribute_id (int)
    - company_id (int)
    - name (string)
    - type (string)
    - is_required (bool)
    - options,omitempty (*string)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/product-attribute-definitions/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (ProductAttributeDefinition)
    - attribute_id (int)
    - company_id (int)
    - name (string)
    - type (string)
    - is_required (bool)
    - options,omitempty (*string)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/inventory/stock

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Stock)
    - stock_id (int)
    - location_id (int)
    - product_id (int)
    - quantity (float64)
    - reserved_quantity (float64)
    - last_updated (time.Time)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/inventory/stock-adjustment

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateStockAdjustmentRequest**
  - ProductID  int
  - Adjustment float64
  - Reason     string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (StockAdjustment)
    - adjustment_id (int)
    - location_id (int)
    - product_id (int)
    - adjustment (float64)
    - reason (string)
    - created_by (int)
    - created_at (time.Time)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/inventory/stock-adjustments

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (StockAdjustment)
    - adjustment_id (int)
    - location_id (int)
    - product_id (int)
    - adjustment (float64)
    - reason (string)
    - created_by (int)
    - created_at (time.Time)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/inventory/summary

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/inventory/import

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/inventory/export

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/inventory/barcode

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**BarcodeRequest**
  - ProductIDs []int

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/inventory/transfers

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/inventory/transfers/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/inventory/transfers

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateStockTransferRequest**
  - ToLocationID int
  - Notes        *string
  - Items        []CreateStockTransferDetailRequest

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/inventory/transfers/:id/approve

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/inventory/transfers/:id/complete

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/inventory/transfers/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/sales

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Sale)
    - sale_id (int)
    - sale_number (string)
    - location_id (int)
    - customer_id,omitempty (*int)
    - sale_date (time.Time)
    - sale_time,omitempty (*time.Time)
    - subtotal (float64)
    - tax_amount (float64)
    - discount_amount (float64)
    - total_amount (float64)
    - paid_amount (float64)
    - payment_method_id,omitempty (*int)
    - status (string)
    - pos_status (string)
    - is_quick_sale (bool)
    - notes,omitempty (*string)
    - created_by (int)
    - updated_by,omitempty (*int)
    - items,omitempty ([]SaleDetail)
    - customer,omitempty (*Customer)
    - payment_method,omitempty (*PaymentMethod)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/sales/history

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/sales/history/export

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/sales/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Sale)
    - sale_id (int)
    - sale_number (string)
    - location_id (int)
    - customer_id,omitempty (*int)
    - sale_date (time.Time)
    - sale_time,omitempty (*time.Time)
    - subtotal (float64)
    - tax_amount (float64)
    - discount_amount (float64)
    - total_amount (float64)
    - paid_amount (float64)
    - payment_method_id,omitempty (*int)
    - status (string)
    - pos_status (string)
    - is_quick_sale (bool)
    - notes,omitempty (*string)
    - created_by (int)
    - updated_by,omitempty (*int)
    - items,omitempty ([]SaleDetail)
    - customer,omitempty (*Customer)
    - payment_method,omitempty (*PaymentMethod)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/sales

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateSaleRequest**
  - CustomerID      *int
  - Items           []CreateSaleDetailRequest
  - PaymentMethodID *int
  - PaidAmount      float64
  - DiscountAmount  float64
  - Notes           *string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Sale)
    - sale_id (int)
    - sale_number (string)
    - location_id (int)
    - customer_id,omitempty (*int)
    - sale_date (time.Time)
    - sale_time,omitempty (*time.Time)
    - subtotal (float64)
    - tax_amount (float64)
    - discount_amount (float64)
    - total_amount (float64)
    - paid_amount (float64)
    - payment_method_id,omitempty (*int)
    - status (string)
    - pos_status (string)
    - is_quick_sale (bool)
    - notes,omitempty (*string)
    - created_by (int)
    - updated_by,omitempty (*int)
    - items,omitempty ([]SaleDetail)
    - customer,omitempty (*Customer)
    - payment_method,omitempty (*PaymentMethod)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/sales/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateSaleRequest**
  - PaymentMethodID *int
  - Notes           *string
  - Status          *string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Sale)
    - sale_id (int)
    - sale_number (string)
    - location_id (int)
    - customer_id,omitempty (*int)
    - sale_date (time.Time)
    - sale_time,omitempty (*time.Time)
    - subtotal (float64)
    - tax_amount (float64)
    - discount_amount (float64)
    - total_amount (float64)
    - paid_amount (float64)
    - payment_method_id,omitempty (*int)
    - status (string)
    - pos_status (string)
    - is_quick_sale (bool)
    - notes,omitempty (*string)
    - created_by (int)
    - updated_by,omitempty (*int)
    - items,omitempty ([]SaleDetail)
    - customer,omitempty (*Customer)
    - payment_method,omitempty (*PaymentMethod)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/sales/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Sale)
    - sale_id (int)
    - sale_number (string)
    - location_id (int)
    - customer_id,omitempty (*int)
    - sale_date (time.Time)
    - sale_time,omitempty (*time.Time)
    - subtotal (float64)
    - tax_amount (float64)
    - discount_amount (float64)
    - total_amount (float64)
    - paid_amount (float64)
    - payment_method_id,omitempty (*int)
    - status (string)
    - pos_status (string)
    - is_quick_sale (bool)
    - notes,omitempty (*string)
    - created_by (int)
    - updated_by,omitempty (*int)
    - items,omitempty ([]SaleDetail)
    - customer,omitempty (*Customer)
    - payment_method,omitempty (*PaymentMethod)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/sales/:id/hold

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/sales/:id/resume

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/sales/quick

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**QuickSaleRequest**
  - Items []CreateSaleDetailRequest

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/sales/quotes

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Quote)
    - quote_id (int)
    - quote_number (string)
    - location_id (int)
    - customer_id,omitempty (*int)
    - quote_date (time.Time)
    - valid_until,omitempty (*time.Time)
    - subtotal (float64)
    - tax_amount (float64)
    - discount_amount (float64)
    - total_amount (float64)
    - status (string)
    - notes,omitempty (*string)
    - created_by (int)
    - updated_by,omitempty (*int)
    - items,omitempty ([]QuoteItem)
    - customer,omitempty (*Customer)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/sales/quotes/export

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/sales/quotes/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Quote)
    - quote_id (int)
    - quote_number (string)
    - location_id (int)
    - customer_id,omitempty (*int)
    - quote_date (time.Time)
    - valid_until,omitempty (*time.Time)
    - subtotal (float64)
    - tax_amount (float64)
    - discount_amount (float64)
    - total_amount (float64)
    - status (string)
    - notes,omitempty (*string)
    - created_by (int)
    - updated_by,omitempty (*int)
    - items,omitempty ([]QuoteItem)
    - customer,omitempty (*Customer)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/sales/quotes

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateQuoteRequest**
  - CustomerID     *int
  - Items          []CreateQuoteItemRequest
  - DiscountAmount float64
  - ValidUntil     time.Time
  - Notes          *string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Quote)
    - quote_id (int)
    - quote_number (string)
    - location_id (int)
    - customer_id,omitempty (*int)
    - quote_date (time.Time)
    - valid_until,omitempty (*time.Time)
    - subtotal (float64)
    - tax_amount (float64)
    - discount_amount (float64)
    - total_amount (float64)
    - status (string)
    - notes,omitempty (*string)
    - created_by (int)
    - updated_by,omitempty (*int)
    - items,omitempty ([]QuoteItem)
    - customer,omitempty (*Customer)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/sales/quotes/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateQuoteRequest**
  - Status     *string
  - Notes      *string
  - ValidUntil *time.Time

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Quote)
    - quote_id (int)
    - quote_number (string)
    - location_id (int)
    - customer_id,omitempty (*int)
    - quote_date (time.Time)
    - valid_until,omitempty (*time.Time)
    - subtotal (float64)
    - tax_amount (float64)
    - discount_amount (float64)
    - total_amount (float64)
    - status (string)
    - notes,omitempty (*string)
    - created_by (int)
    - updated_by,omitempty (*int)
    - items,omitempty ([]QuoteItem)
    - customer,omitempty (*Customer)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/sales/quotes/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Quote)
    - quote_id (int)
    - quote_number (string)
    - location_id (int)
    - customer_id,omitempty (*int)
    - quote_date (time.Time)
    - valid_until,omitempty (*time.Time)
    - subtotal (float64)
    - tax_amount (float64)
    - discount_amount (float64)
    - total_amount (float64)
    - status (string)
    - notes,omitempty (*string)
    - created_by (int)
    - updated_by,omitempty (*int)
    - items,omitempty ([]QuoteItem)
    - customer,omitempty (*Customer)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/sales/quotes/:id/print

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/sales/quotes/:id/share

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**ShareQuoteRequest**
  - Email string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/pos/products

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Product)
    - product_id (int)
    - company_id (int)
    - category_id,omitempty (*int)
    - brand_id,omitempty (*int)
    - unit_id,omitempty (*int)
    - name (string)
    - sku,omitempty (*string)
    - barcodes,omitempty ([]ProductBarcode)
    - description,omitempty (*string)
    - cost_price,omitempty (*float64)
    - selling_price,omitempty (*float64)
    - reorder_level (int)
    - weight,omitempty (*float64)
    - dimensions,omitempty (*string)
    - is_serialized (bool)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
    - attributes,omitempty ([]ProductAttributeValue)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/pos/customers

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Customer)
    - customer_id (int)
    - company_id (int)
    - name (string)
    - phone,omitempty (*string)
    - email,omitempty (*string)
    - address,omitempty (*string)
    - tax_number,omitempty (*string)
    - credit_limit (float64)
    - payment_terms (int)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
    - credit_balance,omitempty (float64)
    - invoices,omitempty ([]CustomerInvoiceReference)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/pos/checkout

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**POSCheckoutRequest**
  - CustomerID      *int
  - Items           []CreateSaleDetailRequest
  - PaymentMethodID *int
  - DiscountAmount  float64
  - PaidAmount      float64

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/pos/print

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**POSPrintRequest**
  - InvoiceID int

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/pos/held-sales

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/pos/payment-methods

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (PaymentMethod)
    - method_id (int)
    - company_id,omitempty (*int)
    - name (string)
    - type (string)
    - external_integration,omitempty (*JSONB)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/pos/sales-summary

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (SalesSummary)
    - period (string)
    - total_sales (float64)
    - transactions (int)
    - outstanding (float64)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/pos/receipt/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/loyalty-programs

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (LoyaltyProgram)
    - loyalty_id (int)
    - customer_id (int)
    - points (float64)
    - total_earned (float64)
    - total_redeemed (float64)
    - last_updated (time.Time)
    - customer,omitempty (*Customer)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/loyalty-programs/:customer_id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (LoyaltyProgram)
    - loyalty_id (int)
    - customer_id (int)
    - points (float64)
    - total_earned (float64)
    - total_redeemed (float64)
    - last_updated (time.Time)
    - customer,omitempty (*Customer)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/loyalty-redemptions

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (LoyaltyRedemption)
    - redemption_id (int)
    - sale_id,omitempty (*int)
    - customer_id (int)
    - points_used (float64)
    - value_redeemed (float64)
    - redeemed_at (time.Time)
    - customer,omitempty (*Customer)
    - sale,omitempty (*Sale)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/loyalty-redemptions

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateLoyaltyRedemptionRequest**
  - CustomerID int
  - PointsUsed float64
  - Reference  *string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (LoyaltyRedemption)
    - redemption_id (int)
    - sale_id,omitempty (*int)
    - customer_id (int)
    - points_used (float64)
    - value_redeemed (float64)
    - redeemed_at (time.Time)
    - customer,omitempty (*Customer)
    - sale,omitempty (*Sale)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/loyalty/settings

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Setting)
    - setting_id (int)
    - company_id (int)
    - location_id,omitempty (*int)
    - key (string)
    - value (JSONB)
    - description,omitempty (*string)
    - data_type (string)
    - created_at (time.Time)
    - updated_at (time.Time)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/loyalty/award-points

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/promotions

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Promotion)
    - promotion_id (int)
    - company_id (int)
    - name (string)
    - description,omitempty (*string)
    - discount_type,omitempty (*string)
    - value,omitempty (*float64)
    - min_amount,omitempty (*float64)
    - start_date (time.Time)
    - end_date (time.Time)
    - applicable_to,omitempty (*string)
    - conditions,omitempty (*JSONB)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/promotions

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreatePromotionRequest**
  - Name         string
  - Description  *string
  - DiscountType *string
  - Value        *float64
  - MinAmount    *float64
  - StartDate    string
  - EndDate      string
  - ApplicableTo *string
  - Conditions   *JSONB

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Promotion)
    - promotion_id (int)
    - company_id (int)
    - name (string)
    - description,omitempty (*string)
    - discount_type,omitempty (*string)
    - value,omitempty (*float64)
    - min_amount,omitempty (*float64)
    - start_date (time.Time)
    - end_date (time.Time)
    - applicable_to,omitempty (*string)
    - conditions,omitempty (*JSONB)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/promotions/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdatePromotionRequest**
  - Name         *string
  - Description  *string
  - DiscountType *string
  - Value        *float64
  - MinAmount    *float64
  - StartDate    *string
  - EndDate      *string
  - ApplicableTo *string
  - Conditions   *JSONB
  - IsActive     *bool

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Promotion)
    - promotion_id (int)
    - company_id (int)
    - name (string)
    - description,omitempty (*string)
    - discount_type,omitempty (*string)
    - value,omitempty (*float64)
    - min_amount,omitempty (*float64)
    - start_date (time.Time)
    - end_date (time.Time)
    - applicable_to,omitempty (*string)
    - conditions,omitempty (*JSONB)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/promotions/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Promotion)
    - promotion_id (int)
    - company_id (int)
    - name (string)
    - description,omitempty (*string)
    - discount_type,omitempty (*string)
    - value,omitempty (*float64)
    - min_amount,omitempty (*float64)
    - start_date (time.Time)
    - end_date (time.Time)
    - applicable_to,omitempty (*string)
    - conditions,omitempty (*JSONB)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/promotions/check-eligibility

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**PromotionEligibilityRequest**
  - CustomerID  *int
  - TotalAmount float64
  - ProductIDs  []int
  - CategoryIDs []int

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (PromotionEligibilityResponse)
    - EligiblePromotions ([]struct)
    - promotion_id (int)
    - name (string)
    - discount_type (string)
    - value (float64)
    - discount_amount (float64)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/sale-returns

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (PromotionEligibilityResponse)
    - EligiblePromotions ([]struct)
    - promotion_id (int)
    - name (string)
    - discount_type (string)
    - value (float64)
    - discount_amount (float64)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/sale-returns/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (SaleReturn)
    - return_id (int)
    - return_number (string)
    - sale_id (int)
    - location_id (int)
    - customer_id,omitempty (*int)
    - return_date (time.Time)
    - total_amount (float64)
    - reason,omitempty (*string)
    - status (string)
    - created_by (int)
    - items,omitempty ([]SaleReturnDetail)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/sale-returns

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateSaleReturnRequest**
  - SaleID int
  - Items  []CreateSaleReturnItemRequest
  - Reason *string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (SaleReturn)
    - return_id (int)
    - return_number (string)
    - sale_id (int)
    - location_id (int)
    - customer_id,omitempty (*int)
    - return_date (time.Time)
    - total_amount (float64)
    - reason,omitempty (*string)
    - status (string)
    - created_by (int)
    - items,omitempty ([]SaleReturnDetail)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/sale-returns/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (SaleReturn)
    - return_id (int)
    - return_number (string)
    - sale_id (int)
    - location_id (int)
    - customer_id,omitempty (*int)
    - return_date (time.Time)
    - total_amount (float64)
    - reason,omitempty (*string)
    - status (string)
    - created_by (int)
    - items,omitempty ([]SaleReturnDetail)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/sale-returns/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (SaleReturn)
    - return_id (int)
    - return_number (string)
    - sale_id (int)
    - location_id (int)
    - customer_id,omitempty (*int)
    - return_date (time.Time)
    - total_amount (float64)
    - reason,omitempty (*string)
    - status (string)
    - created_by (int)
    - items,omitempty ([]SaleReturnDetail)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/sale-returns/summary

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/sale-returns/search/:sale_id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/sale-returns/process/:sale_id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/purchases

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Purchase)
    - purchase_id (int)
    - purchase_number (string)
    - location_id (int)
    - supplier_id (int)
    - purchase_order_id,omitempty (*int)
    - workflow_state_id,omitempty (*int)
    - purchase_date (time.Time)
    - subtotal (float64)
    - tax_amount (float64)
    - discount_amount (float64)
    - total_amount (float64)
    - paid_amount (float64)
    - payment_terms (int)
    - due_date,omitempty (*time.Time)
    - status (string)
    - reference_number,omitempty (*string)
    - notes,omitempty (*string)
    - created_by (int)
    - updated_by,omitempty (*int)
    - items,omitempty ([]PurchaseDetail)
    - goods_receipts,omitempty ([]GoodsReceipt)
    - supplier,omitempty (*Supplier)
    - location,omitempty (*Location)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/purchases/history

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/purchases/pending

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/purchases/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Purchase)
    - purchase_id (int)
    - purchase_number (string)
    - location_id (int)
    - supplier_id (int)
    - purchase_order_id,omitempty (*int)
    - workflow_state_id,omitempty (*int)
    - purchase_date (time.Time)
    - subtotal (float64)
    - tax_amount (float64)
    - discount_amount (float64)
    - total_amount (float64)
    - paid_amount (float64)
    - payment_terms (int)
    - due_date,omitempty (*time.Time)
    - status (string)
    - reference_number,omitempty (*string)
    - notes,omitempty (*string)
    - created_by (int)
    - updated_by,omitempty (*int)
    - items,omitempty ([]PurchaseDetail)
    - goods_receipts,omitempty ([]GoodsReceipt)
    - supplier,omitempty (*Supplier)
    - location,omitempty (*Location)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/purchases

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreatePurchaseRequest**
  - SupplierID      int
  - LocationID      *int
  - PurchaseDate    *time.Time
  - ReferenceNumber *string
  - PaymentTerms    *int
  - Notes           *string
  - Items           []CreatePurchaseDetailRequest

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Purchase)
    - purchase_id (int)
    - purchase_number (string)
    - location_id (int)
    - supplier_id (int)
    - purchase_order_id,omitempty (*int)
    - workflow_state_id,omitempty (*int)
    - purchase_date (time.Time)
    - subtotal (float64)
    - tax_amount (float64)
    - discount_amount (float64)
    - total_amount (float64)
    - paid_amount (float64)
    - payment_terms (int)
    - due_date,omitempty (*time.Time)
    - status (string)
    - reference_number,omitempty (*string)
    - notes,omitempty (*string)
    - created_by (int)
    - updated_by,omitempty (*int)
    - items,omitempty ([]PurchaseDetail)
    - goods_receipts,omitempty ([]GoodsReceipt)
    - supplier,omitempty (*Supplier)
    - location,omitempty (*Location)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/purchases/quick

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreatePurchaseRequest**
  - SupplierID      int
  - LocationID      *int
  - PurchaseDate    *time.Time
  - ReferenceNumber *string
  - PaymentTerms    *int
  - Notes           *string
  - Items           []CreatePurchaseDetailRequest

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/purchases/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdatePurchaseRequest**
  - ReferenceNumber *string
  - PaymentTerms    *int
  - Notes           *string
  - Status          *string
  - Items           []CreatePurchaseDetailRequest

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Purchase)
    - purchase_id (int)
    - purchase_number (string)
    - location_id (int)
    - supplier_id (int)
    - purchase_order_id,omitempty (*int)
    - workflow_state_id,omitempty (*int)
    - purchase_date (time.Time)
    - subtotal (float64)
    - tax_amount (float64)
    - discount_amount (float64)
    - total_amount (float64)
    - paid_amount (float64)
    - payment_terms (int)
    - due_date,omitempty (*time.Time)
    - status (string)
    - reference_number,omitempty (*string)
    - notes,omitempty (*string)
    - created_by (int)
    - updated_by,omitempty (*int)
    - items,omitempty ([]PurchaseDetail)
    - goods_receipts,omitempty ([]GoodsReceipt)
    - supplier,omitempty (*Supplier)
    - location,omitempty (*Location)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/purchases/:id/receive

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**ReceivePurchaseRequest**
  - Items []ReceivePurchaseItemRequest

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/purchases/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Purchase)
    - purchase_id (int)
    - purchase_number (string)
    - location_id (int)
    - supplier_id (int)
    - purchase_order_id,omitempty (*int)
    - workflow_state_id,omitempty (*int)
    - purchase_date (time.Time)
    - subtotal (float64)
    - tax_amount (float64)
    - discount_amount (float64)
    - total_amount (float64)
    - paid_amount (float64)
    - payment_terms (int)
    - due_date,omitempty (*time.Time)
    - status (string)
    - reference_number,omitempty (*string)
    - notes,omitempty (*string)
    - created_by (int)
    - updated_by,omitempty (*int)
    - items,omitempty ([]PurchaseDetail)
    - goods_receipts,omitempty ([]GoodsReceipt)
    - supplier,omitempty (*Supplier)
    - location,omitempty (*Location)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/purchase-orders

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (PurchaseOrder)
    - purchase_order_id (int)
    - order_number (string)
    - location_id (int)
    - supplier_id (int)
    - order_date (time.Time)
    - status (string)
    - total_amount (float64)
    - created_by (int)
    - workflow_state_id,omitempty (*int)
    - items,omitempty ([]PurchaseOrderItem)
    - supplier,omitempty (*Supplier)
    - location,omitempty (*Location)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/purchase-orders/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (PurchaseOrder)
    - purchase_order_id (int)
    - order_number (string)
    - location_id (int)
    - supplier_id (int)
    - order_date (time.Time)
    - status (string)
    - total_amount (float64)
    - created_by (int)
    - workflow_state_id,omitempty (*int)
    - items,omitempty ([]PurchaseOrderItem)
    - supplier,omitempty (*Supplier)
    - location,omitempty (*Location)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/purchase-orders/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (PurchaseOrder)
    - purchase_order_id (int)
    - order_number (string)
    - location_id (int)
    - supplier_id (int)
    - order_date (time.Time)
    - status (string)
    - total_amount (float64)
    - created_by (int)
    - workflow_state_id,omitempty (*int)
    - items,omitempty ([]PurchaseOrderItem)
    - supplier,omitempty (*Supplier)
    - location,omitempty (*Location)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/purchase-orders/:id/approve

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/goods-receipts

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (GoodsReceipt)
    - goods_receipt_id (int)
    - receipt_number (string)
    - purchase_order_id,omitempty (*int)
    - purchase_id,omitempty (*int)
    - location_id (int)
    - supplier_id (int)
    - received_date (time.Time)
    - received_by (int)
    - workflow_state_id,omitempty (*int)
    - items,omitempty ([]GoodsReceiptItem)
    - supplier,omitempty (*Supplier)
    - location,omitempty (*Location)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/purchase-returns

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (PurchaseReturn)
    - return_id (int)
    - return_number (string)
    - purchase_id (int)
    - location_id (int)
    - supplier_id (int)
    - return_date (time.Time)
    - total_amount (float64)
    - reason,omitempty (*string)
    - status (string)
    - created_by (int)
    - approved_by,omitempty (*int)
    - approved_at,omitempty (*time.Time)
    - items,omitempty ([]PurchaseReturnDetail)
    - purchase,omitempty (*Purchase)
    - supplier,omitempty (*Supplier)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/purchase-returns/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (PurchaseReturn)
    - return_id (int)
    - return_number (string)
    - purchase_id (int)
    - location_id (int)
    - supplier_id (int)
    - return_date (time.Time)
    - total_amount (float64)
    - reason,omitempty (*string)
    - status (string)
    - created_by (int)
    - approved_by,omitempty (*int)
    - approved_at,omitempty (*time.Time)
    - items,omitempty ([]PurchaseReturnDetail)
    - purchase,omitempty (*Purchase)
    - supplier,omitempty (*Supplier)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/purchase-returns

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreatePurchaseReturnRequest**
  - PurchaseID int
  - Reason     *string
  - Items      []CreatePurchaseReturnDetailRequest

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (PurchaseReturn)
    - return_id (int)
    - return_number (string)
    - purchase_id (int)
    - location_id (int)
    - supplier_id (int)
    - return_date (time.Time)
    - total_amount (float64)
    - reason,omitempty (*string)
    - status (string)
    - created_by (int)
    - approved_by,omitempty (*int)
    - approved_at,omitempty (*time.Time)
    - items,omitempty ([]PurchaseReturnDetail)
    - purchase,omitempty (*Purchase)
    - supplier,omitempty (*Supplier)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/purchase-returns/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (PurchaseReturn)
    - return_id (int)
    - return_number (string)
    - purchase_id (int)
    - location_id (int)
    - supplier_id (int)
    - return_date (time.Time)
    - total_amount (float64)
    - reason,omitempty (*string)
    - status (string)
    - created_by (int)
    - approved_by,omitempty (*int)
    - approved_at,omitempty (*time.Time)
    - items,omitempty ([]PurchaseReturnDetail)
    - purchase,omitempty (*Purchase)
    - supplier,omitempty (*Supplier)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/purchase-returns/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (PurchaseReturn)
    - return_id (int)
    - return_number (string)
    - purchase_id (int)
    - location_id (int)
    - supplier_id (int)
    - return_date (time.Time)
    - total_amount (float64)
    - reason,omitempty (*string)
    - status (string)
    - created_by (int)
    - approved_by,omitempty (*int)
    - approved_at,omitempty (*time.Time)
    - items,omitempty ([]PurchaseReturnDetail)
    - purchase,omitempty (*Purchase)
    - supplier,omitempty (*Supplier)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/customers

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Customer)
    - customer_id (int)
    - company_id (int)
    - name (string)
    - phone,omitempty (*string)
    - email,omitempty (*string)
    - address,omitempty (*string)
    - tax_number,omitempty (*string)
    - credit_limit (float64)
    - payment_terms (int)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
    - credit_balance,omitempty (float64)
    - invoices,omitempty ([]CustomerInvoiceReference)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/customers/:id/summary

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/customers

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateCustomerRequest**
  - Name         string
  - Phone        *string
  - Email        *string
  - Address      *string
  - TaxNumber    *string
  - CreditLimit  float64
  - PaymentTerms int

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Customer)
    - customer_id (int)
    - company_id (int)
    - name (string)
    - phone,omitempty (*string)
    - email,omitempty (*string)
    - address,omitempty (*string)
    - tax_number,omitempty (*string)
    - credit_limit (float64)
    - payment_terms (int)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
    - credit_balance,omitempty (float64)
    - invoices,omitempty ([]CustomerInvoiceReference)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/customers/import

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/customers/export

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/customers/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateCustomerRequest**
  - Name         *string
  - Phone        *string
  - Email        *string
  - Address      *string
  - TaxNumber    *string
  - CreditLimit  *float64
  - PaymentTerms *int
  - IsActive     *bool

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Customer)
    - customer_id (int)
    - company_id (int)
    - name (string)
    - phone,omitempty (*string)
    - email,omitempty (*string)
    - address,omitempty (*string)
    - tax_number,omitempty (*string)
    - credit_limit (float64)
    - payment_terms (int)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
    - credit_balance,omitempty (float64)
    - invoices,omitempty ([]CustomerInvoiceReference)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/customers/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Customer)
    - customer_id (int)
    - company_id (int)
    - name (string)
    - phone,omitempty (*string)
    - email,omitempty (*string)
    - address,omitempty (*string)
    - tax_number,omitempty (*string)
    - credit_limit (float64)
    - payment_terms (int)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
    - credit_balance,omitempty (float64)
    - invoices,omitempty ([]CustomerInvoiceReference)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/customers/:id/credit

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/customers/:id/credit

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreditTransactionRequest**
  - Amount      float64
  - Type        string
  - Description *string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/employees

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Employee)
    - employee_id (int)
    - company_id (int)
    - location_id,omitempty (*int)
    - employee_code,omitempty (*string)
    - name (string)
    - phone,omitempty (*string)
    - email,omitempty (*string)
    - address,omitempty (*string)
    - position,omitempty (*string)
    - department,omitempty (*string)
    - salary,omitempty (*float64)
    - hire_date,omitempty (*time.Time)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
    - last_check_in,omitempty (*time.Time)
    - last_check_out,omitempty (*time.Time)
    - leave_balance,omitempty (*float64)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/employees

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateEmployeeRequest**
  - LocationID   *int
  - EmployeeCode *string
  - Name         string
  - Phone        *string
  - Email        *string
  - Address      *string
  - Position     *string
  - Department   *string
  - Salary       *float64
  - HireDate     *time.Time
  - IsActive     *bool
  - LeaveBalance *float64

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Employee)
    - employee_id (int)
    - company_id (int)
    - location_id,omitempty (*int)
    - employee_code,omitempty (*string)
    - name (string)
    - phone,omitempty (*string)
    - email,omitempty (*string)
    - address,omitempty (*string)
    - position,omitempty (*string)
    - department,omitempty (*string)
    - salary,omitempty (*float64)
    - hire_date,omitempty (*time.Time)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
    - last_check_in,omitempty (*time.Time)
    - last_check_out,omitempty (*time.Time)
    - leave_balance,omitempty (*float64)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/employees/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateEmployeeRequest**
  - LocationID   *int
  - EmployeeCode *string
  - Name         *string
  - Phone        *string
  - Email        *string
  - Address      *string
  - Position     *string
  - Department   *string
  - Salary       *float64
  - HireDate     *time.Time
  - IsActive     *bool
  - LeaveBalance *float64

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Employee)
    - employee_id (int)
    - company_id (int)
    - location_id,omitempty (*int)
    - employee_code,omitempty (*string)
    - name (string)
    - phone,omitempty (*string)
    - email,omitempty (*string)
    - address,omitempty (*string)
    - position,omitempty (*string)
    - department,omitempty (*string)
    - salary,omitempty (*float64)
    - hire_date,omitempty (*time.Time)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
    - last_check_in,omitempty (*time.Time)
    - last_check_out,omitempty (*time.Time)
    - leave_balance,omitempty (*float64)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/employees/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Employee)
    - employee_id (int)
    - company_id (int)
    - location_id,omitempty (*int)
    - employee_code,omitempty (*string)
    - name (string)
    - phone,omitempty (*string)
    - email,omitempty (*string)
    - address,omitempty (*string)
    - position,omitempty (*string)
    - department,omitempty (*string)
    - salary,omitempty (*float64)
    - hire_date,omitempty (*time.Time)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
    - last_check_in,omitempty (*time.Time)
    - last_check_out,omitempty (*time.Time)
    - leave_balance,omitempty (*float64)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/attendance/check-in

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CheckInRequest**
  - EmployeeID int

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/attendance/check-out

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CheckOutRequest**
  - EmployeeID int

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/attendance/leave

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**LeaveRequest**
  - EmployeeID int
  - StartDate  string
  - EndDate    string
  - Reason     string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Leave)
    - leave_id (int)
    - employee_id (int)
    - start_date (time.Time)
    - end_date (time.Time)
    - reason (string)
    - status (string)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/attendance/holidays

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Holiday)
    - holiday_id (int)
    - company_id (int)
    - date (time.Time)
    - name (string)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/attendance/records

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/payrolls

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Payroll)
    - payroll_id (int)
    - employee_id (int)
    - pay_period_start (time.Time)
    - pay_period_end (time.Time)
    - basic_salary (float64)
    - gross_salary (float64)
    - total_deductions (float64)
    - net_salary (float64)
    - status (string)
    - processed_by,omitempty (*int)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/payrolls

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreatePayrollRequest**
  - EmployeeID  int
  - Month       string
  - BasicSalary float64
  - Allowances  float64
  - Deductions  float64

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Payroll)
    - payroll_id (int)
    - employee_id (int)
    - pay_period_start (time.Time)
    - pay_period_end (time.Time)
    - basic_salary (float64)
    - gross_salary (float64)
    - total_deductions (float64)
    - net_salary (float64)
    - status (string)
    - processed_by,omitempty (*int)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/payrolls/:id/mark-paid

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/payrolls/:id/components

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**AddComponentRequest**
  - Type   string
  - Amount float64

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/payrolls/:id/advances

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**AdvanceRequest**
  - Amount float64
  - Date   string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Advance)
    - advance_id (int)
    - payroll_id (int)
    - amount (float64)
    - date (time.Time)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/payrolls/:id/deductions

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**DeductionRequest**
  - Type   string
  - Amount float64
  - Date   string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Deduction)
    - deduction_id (int)
    - payroll_id (int)
    - type (string)
    - amount (float64)
    - date (time.Time)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/payrolls/:id/payslip

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Payslip)
    - payroll (Payroll)
    - components ([]SalaryComponent)
    - advances ([]Advance)
    - deductions ([]Deduction)
    - net_pay (float64)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/collections

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Collection)
    - collection_id (int)
    - collection_number (string)
    - customer_id (int)
    - location_id (int)
    - amount (float64)
    - collection_date (time.Time)
    - payment_method_id,omitempty (*int)
    - payment_method,omitempty (*string)
    - reference_number,omitempty (*string)
    - notes,omitempty (*string)
    - created_by (int)
    - sync_status (string)
    - created_at (time.Time)
    - updated_at (time.Time)
    - invoices,omitempty ([]CollectionInvoice)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/collections

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateCollectionRequest**
  - CustomerID      int
  - Amount          float64
  - PaymentMethodID *int
  - ReceivedDate    *string
  - ReferenceNumber *string
  - Notes           *string
  - Invoices        []CollectionInvoiceRequest

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Collection)
    - collection_id (int)
    - collection_number (string)
    - customer_id (int)
    - location_id (int)
    - amount (float64)
    - collection_date (time.Time)
    - payment_method_id,omitempty (*int)
    - payment_method,omitempty (*string)
    - reference_number,omitempty (*string)
    - notes,omitempty (*string)
    - created_by (int)
    - sync_status (string)
    - created_at (time.Time)
    - updated_at (time.Time)
    - invoices,omitempty ([]CollectionInvoice)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/collections/outstanding

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/collections/:id/receipt

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/collections/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Collection)
    - collection_id (int)
    - collection_number (string)
    - customer_id (int)
    - location_id (int)
    - amount (float64)
    - collection_date (time.Time)
    - payment_method_id,omitempty (*int)
    - payment_method,omitempty (*string)
    - reference_number,omitempty (*string)
    - notes,omitempty (*string)
    - created_by (int)
    - sync_status (string)
    - created_at (time.Time)
    - updated_at (time.Time)
    - invoices,omitempty ([]CollectionInvoice)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/expenses

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Expense)
    - expense_id (int)
    - category_id (int)
    - location_id (int)
    - amount (float64)
    - notes,omitempty (*string)
    - expense_date (time.Time)
    - created_by (int)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/expenses/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Expense)
    - expense_id (int)
    - category_id (int)
    - location_id (int)
    - amount (float64)
    - notes,omitempty (*string)
    - expense_date (time.Time)
    - created_by (int)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/expenses

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateExpenseRequest**
  - CategoryID  int
  - Amount      float64
  - Notes       *string
  - ExpenseDate time.Time

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Expense)
    - expense_id (int)
    - category_id (int)
    - location_id (int)
    - amount (float64)
    - notes,omitempty (*string)
    - expense_date (time.Time)
    - created_by (int)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/expenses/categories

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/expenses/categories

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateExpenseCategoryRequest**
  - Name string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/expenses/categories/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/expenses/categories/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/vouchers

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Voucher)
    - voucher_id (int)
    - company_id (int)
    - type (string)
    - amount (float64)
    - date (time.Time)
    - account_id (int)
    - reference (string)
    - description,omitempty (*string)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/vouchers/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Voucher)
    - voucher_id (int)
    - company_id (int)
    - type (string)
    - amount (float64)
    - date (time.Time)
    - account_id (int)
    - reference (string)
    - description,omitempty (*string)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/vouchers/:type

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateVoucherRequest**
  - AccountID   int
  - Amount      float64
  - Reference   string
  - Description *string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Voucher)
    - voucher_id (int)
    - company_id (int)
    - type (string)
    - amount (float64)
    - date (time.Time)
    - account_id (int)
    - reference (string)
    - description,omitempty (*string)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/ledgers

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/ledgers/:account_id/entries

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/cash-registers

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (CashRegister)
    - register_id (int)
    - location_id (int)
    - date (time.Time)
    - opening_balance (float64)
    - closing_balance,omitempty (*float64)
    - expected_balance (float64)
    - cash_in (float64)
    - cash_out (float64)
    - variance (float64)
    - opened_by,omitempty (*int)
    - closed_by,omitempty (*int)
    - status (string)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/cash-registers/open

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/cash-registers/close

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/cash-registers/tally

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/reports/sales-summary

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (SalesSummary)
    - period (string)
    - total_sales (float64)
    - transactions (int)
    - outstanding (float64)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/reports/stock-summary

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (StockSummary)
    - product_id (int)
    - location_id (int)
    - quantity (float64)
    - stock_value (float64)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/reports/top-products

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (TopProduct)
    - product_id,omitempty (*int)
    - product_name (string)
    - quantity_sold (float64)
    - revenue (float64)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/reports/customer-balances

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (CustomerBalance)
    - customer_id (int)
    - name (string)
    - total_due (float64)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/reports/expenses-summary

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (ExpensesSummary)
    - category (string)
    - total_amount (float64)
    - period,omitempty (*string)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/reports/item-movement

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/reports/valuation

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/reports/purchase-vs-returns

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/reports/supplier

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Supplier)
    - supplier_id (int)
    - company_id (int)
    - name (string)
    - contact_person,omitempty (*string)
    - phone,omitempty (*string)
    - email,omitempty (*string)
    - address,omitempty (*string)
    - tax_number,omitempty (*string)
    - payment_terms (int)
    - credit_limit (float64)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/reports/daily-cash

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/reports/income-expense

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/reports/general-ledger

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/reports/trial-balance

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/reports/profit-loss

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/reports/balance-sheet

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/reports/outstanding

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/reports/tax

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Tax)
    - tax_id (int)
    - company_id (int)
    - name (string)
    - percentage (float64)
    - is_compound (bool)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/reports/top-performers

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/suppliers

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Supplier)
    - supplier_id (int)
    - company_id (int)
    - name (string)
    - contact_person,omitempty (*string)
    - phone,omitempty (*string)
    - email,omitempty (*string)
    - address,omitempty (*string)
    - tax_number,omitempty (*string)
    - payment_terms (int)
    - credit_limit (float64)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/suppliers/import

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/suppliers/export

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/suppliers/:id/summary

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/suppliers/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Supplier)
    - supplier_id (int)
    - company_id (int)
    - name (string)
    - contact_person,omitempty (*string)
    - phone,omitempty (*string)
    - email,omitempty (*string)
    - address,omitempty (*string)
    - tax_number,omitempty (*string)
    - payment_terms (int)
    - credit_limit (float64)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/suppliers

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateSupplierRequest**
  - Name          string
  - ContactPerson *string
  - Phone         *string
  - Email         *string
  - Address       *string
  - TaxNumber     *string
  - PaymentTerms  *int
  - CreditLimit   *float64

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Supplier)
    - supplier_id (int)
    - company_id (int)
    - name (string)
    - contact_person,omitempty (*string)
    - phone,omitempty (*string)
    - email,omitempty (*string)
    - address,omitempty (*string)
    - tax_number,omitempty (*string)
    - payment_terms (int)
    - credit_limit (float64)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/suppliers/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateSupplierRequest**
  - Name          *string
  - ContactPerson *string
  - Phone         *string
  - Email         *string
  - Address       *string
  - TaxNumber     *string
  - PaymentTerms  *int
  - CreditLimit   *float64
  - IsActive      *bool

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Supplier)
    - supplier_id (int)
    - company_id (int)
    - name (string)
    - contact_person,omitempty (*string)
    - phone,omitempty (*string)
    - email,omitempty (*string)
    - address,omitempty (*string)
    - tax_number,omitempty (*string)
    - payment_terms (int)
    - credit_limit (float64)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/suppliers/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Supplier)
    - supplier_id (int)
    - company_id (int)
    - name (string)
    - contact_person,omitempty (*string)
    - phone,omitempty (*string)
    - email,omitempty (*string)
    - address,omitempty (*string)
    - tax_number,omitempty (*string)
    - payment_terms (int)
    - credit_limit (float64)
    - is_active (bool)
    - created_by (int)
    - updated_by,omitempty (*int)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/currencies

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/currencies

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateCurrencyRequest**
  - Code           string
  - Name           string
  - Symbol         *string
  - ExchangeRate   float64
  - IsBaseCurrency bool

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/currencies/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateCurrencyRequest**
  - Code           *string
  - Name           *string
  - Symbol         *string
  - ExchangeRate   *float64
  - IsBaseCurrency *bool

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## PATCH /api/v1/currencies/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateCurrencyRequest**
  - Code           *string
  - Name           *string
  - Symbol         *string
  - ExchangeRate   *float64
  - IsBaseCurrency *bool

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/currencies/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/taxes

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/taxes

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateTaxRequest**
  - Name       string
  - Percentage float64
  - IsCompound bool
  - IsActive   bool

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/taxes/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateTaxRequest**
  - Name       *string
  - Percentage *float64
  - IsCompound *bool
  - IsActive   *bool

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/taxes/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/settings

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Setting)
    - setting_id (int)
    - company_id (int)
    - location_id,omitempty (*int)
    - key (string)
    - value (JSONB)
    - description,omitempty (*string)
    - data_type (string)
    - created_at (time.Time)
    - updated_at (time.Time)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/settings

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateSettingsRequest**
  - Settings map[string]JSONB

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Setting)
    - setting_id (int)
    - company_id (int)
    - location_id,omitempty (*int)
    - key (string)
    - value (JSONB)
    - description,omitempty (*string)
    - data_type (string)
    - created_at (time.Time)
    - updated_at (time.Time)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/settings/company

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Company)
    - company_id (int)
    - name (string)
    - logo,omitempty (*string)
    - address,omitempty (*string)
    - phone,omitempty (*string)
    - email,omitempty (*string)
    - tax_number,omitempty (*string)
    - currency_id,omitempty (*int)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/settings/company

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CompanySettings**
  - Name    string
  - Address *string
  - Phone   *string
  - Email   *string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Company)
    - company_id (int)
    - name (string)
    - logo,omitempty (*string)
    - address,omitempty (*string)
    - phone,omitempty (*string)
    - email,omitempty (*string)
    - tax_number,omitempty (*string)
    - currency_id,omitempty (*int)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/settings/invoice

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/settings/invoice

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**InvoiceSettings**
  - Prefix     *string
  - NextNumber *int
  - Notes      *string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/settings/tax

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Tax)
    - tax_id (int)
    - company_id (int)
    - name (string)
    - percentage (float64)
    - is_compound (bool)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/settings/tax

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**TaxSettings**
  - TaxName    *string
  - TaxPercent *float64

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Tax)
    - tax_id (int)
    - company_id (int)
    - name (string)
    - percentage (float64)
    - is_compound (bool)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/settings/device-control

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/settings/device-control

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**DeviceControlSettings**
  - AllowRemote bool

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/settings/session-limit

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/settings/session-limit

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**SessionLimitRequest**
  - MaxSessions int

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/settings/session-limit

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**SessionLimitRequest**
  - MaxSessions int

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/settings/session-limit

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/settings/payment-methods

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (PaymentMethod)
    - method_id (int)
    - company_id,omitempty (*int)
    - name (string)
    - type (string)
    - external_integration,omitempty (*JSONB)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/settings/payment-methods

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**PaymentMethodRequest**
  - Name                string
  - Type                string
  - ExternalIntegration *JSONB
  - IsActive            bool

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (PaymentMethod)
    - method_id (int)
    - company_id,omitempty (*int)
    - name (string)
    - type (string)
    - external_integration,omitempty (*JSONB)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/settings/payment-methods/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**PaymentMethodRequest**
  - Name                string
  - Type                string
  - ExternalIntegration *JSONB
  - IsActive            bool

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (PaymentMethod)
    - method_id (int)
    - company_id,omitempty (*int)
    - name (string)
    - type (string)
    - external_integration,omitempty (*JSONB)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/settings/payment-methods/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (PaymentMethod)
    - method_id (int)
    - company_id,omitempty (*int)
    - name (string)
    - type (string)
    - external_integration,omitempty (*JSONB)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/settings/printer

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/settings/printer

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**PrinterProfile**
  - PrinterID    int
  - CompanyID    int
  - LocationID   *int
  - Name         string
  - PrinterType  string
  - PaperSize    *string
  - Connectivity *JSONB
  - IsDefault    bool
  - IsActive     bool

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/settings/printer/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**PrinterProfile**
  - PrinterID    int
  - CompanyID    int
  - LocationID   *int
  - Name         string
  - PrinterType  string
  - PaperSize    *string
  - Connectivity *JSONB
  - IsDefault    bool
  - IsActive     bool

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/settings/printer/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/audit-logs

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (AuditLog)
    - log_id (int)
    - user_id,omitempty (*int)
    - action (string)
    - table_name (string)
    - record_id,omitempty (*int)
    - old_value,omitempty (*JSONB)
    - new_value,omitempty (*JSONB)
    - field_changes,omitempty (*JSONB)
    - ip_address,omitempty (*string)
    - user_agent,omitempty (*string)
    - timestamp (time.Time)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/languages/:code

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Language)
    - language_code (string)
    - language_name (string)
    - is_active (bool)
    - created_at (time.Time)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/translations

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Translation)
    - translation_id (int)
    - key (string)
    - language_code (string)
    - value (string)
    - context,omitempty (*string)
    - created_at (time.Time)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/translations

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateTranslationsRequest**
  - Lang    string
  - Strings map[string]string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Translation)
    - translation_id (int)
    - key (string)
    - language_code (string)
    - value (string)
    - context,omitempty (*string)
    - created_at (time.Time)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/user-preferences

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (UserPreference)
    - preference_id (int)
    - user_id (int)
    - key (string)
    - value (string)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/user-preferences

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (UserPreference)
    - preference_id (int)
    - user_id (int)
    - key (string)
    - value (string)
  - error (string, optional)
  - meta (object, optional)

## PATCH /api/v1/user-preferences

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (UserPreference)
    - preference_id (int)
    - user_id (int)
    - key (string)
    - value (string)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/user-preferences/:key

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (UserPreference)
    - preference_id (int)
    - user_id (int)
    - key (string)
    - value (string)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/numbering-sequences

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (NumberingSequence)
    - sequence_id (int)
    - company_id (int)
    - location_id,omitempty (*int)
    - name (string)
    - prefix,omitempty (*string)
    - sequence_length (int)
    - current_number (int)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/numbering-sequences/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (NumberingSequence)
    - sequence_id (int)
    - company_id (int)
    - location_id,omitempty (*int)
    - name (string)
    - prefix,omitempty (*string)
    - sequence_length (int)
    - current_number (int)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/numbering-sequences

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (NumberingSequence)
    - sequence_id (int)
    - company_id (int)
    - location_id,omitempty (*int)
    - name (string)
    - prefix,omitempty (*string)
    - sequence_length (int)
    - current_number (int)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/numbering-sequences/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (NumberingSequence)
    - sequence_id (int)
    - company_id (int)
    - location_id,omitempty (*int)
    - name (string)
    - prefix,omitempty (*string)
    - sequence_length (int)
    - current_number (int)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/numbering-sequences/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (NumberingSequence)
    - sequence_id (int)
    - company_id (int)
    - location_id,omitempty (*int)
    - name (string)
    - prefix,omitempty (*string)
    - sequence_length (int)
    - current_number (int)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/invoice-templates

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (InvoiceTemplate)
    - template_id (int)
    - company_id (int)
    - name (string)
    - template_type (string)
    - layout (JSONB)
    - primary_language,omitempty (*string)
    - secondary_language,omitempty (*string)
    - is_default (bool)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/invoice-templates/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (InvoiceTemplate)
    - template_id (int)
    - company_id (int)
    - name (string)
    - template_type (string)
    - layout (JSONB)
    - primary_language,omitempty (*string)
    - secondary_language,omitempty (*string)
    - is_default (bool)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/invoice-templates

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (InvoiceTemplate)
    - template_id (int)
    - company_id (int)
    - name (string)
    - template_type (string)
    - layout (JSONB)
    - primary_language,omitempty (*string)
    - secondary_language,omitempty (*string)
    - is_default (bool)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/invoice-templates/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (InvoiceTemplate)
    - template_id (int)
    - company_id (int)
    - name (string)
    - template_type (string)
    - layout (JSONB)
    - primary_language,omitempty (*string)
    - secondary_language,omitempty (*string)
    - is_default (bool)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## DELETE /api/v1/invoice-templates/:id

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (InvoiceTemplate)
    - template_id (int)
    - company_id (int)
    - name (string)
    - template_type (string)
    - layout (JSONB)
    - primary_language,omitempty (*string)
    - secondary_language,omitempty (*string)
    - is_default (bool)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/print/receipt

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**PrintReceiptRequest**
  - Type        string
  - ReferenceID int

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## GET /api/v1/workflow-requests

### Headers
- Authorization: Bearer <token>

### Request Body
None

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (WorkflowRequest)
    - approval_id (int)
    - state_id (int)
    - approver_role_id (int)
    - status (string)
    - remarks,omitempty (*string)
    - approved_at,omitempty (*time.Time)
    - created_by (int)
    - updated_by,omitempty (*int)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/workflow-requests

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateWorkflowRequest**
  - StateID        int
  - ApproverRoleID int

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (WorkflowRequest)
    - approval_id (int)
    - state_id (int)
    - approver_role_id (int)
    - status (string)
    - remarks,omitempty (*string)
    - approved_at,omitempty (*time.Time)
    - created_by (int)
    - updated_by,omitempty (*int)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/workflow-requests/:id/approve

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**DecisionRequest**
  - Remarks *string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/workflow-requests/:id/reject

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**DecisionRequest**
  - Remarks *string

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)
