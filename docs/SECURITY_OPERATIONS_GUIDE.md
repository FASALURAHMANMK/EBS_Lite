# EBS Lite Security Operations Guide

Date: 2026-03-30

## 1. Implemented SMB controls

- Short-lived elevated verification is required for security-sensitive settings changes.
- Password policy is configurable per company and enforced on registration and password reset.
- Inactive device sessions are revoked server-side using the configured idle timeout.
- Request IDs, upload validation, session revocation, and Redis-backed rate limiting remain part of the backend baseline.

## 2. Admin step-up guidance

Use `Settings > Security` for:
- password policy
- session limits
- remote device-control posture
- session idle timeout and elevated access window

When saving these changes:
- an admin must re-enter valid credentials
- the backend issues a short-lived step-up token
- the token is accepted only for the company and required permissions

This is the repo’s SMB-level equivalent elevated-operation protection.

## 3. Password policy guidance

Recommended launch baseline:
- minimum length: 10
- require uppercase
- require lowercase
- require number
- require special character

Do not weaken policy below the documented launch baseline without commercial sign-off.

## 4. Session policy guidance

Recommended launch baseline:
- max sessions: set per role or deployment expectation
- idle timeout: 480 minutes for back-office operators, lower only if the customer explicitly wants tighter control
- elevated access window: 5 minutes

Effects:
- inactive sessions are rejected on protected routes
- operators can revoke sessions from the device sessions page

## 5. Production secrets and config guidance

Required:
- strong non-default `JWT_SECRET`
- real `FRONTEND_BASE_URL`
- explicit production `API_BASE_URL` for packaged Flutter builds
- non-empty `ALLOWED_ORIGINS` without `*`
- Redis configured when rate limiting and readiness checks depend on it

The backend now refuses production startup when these controls are misconfigured.

## 6. Rate-limiting fallback posture

Production recommendation:
- keep `RATE_LIMIT_ENABLED=true`
- set `RATE_LIMIT_FAIL_OPEN=false`
- keep Redis reachable and monitored

Reason:
- fail-open can silently remove protection during Redis failure
- fail-closed is safer for a customer-facing deployment and should be paired with monitoring

## 7. CORS and origin deployment guidance

Use exact origins only, for example:

```text
ALLOWED_ORIGINS=https://app.example.com,https://admin.example.com
```

Do not use:
- `*`
- localhost origins in production
- broad development hostnames in shared environments

## 8. Support bundle guidance

Operator bundle:
- generated from Flutter settings
- includes app version, platform, outbox state, failed queue items, and backend diagnostics when reachable

Backend bundle:
- available at `GET /api/v1/support/bundle`
- disabled in production unless `SUPPORT_BUNDLE_ENABLED=true`
- includes readiness state, sanitized logs, config posture, and production-readiness issues
