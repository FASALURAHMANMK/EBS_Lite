# Next Frontend Web

## Prerequisites

- Node.js 18 or later and npm 9 or later
- For Electron packaging, ensure native build tools are available for your platform (e.g., Xcode on macOS, `build-essential` on Linux, or Visual Studio Build Tools on Windows)

## Installation

From the repository root:

```bash
cd next_frontend_web
npm install
```

## Environment Configuration

The application requires the following environment variables to be set:

- `NEXT_PUBLIC_API_URL` – Base URL used by the client for API requests.
- `API_PROXY_URL` – URL used by Next.js rewrites to proxy `/api/*` calls to the backend. Defaults to `NEXT_PUBLIC_API_URL` if not set.
- `NEXT_PUBLIC_AUTH_REDIRECT` – Redirect URL for authentication callbacks.

Define these variables in your environment or in a `.env` file before running or building the project. For example:

```env
NEXT_PUBLIC_API_URL=http://localhost:8080/api/v1
API_PROXY_URL=http://localhost:8080
NEXT_PUBLIC_AUTH_REDIRECT=http://localhost:3000/auth/callback
```

## Deployment

This project runs with server-side rendering due to its use of internationalization. To create a production build, run `npm run build` and then launch the application with `npm start`. Ensure the environment variables above are configured in your hosting environment.
=======
## Development Server

Start the application in watch mode:

```bash
npm run dev
```

For Electron development with a desktop window:

```bash
npm run electron-dev
```

## Production Build

Create an optimized build and run it with Node.js:

```bash
npm run build
npm start
```

## Electron Packaging

Build a distributable Electron application:

```bash
npm run electron-pack
```

This command runs `next build` and then packages the app using `electron-builder`.

## Testing and Linting

The continuous integration pipeline runs tests and linting using these commands:

```bash
npm test      # run unit tests
npm run lint  # run ESLint
```

## Troubleshooting

- Verify all required environment variables are defined; missing values often cause runtime errors.
- If the development server fails to start, ensure port 3000 is free or set a different `PORT` value.
- Lint failures list files and rules that need attention; run `npm run lint` and fix the reported issues.
