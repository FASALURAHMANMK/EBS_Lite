# Next Frontend Web

## Environment Variables

The application requires the following environment variables to be set:

- `NEXT_PUBLIC_API_URL` – Base URL used by the client for API requests.
- `API_PROXY_URL` – URL used by Next.js rewrites to proxy `/api/*` calls to the backend. Defaults to `NEXT_PUBLIC_API_URL` if not set.

Define these variables in your environment or in a `.env` file before running or building the project. For example:

```
NEXT_PUBLIC_API_URL=http://localhost:8080/api/v1
API_PROXY_URL=http://localhost:8080
NEXT_PUBLIC_AUTH_REDIRECT=http://localhost:3000/auth/callback
```
