# ERP System API Documentation (Go Backend)

This document defines all API endpoints required for the ERP system backend written in Go. It includes request/response formats, purpose, required headers, and detailed behavior for each endpoint. The API supports both online and offline-first operation modes and is structured by modules.

---

## 🔐 Authentication & Authorization

### `POST /auth/login`

**Purpose:** Authenticate user and return JWT tokens.

**Headers:**

* `Content-Type: application/json`

**Request Body:**

```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response:**

```json
{
  "access_token": "...",
  "refresh_token": "...",
  "user": {
    "user_id": 1,
    "username": "admin",
    "role_id": 1,
    "location_id": 2,
    "company_id": 1
  }
}
```

### `POST /auth/logout`

**Purpose:** Invalidate user session.

**Headers:**

* `Authorization: Bearer <access_token>`

**Request Body:** Empty

**Response:**

```json
{
  "message": "Logout successful"
}
```

### `POST /auth/refresh-token`

**Purpose:** Refresh access token using refresh token.

**Request Body:**

```json
{
  "refresh_token": "..."
}
```

**Response:**

```json
{
  "access_token": "..."
}
```

### `GET /auth/me`

**Purpose:** Get logged-in user details.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "user_id": 1,
  "username": "admin",
  "email": "admin@example.com",
  "role_id": 1,
  "location_id": 2,
  "company_id": 1,
  "permissions": ["VIEW_DASHBOARD", "CREATE_SALES"]
}
```

### `POST /auth/forgot-password`

**Purpose:** Send password reset link or OTP.

**Request Body:**

```json
{
  "email": "user@example.com"
}
```

**Response:**

```json
{
  "message": "Password reset instructions sent"
}
```

### `POST /auth/reset-password`

**Purpose:** Reset password using OTP or token.

**Request Body:**

```json
{
  "email": "user@example.com",
  "reset_code": "123456",
  "new_password": "newSecurePassword"
}
```

**Response:**

```json
{
  "message": "Password successfully reset"
}
```

---

## 👤 User Management

### `GET /users`

**Purpose:** Get list of all users (admin access only).

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `company_id`: Optional
* `location_id`: Optional

**Response:**

```json
[
  {
    "user_id": 1,
    "username": "admin",
    "email": "admin@example.com",
    "role_id": 1,
    "is_active": true,
    "is_locked": false,
    "location_id": 2,
    "company_id": 1
  }
]
```

### `POST /users`

**Purpose:** Create new user.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "username": "john",
  "email": "john@example.com",
  "password": "password123",
  "role_id": 2,
  "location_id": 3,
  "company_id": 1
}
```

**Response:**

```json
{
  "message": "User created",
  "user_id": 7
}
```

### `PUT /users/:id`

**Purpose:** Update user profile or status.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body (example):**

```json
{
  "is_active": false,
  "is_locked": true
}
```

**Response:**

```json
{
  "message": "User updated"
}
```

### `DELETE /users/:id`

**Purpose:** Soft delete a user.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "message": "User deleted"
}
```

---

## 🔑 Roles & Permissions

### `GET /roles`

**Purpose:** Retrieve all system roles.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
[
  {
    "role_id": 1,
    "name": "Admin",
    "description": "Full access"
  },
  {
    "role_id": 2,
    "name": "Manager",
    "description": "Manages users and sales"
  }
]
```

### `POST /roles`

**Purpose:** Create a new role.

**Headers:**

* `Authorization: Bearer <access_token>`

**Request Body:**

```json
{
  "name": "Store",
  "description": "Basic store-level role"
}
```

**Response:**

```json
{
  "message": "Role created",
  "role_id": 3
}
```

### `PUT /roles/:id`

**Purpose:** Update a role’s name or description.

**Headers:**

* `Authorization: Bearer <access_token>`

**Request Body:**

```json
{
  "name": "Sales",
  "description": "Handles sales and invoices"
}
```

**Response:**

```json
{
  "message": "Role updated"
}
```

### `DELETE /roles/:id`

**Purpose:** Delete a role.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "message": "Role deleted"
}
```

### `GET /permissions`

**Purpose:** Retrieve full list of permissions.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
[
  {
    "permission_id": 1,
    "name": "VIEW_DASHBOARD",
    "module": "dashboard",
    "action": "view"
  },
  {
    "permission_id": 2,
    "name": "CREATE_SALES",
    "module": "sales",
    "action": "create"
  }
]
```

### `POST /roles/:id/permissions`

**Purpose:** Assign permissions to a role.

**Headers:**

* `Authorization: Bearer <access_token>`

**Request Body:**

```json
{
  "permission_ids": [1, 2, 3]
}
```

**Response:**

```json
{
  "message": "Permissions assigned"
}
```

### `GET /roles/:id/permissions`

**Purpose:** Get all permissions assigned to a role.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "role_id": 1,
  "permissions": [
    {
      "permission_id": 1,
      "name": "VIEW_DASHBOARD"
    },
    {
      "permission_id": 2,
      "name": "CREATE_SALES"
    }
  ]
}
```


## 🏢 Companies & Locations

### `GET /companies`

**Purpose:** Retrieve all companies (admin access only).

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
[
  {
    "company_id": 1,
    "name": "Acme Corp",
    "logo": "https://example.com/logo.png",
    "address": "123 Main St",
    "currency_id": 2
  }
]
```

### `POST /companies`

**Purpose:** Create a new company.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "name": "Acme Corp",
  "logo": "https://example.com/logo.png",
  "address": "123 Main St",
  "currency_id": 2
}
```

**Response:**

```json
{
  "message": "Company created",
  "company_id": 1
}
```

### `PUT /companies/:id`

**Purpose:** Update an existing company’s details.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "address": "456 Updated Ave"
}
```

**Response:**

```json
{
  "message": "Company updated"
}
```

### `DELETE /companies/:id`

**Purpose:** Delete a company (soft delete recommended).

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "message": "Company deleted"
}
```

---

### `GET /locations`

**Purpose:** Retrieve all locations.

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `company_id`: Optional

**Response:**

```json
[
  {
    "location_id": 1,
    "company_id": 1,
    "name": "Downtown Branch",
    "address": "789 Market Road"
  }
]
```

### `POST /locations`

**Purpose:** Create a new location.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "company_id": 1,
  "name": "Downtown Branch",
  "address": "789 Market Road"
}
```

**Response:**

```json
{
  "message": "Location created",
  "location_id": 1
}
```

### `PUT /locations/:id`

**Purpose:** Update location details.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "address": "999 New Address St"
}
```

**Response:**

```json
{
  "message": "Location updated"
}
```

### `DELETE /locations/:id`

**Purpose:** Soft delete a location.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "message": "Location deleted"
}
```

## 📦 Products & Inventory

### `GET /products`

**Purpose:** Retrieve list of all products with optional filters.

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `category_id`: Optional
* `brand_id`: Optional
* `is_active`: Optional

**Response:**

```json
[
  {
    "product_id": 101,
    "name": "Wireless Mouse",
    "barcode": "123456789",
    "category_id": 3,
    "brand_id": 2,
    "unit": "pcs",
    "cost_price": 10.50,
    "selling_price": 15.00,
    "reorder_level": 5,
    "sync_status": "synced"
  }
]
```

### `POST /products`

**Purpose:** Create a new product.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "company_id": 1,
  "name": "Wireless Mouse",
  "category_id": 3,
  "brand_id": 2,
  "barcode": "123456789",
  "unit": "pcs",
  "cost_price": 10.50,
  "selling_price": 15.00,
  "reorder_level": 5
}
```

**Response:**

```json
{
  "message": "Product created",
  "product_id": 101
}
```

### `PUT /products/:id`

**Purpose:** Update an existing product’s information.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body (example):**

```json
{
  "selling_price": 16.00,
  "reorder_level": 8
}
```

**Response:**

```json
{
  "message": "Product updated"
}
```

### `DELETE /products/:id`

**Purpose:** Soft delete a product.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "message": "Product deleted"
}
```

---

### `GET /categories`

**Purpose:** Retrieve all product categories.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
[
  {
    "category_id": 1,
    "name": "Electronics"
  }
]
```

### `POST /categories`

**Purpose:** Create a new category.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "company_id": 1,
  "name": "Electronics"
}
```

**Response:**

```json
{
  "message": "Category created",
  "category_id": 1
}
```

---

### `GET /brands`

**Purpose:** Retrieve all product brands.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
[
  {
    "brand_id": 1,
    "name": "LogiTech"
  }
]
```

### `POST /brands`

**Purpose:** Create a new brand.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "company_id": 1,
  "name": "LogiTech"
}
```

**Response:**

```json
{
  "message": "Brand created",
  "brand_id": 1
}
```

---

### `GET /units`

**Purpose:** Retrieve all units of measurement.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
[
  { "unit_id": 1, "name": "Kilogram", "symbol": "kg" },
  { "unit_id": 2, "name": "Pieces", "symbol": "pcs" }
]
```

### `POST /units`

**Purpose:** Create a new unit of measurement.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "name": "Liters",
  "symbol": "L"
}
```

**Response:**

```json
{
  "message": "Unit created",
  "unit_id": 3
}
```

---

### `GET /stock`

**Purpose:** Retrieve current stock levels per location and product.

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `location_id`: Required
* `product_id`: Optional

**Response:**

```json
[
  {
    "product_id": 101,
    "location_id": 2,
    "quantity": 40,
    "last_updated": "2025-08-03T12:00:00Z"
  }
]
```

### `POST /stock-adjustment`

**Purpose:** Manually adjust stock levels.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "location_id": 2,
  "product_id": 101,
  "adjustment": -5,
  "reason": "Inventory correction"
}
```

**Response:**

```json
{
  "message": "Stock adjusted"
}
```

## 🛒 Sales & POS

### `GET /sales`

**Purpose:** Retrieve all sales records with optional filters.

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `date_from`: Optional (ISO format)
* `date_to`: Optional (ISO format)
* `customer_id`: Optional

**Response:**

```json
[
  {
    "sale_id": 1001,
    "customer_id": 23,
    "location_id": 2,
    "sale_date": "2025-08-03",
    "total_amount": 150.00,
    "status": "completed"
  }
]
```

### `GET /sales/:id`

**Purpose:** Retrieve detailed info about a specific sale.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "sale_id": 1001,
  "customer_id": 23,
  "location_id": 2,
  "sale_date": "2025-08-03",
  "items": [
    {
      "product_id": 101,
      "quantity": 2,
      "unit_price": 15.00,
      "total_price": 30.00
    }
  ],
  "total_amount": 150.00,
  "payment_method": "cash",
  "status": "completed"
}
```

### `POST /sales`

**Purpose:** Create a new sale with line items.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "customer_id": 23,
  "location_id": 2,
  "items": [
    {
      "product_id": 101,
      "quantity": 2,
      "unit_price": 15.00
    }
  ],
  "payment_method": "cash"
}
```

**Response:**

```json
{
  "message": "Sale recorded",
  "sale_id": 1001
}
```

### `PUT /sales/:id`

**Purpose:** Update sale record if not finalized.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "payment_method": "card"
}
```

**Response:**

```json
{
  "message": "Sale updated"
}
```

### `DELETE /sales/:id`

**Purpose:** Cancel or void a sale before sync/finalization.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "message": "Sale deleted"
}
```

### `POST /sales/:id/hold`

**Purpose:** Temporarily hold a sale to be resumed later.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "message": "Sale held"
}
```

### `POST /sales/:id/resume`

**Purpose:** Resume a previously held sale.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "message": "Sale resumed"
}
```

### `POST /sales/quick`

**Purpose:** Create a quick sale with minimal fields.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "items": [
    {
      "product_id": 101,
      "quantity": 1
    }
  ]
}
```

**Response:**

```json
{
  "message": "Quick sale completed",
  "sale_id": 1002
}
```

### `GET /pos/products`

**Purpose:** Retrieve product data optimized for POS terminals.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
[
  {
    "product_id": 101,
    "name": "Wireless Mouse",
    "price": 15.00,
    "stock": 35
  }
]
```

### `GET /pos/customers`

**Purpose:** Retrieve customer list for POS.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
[
  {
    "customer_id": 23,
    "name": "John Doe",
    "phone": "1234567890"
  }
]
```

### `POST /pos/checkout`

**Purpose:** Complete a POS transaction and generate invoice.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "items": [
    {
      "product_id": 101,
      "quantity": 1,
      "unit_price": 15.00
    }
  ],
  "payment_method": "cash",
  "customer_id": 23
}
```

**Response:**

```json
{
  "message": "Transaction complete",
  "invoice_id": 9001
}
```

### `POST /pos/print`

**Purpose:** Trigger POS printer to print a specific invoice.

**Headers:**

* `Authorization: Bearer <access_token>`

**Request Body:**

```json
{
  "invoice_id": 9001
}
```

**Response:**

```json
{
  "message": "Invoice sent to printer"
}
```


## 🔄 Sale Returns, Loyalty & Promotions

### `GET /sale-returns`

**Purpose:** Retrieve all sale return records.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
[
  {
    "return_id": 201,
    "sale_id": 1001,
    "customer_id": 23,
    "return_date": "2025-08-03",
    "total_refund": 30.00
  }
]
```

### `POST /sale-returns`

**Purpose:** Submit a return request for a completed sale.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "sale_id": 1001,
  "items": [
    {
      "product_id": 101,
      "quantity": 1,
      "refund_amount": 15.00
    }
  ],
  "reason": "Product defect"
}
```

**Response:**

```json
{
  "message": "Sale return recorded",
  "return_id": 201
}
```

### `GET /loyalty-programs`

**Purpose:** List all loyalty programs.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
[
  {
    "program_id": 1,
    "name": "Gold Tier",
    "points_per_currency": 1,
    "min_purchase": 100,
    "expires_in_days": 365
  }
]
```

### `POST /loyalty-redemptions`

**Purpose:** Redeem loyalty points for a customer.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "customer_id": 23,
  "points_used": 100,
  "reference": "INV-1001"
}
```

**Response:**

```json
{
  "message": "Points redeemed successfully"
}
```

### `GET /promotions`

**Purpose:** List active promotions.

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `date`: Optional (ISO format)

**Response:**

```json
[
  {
    "promotion_id": 5,
    "name": "Buy 1 Get 1",
    "start_date": "2025-08-01",
    "end_date": "2025-08-15",
    "details": "Applies to select electronics"
  }
]
```

### `POST /promotions`

**Purpose:** Create a new promotion.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "name": "Buy 1 Get 1",
  "start_date": "2025-08-01",
  "end_date": "2025-08-15",
  "details": "Applies to select electronics"
}
```

**Response:**

```json
{
  "message": "Promotion created",
  "promotion_id": 5
}
```

## 🔁 Inventory Transfers & Stock Movement

### `GET /transfers`

**Purpose:** Retrieve all inventory transfers between locations.

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `source_location_id`: Optional
* `destination_location_id`: Optional
* `status`: Optional (e.g., pending, completed)

**Response:**

```json
[
  {
    "transfer_id": 301,
    "source_location_id": 1,
    "destination_location_id": 2,
    "transfer_date": "2025-08-03",
    "status": "completed",
    "items": [
      {
        "product_id": 101,
        "quantity": 10
      }
    ]
  }
]
```

### `POST /transfers`

**Purpose:** Initiate a new inventory transfer.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "source_location_id": 1,
  "destination_location_id": 2,
  "items": [
    {
      "product_id": 101,
      "quantity": 10
    }
  ]
}
```

**Response:**

```json
{
  "message": "Transfer initiated",
  "transfer_id": 301
}
```

### `PUT /transfers/:id/complete`

**Purpose:** Mark a transfer as completed and update destination stock.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "message": "Transfer marked as completed"
}
```

### `DELETE /transfers/:id`

**Purpose:** Cancel a pending transfer request.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "message": "Transfer cancelled"
}
```


## 📥 Purchases & Purchase Returns

### `GET /purchases`

**Purpose:** Retrieve all purchase records with optional filters.

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `supplier_id`: Optional
* `date_from`: Optional
* `date_to`: Optional

**Response:**

```json
[
  {
    "purchase_id": 501,
    "supplier_id": 12,
    "location_id": 3,
    "invoice_number": "INV-2025-001",
    "purchase_date": "2025-08-01",
    "total_amount": 220.50,
    "status": "received"
  }
]
```

### `POST /purchases`

**Purpose:** Record a new purchase.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "supplier_id": 12,
  "location_id": 3,
  "invoice_number": "INV-2025-001",
  "purchase_date": "2025-08-01",
  "items": [
    {
      "product_id": 101,
      "quantity": 10,
      "unit_cost": 20.00
    }
  ]
}
```

**Response:**

```json
{
  "message": "Purchase recorded",
  "purchase_id": 501
}
```

### `PUT /purchases/:id`

**Purpose:** Update a purchase before confirmation.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "invoice_number": "INV-2025-002"
}
```

**Response:**

```json
{
  "message": "Purchase updated"
}
```

### `DELETE /purchases/:id`

**Purpose:** Cancel or delete a purchase (if not finalized).

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "message": "Purchase deleted"
}
```

---

### `GET /purchase-returns`

**Purpose:** Retrieve all purchase return records.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
[
  {
    "return_id": 601,
    "purchase_id": 501,
    "return_date": "2025-08-02",
    "items": [
      {
        "product_id": 101,
        "quantity": 2,
        "refund_amount": 40.00
      }
    ]
  }
]
```

### `POST /purchase-returns`

**Purpose:** Return items from a purchase.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "purchase_id": 501,
  "items": [
    {
      "product_id": 101,
      "quantity": 2,
      "refund_amount": 40.00
    }
  ],
  "reason": "Damaged goods"
}
```

**Response:**

```json
{
  "message": "Purchase return recorded",
  "return_id": 601
}
```


## 🚚 Suppliers & Customer Collections

### `GET /suppliers`

**Purpose:** Retrieve list of all suppliers.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
[
  {
    "supplier_id": 12,
    "name": "Tech Traders",
    "phone": "9876543210",
    "email": "supplier@example.com",
    "address": "456 Supplier Ave",
    "company_id": 1
  }
]
```

### `POST /suppliers`

**Purpose:** Add a new supplier.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "name": "Tech Traders",
  "phone": "9876543210",
  "email": "supplier@example.com",
  "address": "456 Supplier Ave",
  "company_id": 1
}
```

**Response:**

```json
{
  "message": "Supplier created",
  "supplier_id": 12
}
```

### `PUT /suppliers/:id`

**Purpose:** Update supplier details.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "address": "New Supplier Address"
}
```

**Response:**

```json
{
  "message": "Supplier updated"
}
```

### `DELETE /suppliers/:id`

**Purpose:** Soft delete a supplier.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "message": "Supplier deleted"
}
```

---

### `GET /collections`

**Purpose:** Retrieve collection records from customers.

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `customer_id`: Optional
* `date_from`: Optional
* `date_to`: Optional

**Response:**

```json
[
  {
    "collection_id": 801,
    "customer_id": 23,
    "amount": 150.00,
    "payment_method": "cash",
    "received_date": "2025-08-03",
    "reference": "SALE-1001"
  }
]
```

### `POST /collections`

**Purpose:** Record a payment collected from a customer.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "customer_id": 23,
  "amount": 150.00,
  "payment_method": "cash",
  "received_date": "2025-08-03",
  "reference": "SALE-1001"
}
```

**Response:**

```json
{
  "message": "Collection recorded",
  "collection_id": 801
}
```

### `DELETE /collections/:id`

**Purpose:** Delete a collection record.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "message": "Collection deleted"
}
```

## 👥 Customers, Expenses & Cash Register

### `GET /customers`

**Purpose:** Retrieve all customers.

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `search`: Optional string filter by name or phone

**Response:**

```json
[
  {
    "customer_id": 23,
    "name": "John Doe",
    "phone": "1234567890",
    "email": "john@example.com",
    "address": "123 Elm St",
    "loyalty_points": 120
  }
]
```

### `POST /customers`

**Purpose:** Add a new customer.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "name": "John Doe",
  "phone": "1234567890",
  "email": "john@example.com",
  "address": "123 Elm St"
}
```

**Response:**

```json
{
  "message": "Customer created",
  "customer_id": 23
}
```

### `PUT /customers/:id`

**Purpose:** Update customer information.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "email": "new-email@example.com"
}
```

**Response:**

```json
{
  "message": "Customer updated"
}
```

### `DELETE /customers/:id`

**Purpose:** Soft delete a customer.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "message": "Customer deleted"
}
```

---

### `GET /expenses`

**Purpose:** Retrieve expense records.

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `date_from`: Optional
* `date_to`: Optional

**Response:**

```json
[
  {
    "expense_id": 1001,
    "amount": 45.00,
    "category": "Travel",
    "note": "Taxi fare",
    "created_by": 1,
    "created_at": "2025-08-02T10:00:00Z"
  }
]
```

### `POST /expenses`

**Purpose:** Record a new expense.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "amount": 45.00,
  "category": "Travel",
  "note": "Taxi fare"
}
```

**Response:**

```json
{
  "message": "Expense recorded",
  "expense_id": 1001
}
```

### `DELETE /expenses/:id`

**Purpose:** Delete an expense record.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "message": "Expense deleted"
}
```

---

### `GET /cash-registers`

**Purpose:** View open/close history of cash registers.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
[
  {
    "register_id": 1,
    "opened_by": 2,
    "opening_balance": 100.00,
    "status": "open",
    "opened_at": "2025-08-03T09:00:00Z"
  }
]
```

### `POST /cash-registers/open`

**Purpose:** Open a new cash register session.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "opening_balance": 100.00
}
```

**Response:**

```json
{
  "message": "Cash register opened",
  "register_id": 1
}
```

### `POST /cash-registers/close`

**Purpose:** Close the current cash register session.

**Headers:**

* `Authorization: Bearer <access_token>`

**Request Body:**

```json
{
  "closing_balance": 250.00
}
```

**Response:**

```json
{
  "message": "Cash register closed"
}
```

## 📊 Reports

### `GET /reports/sales-summary`

**Purpose:** Retrieve total sales data grouped by day/month/year.

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `from_date`: Optional (ISO)
* `to_date`: Optional (ISO)
* `group_by`: Required (e.g., `day`, `month`, `year`)

**Response:**

```json
[
  {
    "period": "2025-08-01",
    "total_sales": 3500.00,
    "transactions": 28
  }
]
```

### `GET /reports/stock-summary`

**Purpose:** Get stock levels and values by location or product.

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `location_id`: Optional
* `product_id`: Optional

**Response:**

```json
[
  {
    "product_id": 101,
    "location_id": 2,
    "quantity": 30,
    "stock_value": 450.00
  }
]
```

### `GET /reports/top-products`

**Purpose:** Get top-selling products within a date range.

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `from_date`: Optional
* `to_date`: Optional
* `limit`: Optional (default 10)

**Response:**

```json
[
  {
    "product_id": 101,
    "product_name": "Wireless Mouse",
    "quantity_sold": 120,
    "revenue": 1800.00
  }
]
```

### `GET /reports/customer-balances`

**Purpose:** Get outstanding balances of customers.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
[
  {
    "customer_id": 23,
    "name": "John Doe",
    "total_due": 90.00
  }
]
```

### `GET /reports/expenses-summary`

**Purpose:** View expenses grouped by category and period.

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `group_by`: Optional (`category`, `day`, `month`)

**Response:**

```json
[
  {
    "category": "Travel",
    "total_amount": 120.00,
    "period": "2025-08"
  }
]
```


## 🧑‍💼 HR & Payroll

### `GET /employees`

**Purpose:** List all employees with optional filters.

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `department`: Optional
* `status`: Optional (`active`, `inactive`)

**Response:**

```json
[
  {
    "employee_id": 1,
    "name": "Jane Smith",
    "designation": "Cashier",
    "status": "active",
    "phone": "9876543210"
  }
]
```

### `POST /employees`

**Purpose:** Create a new employee record.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "name": "Jane Smith",
  "designation": "Cashier",
  "phone": "9876543210",
  "email": "jane@example.com",
  "status": "active"
}
```

**Response:**

```json
{
  "message": "Employee created",
  "employee_id": 1
}
```

### `PUT /employees/:id`

**Purpose:** Update an existing employee's record.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body (example):**

```json
{
  "designation": "Senior Cashier",
  "status": "inactive"
}
```

**Response:**

```json
{
  "message": "Employee updated"
}
```

### `DELETE /employees/:id`

**Purpose:** Remove an employee (soft delete).

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "message": "Employee deleted"
}
```

### `GET /payrolls`

**Purpose:** View payroll records.

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `employee_id`: Optional
* `month`: Optional (e.g., `2025-08`)

**Response:**

```json
[
  {
    "payroll_id": 9001,
    "employee_id": 1,
    "month": "2025-08",
    "net_salary": 1500.00,
    "status": "paid"
  }
]
```

### `POST /payrolls`

**Purpose:** Generate a new payroll entry.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "employee_id": 1,
  "month": "2025-08",
  "basic_salary": 1200.00,
  "allowances": 300.00,
  "deductions": 0.00
}
```

**Response:**

```json
{
  "message": "Payroll generated",
  "payroll_id": 9001
}
```

### `PUT /payrolls/:id/mark-paid`

**Purpose:** Mark a payroll as paid.

**Headers:**

* `Authorization: Bearer <access_token>`

**Response:**

```json
{
  "message": "Payroll marked as paid"
}
```

## ✅ Workflow & Approvals

### `GET /workflow-requests`

**Purpose:** List all pending workflow approval requests.

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `status`: Optional (`pending`, `approved`, `rejected`)
* `module`: Optional (e.g., `purchase`, `leave`, `voucher`)

**Response:**

```json
[
  {
    "request_id": 301,
    "type": "purchase",
    "reference_id": 501,
    "status": "pending",
    "requested_by": 12,
    "requested_at": "2025-08-01T10:30:00Z"
  }
]
```

### `POST /workflow-requests`

**Purpose:** Submit a new approval request for a workflow.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "type": "purchase",
  "reference_id": 501,
  "note": "Requires manager approval"
}
```

**Response:**

```json
{
  "message": "Approval request submitted",
  "request_id": 301
}
```

### `PUT /workflow-requests/:id/approve`

**Purpose:** Approve a pending workflow request.

**Headers:**

* `Authorization: Bearer <access_token>`

**Request Body (optional):**

```json
{
  "note": "Approved after review"
}
```

**Response:**

```json
{
  "message": "Request approved"
}
```

### `PUT /workflow-requests/:id/reject`

**Purpose:** Reject a workflow request.

**Headers:**

* `Authorization: Bearer <access_token>`

**Request Body (optional):**

```json
{
  "note": "Insufficient documentation"
}
```

**Response:**

```json
{
  "message": "Request rejected"
}
```

---

## 🔄 Sync Engine (Offline Support)

### `POST /sync/upload`

**Purpose:** Upload changes from the local (offline) database to the server.

**Headers:**

* `Authorization: Bearer <access_token>`
* `Content-Type: application/json`

**Request Body:**

```json
{
  "tables": {
    "sales": [
      {
        "sale_id": "local-uuid-1",
        "customer_id": 23,
        "total": 150.00,
        "sale_date": "2025-08-03T12:00:00Z",
        "items": [
          { "product_id": 101, "quantity": 2, "price": 75.00 }
        ]
      }
    ],
    "collections": [
      {
        "collection_id": "local-uuid-2",
        "customer_id": 23,
        "amount": 150.00,
        "payment_method": "cash",
        "received_date": "2025-08-03"
      }
    ]
  }
}
```

**Response:**

```json
{
  "message": "Data synced successfully",
  "synced_ids": {
    "sales": { "local-uuid-1": 1001 },
    "collections": { "local-uuid-2": 2001 }
  }
}
```

### `GET /sync/download`

**Purpose:** Download latest changes from the server to local storage (used during offline app re-entry).

**Headers:**

* `Authorization: Bearer <access_token>`

**Query Parameters:**

* `last_sync_at`: Optional ISO timestamp (e.g., `2025-08-01T10:00:00Z`)

**Response:**

```json
{
  "sales": [ ... ],
  "customers": [ ... ],
  "products": [ ... ],
  "inventory": [ ... ],
  "collections": [ ... ]
}
```
---

## ⚙️ Settings, Audit Logs, Translations & Printing

### `GET /settings`
**Purpose:** Retrieve global system configuration settings.

**Headers:**
- `Authorization: Bearer <access_token>`

**Response:**
```json
{
  "currency": "USD",
  "timezone": "Asia/Kolkata",
  "date_format": "YYYY-MM-DD",
  "print_logo_url": "https://example.com/logo.png"
}
```

### `PUT /settings`
**Purpose:** Update system-wide configuration values.

**Headers:**
- `Authorization: Bearer <access_token>`
- `Content-Type: application/json`

**Request Body:**
```json
{
  "currency": "INR",
  "timezone": "Asia/Kolkata"
}
```

**Response:**
```json
{
  "message": "Settings updated"
}
```

---

### `GET /audit-logs`
**Purpose:** View logs of user/system actions for traceability.

**Headers:**
- `Authorization: Bearer <access_token>`

**Query Parameters:**
- `user_id`: Optional
- `action`: Optional
- `from_date`: Optional
- `to_date`: Optional

**Response:**
```json
[
  {
    "log_id": 1,
    "user_id": 2,
    "action": "created_sale",
    "entity": "sales",
    "entity_id": 101,
    "timestamp": "2025-08-03T12:00:00Z"
  }
]
```

---

### `GET /translations`
**Purpose:** Retrieve all translation strings for localization.

**Headers:**
- `Authorization: Bearer <access_token>`

**Query Parameters:**
- `lang`: Optional (default: `en`)

**Response:**
```json
{
  "hello": "Hello",
  "welcome": "Welcome",
  "logout": "Logout"
}
```

### `PUT /translations`
**Purpose:** Update translation strings for a given language.

**Headers:**
- `Authorization: Bearer <access_token>`
- `Content-Type: application/json`

**Request Body:**
```json
{
  "lang": "fr",
  "strings": {
    "hello": "Bonjour",
    "logout": "Se déconnecter"
  }
}
```

**Response:**
```json
{
  "message": "Translations updated"
}
```

---

### `POST /print/receipt`
**Purpose:** Trigger printing of a formatted receipt.

**Headers:**
- `Authorization: Bearer <access_token>`
- `Content-Type: application/json`

**Request Body:**
```json
{
  "type": "sale",
  "reference_id": 1001
}
```

**Response:**
```json
{
  "message": "Print command sent"
}
```

---

✅ **ERP API Documentation Complete**
