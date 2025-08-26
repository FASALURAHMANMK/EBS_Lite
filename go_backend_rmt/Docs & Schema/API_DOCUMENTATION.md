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
    - status (string)
    - message (string)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/auth/login

### Headers
- Content-Type: application/json

### Request Body
**LoginRequest**
  - username (string)
  - email (string)
  - password (string)
  - device_id (string)
  - device_name (string, optional)
  - include_preferences (bool)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (LoginResponse)
    - access_token (string)
    - refresh_token (string)
    - session_id (string)
    - user (UserResponse)
    - company (Company, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/auth/register

### Headers
- Content-Type: application/json

### Request Body
**RegisterRequest**
  - username (string)
  - email (string)
  - password (string)
  - first_name (string, optional)
  - last_name (string, optional)
  - phone (string, optional)
  - preferred_language (string, optional)
  - secondary_language (string, optional)

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
  - email (string)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (empty object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/auth/reset-password

### Headers
- Content-Type: application/json

### Request Body
**ResetPasswordRequest**
  - token (string)
  - new_password (string)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (empty object)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/auth/refresh-token

### Headers
- Content-Type: application/json

### Request Body
**RefreshTokenRequest**
  - refresh_token (string)

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
 - data (array of Language)
    - language_code (string)
    - language_name (string)
    - is_active (bool)
    - created_at (string (RFC3339 timestamp))
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
  - data (AuthMeResponse)
    - user (UserResponse)
    - company (Company, optional)
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
  - data (empty object)
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
 - data (array of DeviceSession)
    - session_id (string)
    - user_id (int)
    - device_id (string)
    - device_name (string, optional)
    - ip_address (string, optional)
    - user_agent (string, optional)
    - last_seen (string (RFC3339 timestamp))
    - last_sync_time (string (RFC3339 timestamp), optional)
    - is_active (bool)
    - is_stale (bool)
    - created_at (string (RFC3339 timestamp))
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
    - device_name (string, optional)
    - ip_address (string, optional)
    - user_agent (string, optional)
    - last_seen (string (RFC3339 timestamp))
    - last_sync_time (string (RFC3339 timestamp), optional)
    - is_active (bool)
    - is_stale (bool)
    - created_at (string (RFC3339 timestamp))
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
  - data (DashboardMetrics)
    - credit_outstanding (number)
    - inventory_value (number)
    - today_sales (number)
    - today_purchases (number)
    - cash_in (number)
    - cash_out (number)
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
  - data (QuickActionCounts)
    - sales_today (int)
    - purchases_today (int)
    - collections_today (int)
    - payments_today (int)
    - receipts_today (int)
    - journals_today (int)
    - low_stock_items (int)
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
 - data (array of User)
    - user_id (int)
    - company_id (int, optional)
    - location_id (int, optional)
    - role_id (int, optional)
    - username (string)
    - email (string)
    - first_name (string, optional)
    - last_name (string, optional)
    - phone (string, optional)
    - preferred_language (string, optional)
    - secondary_language (string, optional)
    - max_allowed_devices (int)
    - is_locked (bool)
    - is_active (bool)
    - last_login (string (RFC3339 timestamp), optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/users

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateUserRequest**
  - username (string)
  - email (string)
  - password (string)
  - first_name (string, optional)
  - last_name (string, optional)
  - phone (string, optional)
  - role_id (int, optional)
  - location_id (int, optional)
  - company_id (int)
  - preferred_language (string, optional)
  - secondary_language (string, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (User)
    - user_id (int)
    - company_id (int, optional)
    - location_id (int, optional)
    - role_id (int, optional)
    - username (string)
    - email (string)
    - first_name (string, optional)
    - last_name (string, optional)
    - phone (string, optional)
    - preferred_language (string, optional)
    - secondary_language (string, optional)
    - max_allowed_devices (int)
    - is_locked (bool)
    - is_active (bool)
    - last_login (string (RFC3339 timestamp), optional)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/users/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateUserRequest**
  - first_name (string, optional)
  - last_name (string, optional)
  - phone (string, optional)
  - is_active (bool, optional)
  - is_locked (bool, optional)
  - role_id (int, optional)
  - location_id (int, optional)
  - preferred_language (string, optional)
  - secondary_language (string, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (User)
    - user_id (int)
    - company_id (int, optional)
    - location_id (int, optional)
    - role_id (int, optional)
    - username (string)
    - email (string)
    - first_name (string, optional)
    - last_name (string, optional)
    - phone (string, optional)
    - preferred_language (string, optional)
    - secondary_language (string, optional)
    - max_allowed_devices (int)
    - is_locked (bool)
    - is_active (bool)
    - last_login (string (RFC3339 timestamp), optional)
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
    - company_id (int, optional)
    - location_id (int, optional)
    - role_id (int, optional)
    - username (string)
    - email (string)
    - first_name (string, optional)
    - last_name (string, optional)
    - phone (string, optional)
    - preferred_language (string, optional)
    - secondary_language (string, optional)
    - max_allowed_devices (int)
    - is_locked (bool)
    - is_active (bool)
    - last_login (string (RFC3339 timestamp), optional)
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
  - data (array of Company)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/companies

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateCompanyRequest**
  - name (string)
  - logo (string, optional)
  - address (string, optional)
  - phone (string, optional)
  - email (string, optional)
  - tax_number (string, optional)
  - currency_id (int, optional)

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
  - name (string, optional)
  - logo (string, optional)
  - address (string, optional)
  - phone (string, optional)
  - email (string, optional)
  - tax_number (string, optional)
  - currency_id (int, optional)
  - is_active (bool, optional)

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
 - data (array of Location)
    - location_id (int)
    - company_id (int)
    - name (string)
    - address (string, optional)
    - phone (string, optional)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/locations

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateLocationRequest**
  - company_id (int)
  - name (string)
  - address (string, optional)
  - phone (string, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Location)
    - location_id (int)
    - company_id (int)
    - name (string)
    - address (string, optional)
    - phone (string, optional)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/locations/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateLocationRequest**
  - name (string, optional)
  - address (string, optional)
  - phone (string, optional)
  - is_active (bool, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Location)
    - location_id (int)
    - company_id (int)
    - name (string)
    - address (string, optional)
    - phone (string, optional)
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
    - address (string, optional)
    - phone (string, optional)
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
 - data (array of Role)
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
  - name (string)
  - description (string)

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
  - name (string, optional)
  - description (string, optional)

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
 - data (array of Permission)
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
  - permission_ids (array of int)

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
- data (array of Permission)
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
 - data (array of Product)
    - product_id (int)
    - company_id (int)
    - category_id (int, optional)
    - brand_id (int, optional)
    - unit_id (int, optional)
    - name (string)
    - sku (string, optional)
    - barcodes (array of ProductBarcode, optional)
    - description (string, optional)
    - cost_price (number, optional)
    - selling_price (number, optional)
    - reorder_level (int)
    - weight (number, optional)
    - dimensions (string, optional)
    - is_serialized (bool)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
    - attributes (array of ProductAttributeValue, optional)
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
    - category_id (int, optional)
    - brand_id (int, optional)
    - unit_id (int, optional)
    - name (string)
    - sku (string, optional)
    - barcodes (array of ProductBarcode, optional)
    - description (string, optional)
    - cost_price (number, optional)
    - selling_price (number, optional)
    - reorder_level (int)
    - weight (number, optional)
    - dimensions (string, optional)
    - is_serialized (bool)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
    - attributes (array of ProductAttributeValue, optional)
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
  - category_id (int, optional)
  - brand_id (int, optional)
  - unit_id (int, optional)
  - name (string)
  - sku (string, optional)
  - barcodes (array of ProductBarcode)
  - description (string, optional)
  - cost_price (number, optional)
  - selling_price (number, optional)
  - reorder_level (int)
  - weight (number, optional)
  - dimensions (string, optional)
  - is_serialized (bool)
  - attributes (object mapping int to string)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Product)
    - product_id (int)
    - company_id (int)
    - category_id (int, optional)
    - brand_id (int, optional)
    - unit_id (int, optional)
    - name (string)
    - sku (string, optional)
    - barcodes (array of ProductBarcode, optional)
    - description (string, optional)
    - cost_price (number, optional)
    - selling_price (number, optional)
    - reorder_level (int)
    - weight (number, optional)
    - dimensions (string, optional)
    - is_serialized (bool)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
    - attributes (array of ProductAttributeValue, optional)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/products/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateProductRequest**
  - category_id (int, optional)
  - brand_id (int, optional)
  - unit_id (int, optional)
  - name (string, optional)
  - sku (string, optional)
  - barcodes (array of ProductBarcode)
  - description (string, optional)
  - cost_price (number, optional)
  - selling_price (number, optional)
  - reorder_level (int, optional)
  - weight (number, optional)
  - dimensions (string, optional)
  - is_serialized (bool, optional)
  - is_active (bool, optional)
  - attributes (object mapping int to string)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Product)
    - product_id (int)
    - company_id (int)
    - category_id (int, optional)
    - brand_id (int, optional)
    - unit_id (int, optional)
    - name (string)
    - sku (string, optional)
    - barcodes (array of ProductBarcode, optional)
    - description (string, optional)
    - cost_price (number, optional)
    - selling_price (number, optional)
    - reorder_level (int)
    - weight (number, optional)
    - dimensions (string, optional)
    - is_serialized (bool)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
    - attributes (array of ProductAttributeValue, optional)
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
    - category_id (int, optional)
    - brand_id (int, optional)
    - unit_id (int, optional)
    - name (string)
    - sku (string, optional)
    - barcodes (array of ProductBarcode, optional)
    - description (string, optional)
    - cost_price (number, optional)
    - selling_price (number, optional)
    - reorder_level (int)
    - weight (number, optional)
    - dimensions (string, optional)
    - is_serialized (bool)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
    - attributes (array of ProductAttributeValue, optional)
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
 - data (array of Category)
    - category_id (int)
    - company_id (int)
    - name (string)
    - description (string, optional)
    - parent_id (int, optional)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/categories

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateCategoryRequest**
  - name (string)
  - description (string, optional)
  - parent_id (int, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Category)
    - category_id (int)
    - company_id (int)
    - name (string)
    - description (string, optional)
    - parent_id (int, optional)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/categories/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateCategoryRequest**
  - name (string, optional)
  - description (string, optional)
  - parent_id (int, optional)
  - is_active (bool, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Category)
    - category_id (int)
    - company_id (int)
    - name (string)
    - description (string, optional)
    - parent_id (int, optional)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
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
    - description (string, optional)
    - parent_id (int, optional)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
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
 - data (array of Brand)
    - brand_id (int)
    - company_id (int)
    - name (string)
    - description (string, optional)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/brands

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateBrandRequest**
  - name (string)
  - description (string, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Brand)
    - brand_id (int)
    - company_id (int)
    - name (string)
    - description (string, optional)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
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
 - data (array of Unit)
    - unit_id (int)
    - name (string)
    - symbol (string, optional)
    - base_unit_id (int, optional)
    - conversion_factor (number, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/units

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateUnitRequest**
  - name (string)
  - symbol (string, optional)
  - base_unit_id (int, optional)
  - conversion_factor (number, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Unit)
    - unit_id (int)
    - name (string)
    - symbol (string, optional)
    - base_unit_id (int, optional)
    - conversion_factor (number, optional)
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
    - options (string, optional)
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
    - options (string, optional)
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
    - options (string, optional)
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
    - options (string, optional)
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
    - quantity (number)
    - reserved_quantity (number)
    - last_updated (string (RFC3339 timestamp))
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/inventory/stock-adjustment

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateStockAdjustmentRequest**
  - product_id (int)
  - adjustment (number)
  - reason (string)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (StockAdjustment)
    - adjustment_id (int)
    - location_id (int)
    - product_id (int)
    - adjustment (number)
    - reason (string)
    - created_by (int)
    - created_at (string (RFC3339 timestamp))
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
    - adjustment (number)
    - reason (string)
    - created_by (int)
    - created_at (string (RFC3339 timestamp))
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
  - product_ids (array of int)

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
  - to_location_id (int)
  - notes (string, optional)
  - items (array of CreateStockTransferDetailRequest)

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
    - customer_id (int, optional)
    - sale_date (string (RFC3339 timestamp))
    - sale_time (string (RFC3339 timestamp), optional)
    - subtotal (number)
    - tax_amount (number)
    - discount_amount (number)
    - total_amount (number)
    - paid_amount (number)
    - payment_method_id (int, optional)
    - status (string)
    - pos_status (string)
    - is_quick_sale (bool)
    - notes (string, optional)
    - created_by (int)
    - updated_by (int, optional)
    - items (array of SaleDetail, optional)
    - customer (Customer, optional)
    - payment_method (PaymentMethod, optional)
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
    - customer_id (int, optional)
    - sale_date (string (RFC3339 timestamp))
    - sale_time (string (RFC3339 timestamp), optional)
    - subtotal (number)
    - tax_amount (number)
    - discount_amount (number)
    - total_amount (number)
    - paid_amount (number)
    - payment_method_id (int, optional)
    - status (string)
    - pos_status (string)
    - is_quick_sale (bool)
    - notes (string, optional)
    - created_by (int)
    - updated_by (int, optional)
    - items (array of SaleDetail, optional)
    - customer (Customer, optional)
    - payment_method (PaymentMethod, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/sales

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateSaleRequest**
  - customer_id (int, optional)
  - items (array of CreateSaleDetailRequest)
  - payment_method_id (int, optional)
  - paid_amount (number)
  - discount_amount (number)
  - notes (string, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Sale)
    - sale_id (int)
    - sale_number (string)
    - location_id (int)
    - customer_id (int, optional)
    - sale_date (string (RFC3339 timestamp))
    - sale_time (string (RFC3339 timestamp), optional)
    - subtotal (number)
    - tax_amount (number)
    - discount_amount (number)
    - total_amount (number)
    - paid_amount (number)
    - payment_method_id (int, optional)
    - status (string)
    - pos_status (string)
    - is_quick_sale (bool)
    - notes (string, optional)
    - created_by (int)
    - updated_by (int, optional)
    - items (array of SaleDetail, optional)
    - customer (Customer, optional)
    - payment_method (PaymentMethod, optional)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/sales/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateSaleRequest**
  - payment_method_id (int, optional)
  - notes (string, optional)
  - status (string, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Sale)
    - sale_id (int)
    - sale_number (string)
    - location_id (int)
    - customer_id (int, optional)
    - sale_date (string (RFC3339 timestamp))
    - sale_time (string (RFC3339 timestamp), optional)
    - subtotal (number)
    - tax_amount (number)
    - discount_amount (number)
    - total_amount (number)
    - paid_amount (number)
    - payment_method_id (int, optional)
    - status (string)
    - pos_status (string)
    - is_quick_sale (bool)
    - notes (string, optional)
    - created_by (int)
    - updated_by (int, optional)
    - items (array of SaleDetail, optional)
    - customer (Customer, optional)
    - payment_method (PaymentMethod, optional)
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
    - customer_id (int, optional)
    - sale_date (string (RFC3339 timestamp))
    - sale_time (string (RFC3339 timestamp), optional)
    - subtotal (number)
    - tax_amount (number)
    - discount_amount (number)
    - total_amount (number)
    - paid_amount (number)
    - payment_method_id (int, optional)
    - status (string)
    - pos_status (string)
    - is_quick_sale (bool)
    - notes (string, optional)
    - created_by (int)
    - updated_by (int, optional)
    - items (array of SaleDetail, optional)
    - customer (Customer, optional)
    - payment_method (PaymentMethod, optional)
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
  - items (array of CreateSaleDetailRequest)

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
    - customer_id (int, optional)
    - quote_date (string (RFC3339 timestamp))
    - valid_until (string (RFC3339 timestamp), optional)
    - subtotal (number)
    - tax_amount (number)
    - discount_amount (number)
    - total_amount (number)
    - status (string)
    - notes (string, optional)
    - created_by (int)
    - updated_by (int, optional)
    - items (array of QuoteItem, optional)
    - customer (Customer, optional)
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
    - customer_id (int, optional)
    - quote_date (string (RFC3339 timestamp))
    - valid_until (string (RFC3339 timestamp), optional)
    - subtotal (number)
    - tax_amount (number)
    - discount_amount (number)
    - total_amount (number)
    - status (string)
    - notes (string, optional)
    - created_by (int)
    - updated_by (int, optional)
    - items (array of QuoteItem, optional)
    - customer (Customer, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/sales/quotes

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateQuoteRequest**
  - customer_id (int, optional)
  - items (array of CreateQuoteItemRequest)
  - discount_amount (number)
  - valid_until (string (RFC3339 timestamp))
  - notes (string, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Quote)
    - quote_id (int)
    - quote_number (string)
    - location_id (int)
    - customer_id (int, optional)
    - quote_date (string (RFC3339 timestamp))
    - valid_until (string (RFC3339 timestamp), optional)
    - subtotal (number)
    - tax_amount (number)
    - discount_amount (number)
    - total_amount (number)
    - status (string)
    - notes (string, optional)
    - created_by (int)
    - updated_by (int, optional)
    - items (array of QuoteItem, optional)
    - customer (Customer, optional)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/sales/quotes/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateQuoteRequest**
  - status (string, optional)
  - notes (string, optional)
  - valid_until (string (RFC3339 timestamp), optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Quote)
    - quote_id (int)
    - quote_number (string)
    - location_id (int)
    - customer_id (int, optional)
    - quote_date (string (RFC3339 timestamp))
    - valid_until (string (RFC3339 timestamp), optional)
    - subtotal (number)
    - tax_amount (number)
    - discount_amount (number)
    - total_amount (number)
    - status (string)
    - notes (string, optional)
    - created_by (int)
    - updated_by (int, optional)
    - items (array of QuoteItem, optional)
    - customer (Customer, optional)
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
    - customer_id (int, optional)
    - quote_date (string (RFC3339 timestamp))
    - valid_until (string (RFC3339 timestamp), optional)
    - subtotal (number)
    - tax_amount (number)
    - discount_amount (number)
    - total_amount (number)
    - status (string)
    - notes (string, optional)
    - created_by (int)
    - updated_by (int, optional)
    - items (array of QuoteItem, optional)
    - customer (Customer, optional)
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
  - email (string)

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
    - category_id (int, optional)
    - brand_id (int, optional)
    - unit_id (int, optional)
    - name (string)
    - sku (string, optional)
    - barcodes (array of ProductBarcode, optional)
    - description (string, optional)
    - cost_price (number, optional)
    - selling_price (number, optional)
    - reorder_level (int)
    - weight (number, optional)
    - dimensions (string, optional)
    - is_serialized (bool)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
    - attributes (array of ProductAttributeValue, optional)
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
 - data (array of Customer)
    - customer_id (int)
    - company_id (int)
    - name (string)
    - phone (string, optional)
    - email (string, optional)
    - address (string, optional)
    - tax_number (string, optional)
    - credit_limit (number)
    - payment_terms (int)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
    - credit_balance (number, optional)
    - invoices (array of CustomerInvoiceReference, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/pos/checkout

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**POSCheckoutRequest**
  - customer_id (int, optional)
  - items (array of CreateSaleDetailRequest)
  - payment_method_id (int, optional)
  - discount_amount (number)
  - paid_amount (number)

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
  - invoice_id (int)

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
    - company_id (int, optional)
    - name (string)
    - type (string)
    - external_integration (JSONB, optional)
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
    - total_sales (number)
    - transactions (int)
    - outstanding (number)
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
    - points (number)
    - total_earned (number)
    - total_redeemed (number)
    - last_updated (string (RFC3339 timestamp))
    - customer (Customer, optional)
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
    - points (number)
    - total_earned (number)
    - total_redeemed (number)
    - last_updated (string (RFC3339 timestamp))
    - customer (Customer, optional)
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
    - sale_id (int, optional)
    - customer_id (int)
    - points_used (number)
    - value_redeemed (number)
    - redeemed_at (string (RFC3339 timestamp))
    - customer (Customer, optional)
    - sale (Sale, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/loyalty-redemptions

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateLoyaltyRedemptionRequest**
  - customer_id (int)
  - points_used (number)
  - reference (string, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (LoyaltyRedemption)
    - redemption_id (int)
    - sale_id (int, optional)
    - customer_id (int)
    - points_used (number)
    - value_redeemed (number)
    - redeemed_at (string (RFC3339 timestamp))
    - customer (Customer, optional)
    - sale (Sale, optional)
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
    - location_id (int, optional)
    - key (string)
    - value (JSONB)
    - description (string, optional)
    - data_type (string)
    - created_at (string (RFC3339 timestamp))
    - updated_at (string (RFC3339 timestamp))
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
    - description (string, optional)
    - discount_type (string, optional)
    - value (number, optional)
    - min_amount (number, optional)
    - start_date (string (RFC3339 timestamp))
    - end_date (string (RFC3339 timestamp))
    - applicable_to (string, optional)
    - conditions (JSONB, optional)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/promotions

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreatePromotionRequest**
  - name (string)
  - description (string, optional)
  - discount_type (string, optional)
  - value (number, optional)
  - min_amount (number, optional)
  - start_date (string)
  - end_date (string)
  - applicable_to (string, optional)
  - conditions (JSONB, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Promotion)
    - promotion_id (int)
    - company_id (int)
    - name (string)
    - description (string, optional)
    - discount_type (string, optional)
    - value (number, optional)
    - min_amount (number, optional)
    - start_date (string (RFC3339 timestamp))
    - end_date (string (RFC3339 timestamp))
    - applicable_to (string, optional)
    - conditions (JSONB, optional)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/promotions/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdatePromotionRequest**
  - name (string, optional)
  - description (string, optional)
  - discount_type (string, optional)
  - value (number, optional)
  - min_amount (number, optional)
  - start_date (string, optional)
  - end_date (string, optional)
  - applicable_to (string, optional)
  - conditions (JSONB, optional)
  - is_active (bool, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Promotion)
    - promotion_id (int)
    - company_id (int)
    - name (string)
    - description (string, optional)
    - discount_type (string, optional)
    - value (number, optional)
    - min_amount (number, optional)
    - start_date (string (RFC3339 timestamp))
    - end_date (string (RFC3339 timestamp))
    - applicable_to (string, optional)
    - conditions (JSONB, optional)
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
    - description (string, optional)
    - discount_type (string, optional)
    - value (number, optional)
    - min_amount (number, optional)
    - start_date (string (RFC3339 timestamp))
    - end_date (string (RFC3339 timestamp))
    - applicable_to (string, optional)
    - conditions (JSONB, optional)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/promotions/check-eligibility

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**PromotionEligibilityRequest**
  - customer_id (int, optional)
  - total_amount (number)
  - product_ids (array of int)
  - category_ids (array of int)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (PromotionEligibilityResponse)
    - eligible_promotions (array of struct)
    - promotion_id (int)
    - name (string)
    - discount_type (string)
    - value (number)
    - discount_amount (number)
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
    - eligible_promotions (array of struct)
    - promotion_id (int)
    - name (string)
    - discount_type (string)
    - value (number)
    - discount_amount (number)
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
    - customer_id (int, optional)
    - return_date (string (RFC3339 timestamp))
    - total_amount (number)
    - reason (string, optional)
    - status (string)
    - created_by (int)
    - items (array of SaleReturnDetail, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/sale-returns

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateSaleReturnRequest**
  - sale_id (int)
  - items (array of CreateSaleReturnItemRequest)
  - reason (string, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (SaleReturn)
    - return_id (int)
    - return_number (string)
    - sale_id (int)
    - location_id (int)
    - customer_id (int, optional)
    - return_date (string (RFC3339 timestamp))
    - total_amount (number)
    - reason (string, optional)
    - status (string)
    - created_by (int)
    - items (array of SaleReturnDetail, optional)
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
    - customer_id (int, optional)
    - return_date (string (RFC3339 timestamp))
    - total_amount (number)
    - reason (string, optional)
    - status (string)
    - created_by (int)
    - items (array of SaleReturnDetail, optional)
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
    - customer_id (int, optional)
    - return_date (string (RFC3339 timestamp))
    - total_amount (number)
    - reason (string, optional)
    - status (string)
    - created_by (int)
    - items (array of SaleReturnDetail, optional)
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
    - purchase_order_id (int, optional)
    - workflow_state_id (int, optional)
    - purchase_date (string (RFC3339 timestamp))
    - subtotal (number)
    - tax_amount (number)
    - discount_amount (number)
    - total_amount (number)
    - paid_amount (number)
    - payment_terms (int)
    - due_date (string (RFC3339 timestamp), optional)
    - status (string)
    - reference_number (string, optional)
    - notes (string, optional)
    - created_by (int)
    - updated_by (int, optional)
    - items (array of PurchaseDetail, optional)
    - goods_receipts (array of GoodsReceipt, optional)
    - supplier (Supplier, optional)
    - location (Location, optional)
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
    - purchase_order_id (int, optional)
    - workflow_state_id (int, optional)
    - purchase_date (string (RFC3339 timestamp))
    - subtotal (number)
    - tax_amount (number)
    - discount_amount (number)
    - total_amount (number)
    - paid_amount (number)
    - payment_terms (int)
    - due_date (string (RFC3339 timestamp), optional)
    - status (string)
    - reference_number (string, optional)
    - notes (string, optional)
    - created_by (int)
    - updated_by (int, optional)
    - items (array of PurchaseDetail, optional)
    - goods_receipts (array of GoodsReceipt, optional)
    - supplier (Supplier, optional)
    - location (Location, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/purchases

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreatePurchaseRequest**
  - supplier_id (int)
  - location_id (int, optional)
  - purchase_date (string (RFC3339 timestamp), optional)
  - reference_number (string, optional)
  - payment_terms (int, optional)
  - notes (string, optional)
  - items (array of CreatePurchaseDetailRequest)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Purchase)
    - purchase_id (int)
    - purchase_number (string)
    - location_id (int)
    - supplier_id (int)
    - purchase_order_id (int, optional)
    - workflow_state_id (int, optional)
    - purchase_date (string (RFC3339 timestamp))
    - subtotal (number)
    - tax_amount (number)
    - discount_amount (number)
    - total_amount (number)
    - paid_amount (number)
    - payment_terms (int)
    - due_date (string (RFC3339 timestamp), optional)
    - status (string)
    - reference_number (string, optional)
    - notes (string, optional)
    - created_by (int)
    - updated_by (int, optional)
    - items (array of PurchaseDetail, optional)
    - goods_receipts (array of GoodsReceipt, optional)
    - supplier (Supplier, optional)
    - location (Location, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/purchases/quick

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreatePurchaseRequest**
  - supplier_id (int)
  - location_id (int, optional)
  - purchase_date (string (RFC3339 timestamp), optional)
  - reference_number (string, optional)
  - payment_terms (int, optional)
  - notes (string, optional)
  - items (array of CreatePurchaseDetailRequest)

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
  - reference_number (string, optional)
  - payment_terms (int, optional)
  - notes (string, optional)
  - status (string, optional)
  - items (array of CreatePurchaseDetailRequest)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Purchase)
    - purchase_id (int)
    - purchase_number (string)
    - location_id (int)
    - supplier_id (int)
    - purchase_order_id (int, optional)
    - workflow_state_id (int, optional)
    - purchase_date (string (RFC3339 timestamp))
    - subtotal (number)
    - tax_amount (number)
    - discount_amount (number)
    - total_amount (number)
    - paid_amount (number)
    - payment_terms (int)
    - due_date (string (RFC3339 timestamp), optional)
    - status (string)
    - reference_number (string, optional)
    - notes (string, optional)
    - created_by (int)
    - updated_by (int, optional)
    - items (array of PurchaseDetail, optional)
    - goods_receipts (array of GoodsReceipt, optional)
    - supplier (Supplier, optional)
    - location (Location, optional)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/purchases/:id/receive

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**ReceivePurchaseRequest**
  - items (array of ReceivePurchaseItemRequest)

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
    - purchase_order_id (int, optional)
    - workflow_state_id (int, optional)
    - purchase_date (string (RFC3339 timestamp))
    - subtotal (number)
    - tax_amount (number)
    - discount_amount (number)
    - total_amount (number)
    - paid_amount (number)
    - payment_terms (int)
    - due_date (string (RFC3339 timestamp), optional)
    - status (string)
    - reference_number (string, optional)
    - notes (string, optional)
    - created_by (int)
    - updated_by (int, optional)
    - items (array of PurchaseDetail, optional)
    - goods_receipts (array of GoodsReceipt, optional)
    - supplier (Supplier, optional)
    - location (Location, optional)
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
    - order_date (string (RFC3339 timestamp))
    - status (string)
    - total_amount (number)
    - created_by (int)
    - workflow_state_id (int, optional)
    - items (array of PurchaseOrderItem, optional)
    - supplier (Supplier, optional)
    - location (Location, optional)
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
    - order_date (string (RFC3339 timestamp))
    - status (string)
    - total_amount (number)
    - created_by (int)
    - workflow_state_id (int, optional)
    - items (array of PurchaseOrderItem, optional)
    - supplier (Supplier, optional)
    - location (Location, optional)
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
    - order_date (string (RFC3339 timestamp))
    - status (string)
    - total_amount (number)
    - created_by (int)
    - workflow_state_id (int, optional)
    - items (array of PurchaseOrderItem, optional)
    - supplier (Supplier, optional)
    - location (Location, optional)
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
    - purchase_order_id (int, optional)
    - purchase_id (int, optional)
    - location_id (int)
    - supplier_id (int)
    - received_date (string (RFC3339 timestamp))
    - received_by (int)
    - workflow_state_id (int, optional)
    - items (array of GoodsReceiptItem, optional)
    - supplier (Supplier, optional)
    - location (Location, optional)
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
    - return_date (string (RFC3339 timestamp))
    - total_amount (number)
    - reason (string, optional)
    - status (string)
    - created_by (int)
    - approved_by (int, optional)
    - approved_at (string (RFC3339 timestamp), optional)
    - items (array of PurchaseReturnDetail, optional)
    - purchase (Purchase, optional)
    - supplier (Supplier, optional)
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
    - return_date (string (RFC3339 timestamp))
    - total_amount (number)
    - reason (string, optional)
    - status (string)
    - created_by (int)
    - approved_by (int, optional)
    - approved_at (string (RFC3339 timestamp), optional)
    - items (array of PurchaseReturnDetail, optional)
    - purchase (Purchase, optional)
    - supplier (Supplier, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/purchase-returns

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreatePurchaseReturnRequest**
  - purchase_id (int)
  - reason (string, optional)
  - items (array of CreatePurchaseReturnDetailRequest)

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
    - return_date (string (RFC3339 timestamp))
    - total_amount (number)
    - reason (string, optional)
    - status (string)
    - created_by (int)
    - approved_by (int, optional)
    - approved_at (string (RFC3339 timestamp), optional)
    - items (array of PurchaseReturnDetail, optional)
    - purchase (Purchase, optional)
    - supplier (Supplier, optional)
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
    - return_date (string (RFC3339 timestamp))
    - total_amount (number)
    - reason (string, optional)
    - status (string)
    - created_by (int)
    - approved_by (int, optional)
    - approved_at (string (RFC3339 timestamp), optional)
    - items (array of PurchaseReturnDetail, optional)
    - purchase (Purchase, optional)
    - supplier (Supplier, optional)
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
    - return_date (string (RFC3339 timestamp))
    - total_amount (number)
    - reason (string, optional)
    - status (string)
    - created_by (int)
    - approved_by (int, optional)
    - approved_at (string (RFC3339 timestamp), optional)
    - items (array of PurchaseReturnDetail, optional)
    - purchase (Purchase, optional)
    - supplier (Supplier, optional)
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
    - phone (string, optional)
    - email (string, optional)
    - address (string, optional)
    - tax_number (string, optional)
    - credit_limit (number)
    - payment_terms (int)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
    - credit_balance (number, optional)
    - invoices (array of CustomerInvoiceReference, optional)
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
  - name (string)
  - phone (string, optional)
  - email (string, optional)
  - address (string, optional)
  - tax_number (string, optional)
  - credit_limit (number)
  - payment_terms (int)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Customer)
    - customer_id (int)
    - company_id (int)
    - name (string)
    - phone (string, optional)
    - email (string, optional)
    - address (string, optional)
    - tax_number (string, optional)
    - credit_limit (number)
    - payment_terms (int)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
    - credit_balance (number, optional)
    - invoices (array of CustomerInvoiceReference, optional)
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
  - name (string, optional)
  - phone (string, optional)
  - email (string, optional)
  - address (string, optional)
  - tax_number (string, optional)
  - credit_limit (number, optional)
  - payment_terms (int, optional)
  - is_active (bool, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Customer)
    - customer_id (int)
    - company_id (int)
    - name (string)
    - phone (string, optional)
    - email (string, optional)
    - address (string, optional)
    - tax_number (string, optional)
    - credit_limit (number)
    - payment_terms (int)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
    - credit_balance (number, optional)
    - invoices (array of CustomerInvoiceReference, optional)
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
    - phone (string, optional)
    - email (string, optional)
    - address (string, optional)
    - tax_number (string, optional)
    - credit_limit (number)
    - payment_terms (int)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
    - credit_balance (number, optional)
    - invoices (array of CustomerInvoiceReference, optional)
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
  - amount (number)
  - type (string)
  - description (string, optional)

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
    - location_id (int, optional)
    - employee_code (string, optional)
    - name (string)
    - phone (string, optional)
    - email (string, optional)
    - address (string, optional)
    - position (string, optional)
    - department (string, optional)
    - salary (number, optional)
    - hire_date (string (RFC3339 timestamp), optional)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
    - last_check_in (string (RFC3339 timestamp), optional)
    - last_check_out (string (RFC3339 timestamp), optional)
    - leave_balance (number, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/employees

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateEmployeeRequest**
  - location_id (int, optional)
  - employee_code (string, optional)
  - name (string)
  - phone (string, optional)
  - email (string, optional)
  - address (string, optional)
  - position (string, optional)
  - department (string, optional)
  - salary (number, optional)
  - hire_date (string (RFC3339 timestamp), optional)
  - is_active (bool, optional)
  - leave_balance (number, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Employee)
    - employee_id (int)
    - company_id (int)
    - location_id (int, optional)
    - employee_code (string, optional)
    - name (string)
    - phone (string, optional)
    - email (string, optional)
    - address (string, optional)
    - position (string, optional)
    - department (string, optional)
    - salary (number, optional)
    - hire_date (string (RFC3339 timestamp), optional)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
    - last_check_in (string (RFC3339 timestamp), optional)
    - last_check_out (string (RFC3339 timestamp), optional)
    - leave_balance (number, optional)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/employees/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateEmployeeRequest**
  - location_id (int, optional)
  - employee_code (string, optional)
  - name (string, optional)
  - phone (string, optional)
  - email (string, optional)
  - address (string, optional)
  - position (string, optional)
  - department (string, optional)
  - salary (number, optional)
  - hire_date (string (RFC3339 timestamp), optional)
  - is_active (bool, optional)
  - leave_balance (number, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Employee)
    - employee_id (int)
    - company_id (int)
    - location_id (int, optional)
    - employee_code (string, optional)
    - name (string)
    - phone (string, optional)
    - email (string, optional)
    - address (string, optional)
    - position (string, optional)
    - department (string, optional)
    - salary (number, optional)
    - hire_date (string (RFC3339 timestamp), optional)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
    - last_check_in (string (RFC3339 timestamp), optional)
    - last_check_out (string (RFC3339 timestamp), optional)
    - leave_balance (number, optional)
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
    - location_id (int, optional)
    - employee_code (string, optional)
    - name (string)
    - phone (string, optional)
    - email (string, optional)
    - address (string, optional)
    - position (string, optional)
    - department (string, optional)
    - salary (number, optional)
    - hire_date (string (RFC3339 timestamp), optional)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
    - last_check_in (string (RFC3339 timestamp), optional)
    - last_check_out (string (RFC3339 timestamp), optional)
    - leave_balance (number, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/attendance/check-in

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CheckInRequest**
  - employee_id (int)

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
  - employee_id (int)

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
  - employee_id (int)
  - start_date (string)
  - end_date (string)
  - reason (string)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Leave)
    - leave_id (int)
    - employee_id (int)
    - start_date (string (RFC3339 timestamp))
    - end_date (string (RFC3339 timestamp))
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
    - date (string (RFC3339 timestamp))
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
    - pay_period_start (string (RFC3339 timestamp))
    - pay_period_end (string (RFC3339 timestamp))
    - basic_salary (number)
    - gross_salary (number)
    - total_deductions (number)
    - net_salary (number)
    - status (string)
    - processed_by (int, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/payrolls

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreatePayrollRequest**
  - employee_id (int)
  - month (string)
  - basic_salary (number)
  - allowances (number)
  - deductions (number)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Payroll)
    - payroll_id (int)
    - employee_id (int)
    - pay_period_start (string (RFC3339 timestamp))
    - pay_period_end (string (RFC3339 timestamp))
    - basic_salary (number)
    - gross_salary (number)
    - total_deductions (number)
    - net_salary (number)
    - status (string)
    - processed_by (int, optional)
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
  - type (string)
  - amount (number)

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
  - amount (number)
  - date (string)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Advance)
    - advance_id (int)
    - payroll_id (int)
    - amount (number)
    - date (string (RFC3339 timestamp))
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/payrolls/:id/deductions

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**DeductionRequest**
  - type (string)
  - amount (number)
  - date (string)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Deduction)
    - deduction_id (int)
    - payroll_id (int)
    - type (string)
    - amount (number)
    - date (string (RFC3339 timestamp))
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
    - components (array of SalaryComponent)
    - advances (array of Advance)
    - deductions (array of Deduction)
    - net_pay (number)
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
 - data (array of Collection)
    - collection_id (int)
    - collection_number (string)
    - customer_id (int)
    - location_id (int)
    - amount (number)
    - collection_date (string (RFC3339 timestamp))
    - payment_method_id (int, optional)
    - payment_method (string, optional)
    - reference_number (string, optional)
    - notes (string, optional)
    - created_by (int)
    - sync_status (string)
    - created_at (string (RFC3339 timestamp))
    - updated_at (string (RFC3339 timestamp))
    - invoices (array of CollectionInvoice, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/collections

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateCollectionRequest**
  - customer_id (int)
  - amount (number)
  - payment_method_id (int, optional)
  - received_date (string, optional)
  - reference_number (string, optional)
  - notes (string, optional)
  - invoices (array of CollectionInvoiceRequest)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Collection)
    - collection_id (int)
    - collection_number (string)
    - customer_id (int)
    - location_id (int)
    - amount (number)
    - collection_date (string (RFC3339 timestamp))
    - payment_method_id (int, optional)
    - payment_method (string, optional)
    - reference_number (string, optional)
    - notes (string, optional)
    - created_by (int)
    - sync_status (string)
    - created_at (string (RFC3339 timestamp))
    - updated_at (string (RFC3339 timestamp))
    - invoices (array of CollectionInvoice, optional)
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
    - amount (number)
    - collection_date (string (RFC3339 timestamp))
    - payment_method_id (int, optional)
    - payment_method (string, optional)
    - reference_number (string, optional)
    - notes (string, optional)
    - created_by (int)
    - sync_status (string)
    - created_at (string (RFC3339 timestamp))
    - updated_at (string (RFC3339 timestamp))
    - invoices (array of CollectionInvoice, optional)
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
    - amount (number)
    - notes (string, optional)
    - expense_date (string (RFC3339 timestamp))
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
    - amount (number)
    - notes (string, optional)
    - expense_date (string (RFC3339 timestamp))
    - created_by (int)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/expenses

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateExpenseRequest**
  - category_id (int)
  - amount (number)
  - notes (string, optional)
  - expense_date (string (RFC3339 timestamp))

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Expense)
    - expense_id (int)
    - category_id (int)
    - location_id (int)
    - amount (number)
    - notes (string, optional)
    - expense_date (string (RFC3339 timestamp))
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
  - name (string)

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
    - amount (number)
    - date (string (RFC3339 timestamp))
    - account_id (int)
    - reference (string)
    - description (string, optional)
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
    - amount (number)
    - date (string (RFC3339 timestamp))
    - account_id (int)
    - reference (string)
    - description (string, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/vouchers/:type

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateVoucherRequest**
  - account_id (int)
  - amount (number)
  - reference (string)
  - description (string, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Voucher)
    - voucher_id (int)
    - company_id (int)
    - type (string)
    - amount (number)
    - date (string (RFC3339 timestamp))
    - account_id (int)
    - reference (string)
    - description (string, optional)
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
    - date (string (RFC3339 timestamp))
    - opening_balance (number)
    - closing_balance (number, optional)
    - expected_balance (number)
    - cash_in (number)
    - cash_out (number)
    - variance (number)
    - opened_by (int, optional)
    - closed_by (int, optional)
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
    - total_sales (number)
    - transactions (int)
    - outstanding (number)
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
    - quantity (number)
    - stock_value (number)
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
    - product_id (int, optional)
    - product_name (string)
    - quantity_sold (number)
    - revenue (number)
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
    - total_due (number)
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
    - total_amount (number)
    - period (string, optional)
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
    - contact_person (string, optional)
    - phone (string, optional)
    - email (string, optional)
    - address (string, optional)
    - tax_number (string, optional)
    - payment_terms (int)
    - credit_limit (number)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
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
    - percentage (number)
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
    - contact_person (string, optional)
    - phone (string, optional)
    - email (string, optional)
    - address (string, optional)
    - tax_number (string, optional)
    - payment_terms (int)
    - credit_limit (number)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
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
    - contact_person (string, optional)
    - phone (string, optional)
    - email (string, optional)
    - address (string, optional)
    - tax_number (string, optional)
    - payment_terms (int)
    - credit_limit (number)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/suppliers

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateSupplierRequest**
  - name (string)
  - contact_person (string, optional)
  - phone (string, optional)
  - email (string, optional)
  - address (string, optional)
  - tax_number (string, optional)
  - payment_terms (int, optional)
  - credit_limit (number, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Supplier)
    - supplier_id (int)
    - company_id (int)
    - name (string)
    - contact_person (string, optional)
    - phone (string, optional)
    - email (string, optional)
    - address (string, optional)
    - tax_number (string, optional)
    - payment_terms (int)
    - credit_limit (number)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/suppliers/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateSupplierRequest**
  - name (string, optional)
  - contact_person (string, optional)
  - phone (string, optional)
  - email (string, optional)
  - address (string, optional)
  - tax_number (string, optional)
  - payment_terms (int, optional)
  - credit_limit (number, optional)
  - is_active (bool, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Supplier)
    - supplier_id (int)
    - company_id (int)
    - name (string)
    - contact_person (string, optional)
    - phone (string, optional)
    - email (string, optional)
    - address (string, optional)
    - tax_number (string, optional)
    - payment_terms (int)
    - credit_limit (number)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
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
    - contact_person (string, optional)
    - phone (string, optional)
    - email (string, optional)
    - address (string, optional)
    - tax_number (string, optional)
    - payment_terms (int)
    - credit_limit (number)
    - is_active (bool)
    - created_by (int)
    - updated_by (int, optional)
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
  - code (string)
  - name (string)
  - symbol (string, optional)
  - exchange_rate (number)
  - is_base_currency (bool)

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
  - code (string, optional)
  - name (string, optional)
  - symbol (string, optional)
  - exchange_rate (number, optional)
  - is_base_currency (bool, optional)

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
  - code (string, optional)
  - name (string, optional)
  - symbol (string, optional)
  - exchange_rate (number, optional)
  - is_base_currency (bool, optional)

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
  - name (string)
  - percentage (number)
  - is_compound (bool)
  - is_active (bool)

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
  - name (string, optional)
  - percentage (number, optional)
  - is_compound (bool, optional)
  - is_active (bool, optional)

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
    - location_id (int, optional)
    - key (string)
    - value (JSONB)
    - description (string, optional)
    - data_type (string)
    - created_at (string (RFC3339 timestamp))
    - updated_at (string (RFC3339 timestamp))
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/settings

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateSettingsRequest**
  - settings (map[string]JSONB)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Setting)
    - setting_id (int)
    - company_id (int)
    - location_id (int, optional)
    - key (string)
    - value (JSONB)
    - description (string, optional)
    - data_type (string)
    - created_at (string (RFC3339 timestamp))
    - updated_at (string (RFC3339 timestamp))
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
    - logo (string, optional)
    - address (string, optional)
    - phone (string, optional)
    - email (string, optional)
    - tax_number (string, optional)
    - currency_id (int, optional)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/settings/company

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CompanySettings**
  - name (string)
  - address (string, optional)
  - phone (string, optional)
  - email (string, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Company)
    - company_id (int)
    - name (string)
    - logo (string, optional)
    - address (string, optional)
    - phone (string, optional)
    - email (string, optional)
    - tax_number (string, optional)
    - currency_id (int, optional)
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
  - prefix (string, optional)
  - next_number (int, optional)
  - notes (string, optional)

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
    - percentage (number)
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
  - tax_name (string, optional)
  - tax_percent (number, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Tax)
    - tax_id (int)
    - company_id (int)
    - name (string)
    - percentage (number)
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
  - allow_remote (bool)

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
  - max_sessions (int)

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
  - max_sessions (int)

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
    - company_id (int, optional)
    - name (string)
    - type (string)
    - external_integration (JSONB, optional)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/settings/payment-methods

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**PaymentMethodRequest**
  - name (string)
  - type (string)
  - external_integration (JSONB, optional)
  - is_active (bool)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (PaymentMethod)
    - method_id (int)
    - company_id (int, optional)
    - name (string)
    - type (string)
    - external_integration (JSONB, optional)
    - is_active (bool)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/settings/payment-methods/:id

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**PaymentMethodRequest**
  - name (string)
  - type (string)
  - external_integration (JSONB, optional)
  - is_active (bool)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (PaymentMethod)
    - method_id (int)
    - company_id (int, optional)
    - name (string)
    - type (string)
    - external_integration (JSONB, optional)
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
    - company_id (int, optional)
    - name (string)
    - type (string)
    - external_integration (JSONB, optional)
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
  - printer_id (int)
  - company_id (int)
  - location_id (int, optional)
  - name (string)
  - printer_type (string)
  - paper_size (string, optional)
  - connectivity (JSONB, optional)
  - is_default (bool)
  - is_active (bool)

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
  - printer_id (int)
  - company_id (int)
  - location_id (int, optional)
  - name (string)
  - printer_type (string)
  - paper_size (string, optional)
  - connectivity (JSONB, optional)
  - is_default (bool)
  - is_active (bool)

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
    - user_id (int, optional)
    - action (string)
    - table_name (string)
    - record_id (int, optional)
    - old_value (JSONB, optional)
    - new_value (JSONB, optional)
    - field_changes (JSONB, optional)
    - ip_address (string, optional)
    - user_agent (string, optional)
    - timestamp (string (RFC3339 timestamp))
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
    - created_at (string (RFC3339 timestamp))
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
    - context (string, optional)
    - created_at (string (RFC3339 timestamp))
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/translations

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**UpdateTranslationsRequest**
  - lang (string)
  - strings (map[string]string)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (Translation)
    - translation_id (int)
    - key (string)
    - language_code (string)
    - value (string)
    - context (string, optional)
    - created_at (string (RFC3339 timestamp))
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
    - location_id (int, optional)
    - name (string)
    - prefix (string, optional)
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
    - location_id (int, optional)
    - name (string)
    - prefix (string, optional)
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
    - location_id (int, optional)
    - name (string)
    - prefix (string, optional)
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
    - location_id (int, optional)
    - name (string)
    - prefix (string, optional)
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
    - location_id (int, optional)
    - name (string)
    - prefix (string, optional)
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
    - primary_language (string, optional)
    - secondary_language (string, optional)
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
    - primary_language (string, optional)
    - secondary_language (string, optional)
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
    - primary_language (string, optional)
    - secondary_language (string, optional)
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
    - primary_language (string, optional)
    - secondary_language (string, optional)
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
    - primary_language (string, optional)
    - secondary_language (string, optional)
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
  - type (string)
  - reference_id (int)

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
    - remarks (string, optional)
    - approved_at (string (RFC3339 timestamp), optional)
    - created_by (int)
    - updated_by (int, optional)
  - error (string, optional)
  - meta (object, optional)

## POST /api/v1/workflow-requests

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**CreateWorkflowRequest**
  - state_id (int)
  - approver_role_id (int)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
- data (WorkflowRequest)
    - approval_id (int)
    - state_id (int)
    - approver_role_id (int)
    - status (string)
    - remarks (string, optional)
    - approved_at (string (RFC3339 timestamp), optional)
    - created_by (int)
    - updated_by (int, optional)
  - error (string, optional)
  - meta (object, optional)

## PUT /api/v1/workflow-requests/:id/approve

### Headers
- Authorization: Bearer <token>
- Content-Type: application/json

### Request Body
**DecisionRequest**
  - remarks (string, optional)

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
  - remarks (string, optional)

### Response
Standard `APIResponse` with fields:
  - success (bool)
  - message (string)
  - data (object)
  - error (string, optional)
  - meta (object, optional)
