import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const token = request.cookies.get('accessToken')?.value;
  if (!token) {
    return NextResponse.redirect(new URL('/login', request.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: [
    '/dashboard/:path*',
    '/sales/:path*',
    '/purchases/:path*',
    '/inventory/:path*',
    '/reports/:path*',
    '/accounting/:path*',
    '/hr/:path*',
    '/company-create',
  ],
};
