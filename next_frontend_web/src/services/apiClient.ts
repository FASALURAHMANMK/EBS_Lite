const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

let accessToken: string | null = null;
let refreshToken: string | null = null;
let companyId: string | null = null;
let locationId: string | null = null;

const getCookie = (name: string): string | null => {
  if (typeof document === 'undefined') return null;
  const match = document.cookie.match(new RegExp('(?:^|; )' + name + '=([^;]*)'));
  return match ? decodeURIComponent(match[1]) : null;
};

const setCookie = (name: string, value: string, days = 7) => {
  if (typeof document === 'undefined') return;
  const expires = new Date(Date.now() + days * 864e5).toUTCString();
  const isSecure =
    typeof window !== 'undefined' && window.location.protocol === 'https:';
  document.cookie = `${name}=${encodeURIComponent(value)}; expires=${expires}; path=/; SameSite=Strict${isSecure ? '; secure' : ''}`;
};

const deleteCookie = (name: string) => {
  if (typeof document === 'undefined') return;
  document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/;`;
};

if (typeof window !== 'undefined') {
  accessToken = getCookie('accessToken');
  refreshToken = getCookie('refreshToken');
}

export const setAuthTokens = ({
  accessToken: newAccess,
  refreshToken: newRefresh,
}: {
  accessToken: string;
  refreshToken: string;
}) => {
  accessToken = newAccess;
  refreshToken = newRefresh;
  setCookie('accessToken', newAccess);
  setCookie('refreshToken', newRefresh, 30);
};

export const clearAuthTokens = () => {
  accessToken = null;
  refreshToken = null;
  deleteCookie('accessToken');
  deleteCookie('refreshToken');
};

export const setCompanyLocation = (
  company: string | null,
  location: string | null
) => {
  companyId = company;
  locationId = location;
};

const toSnakeCase = (obj: any): any => {
  if (Array.isArray(obj)) return obj.map(toSnakeCase);
  if (obj && typeof obj === 'object') {
    return Object.fromEntries(
      Object.entries(obj).map(([key, value]) => [
        key.replace(/[A-Z]/g, (l) => `_${l.toLowerCase()}`),
        toSnakeCase(value),
      ])
    );
  }
  return obj;
};

const toCamelCase = (obj: any): any => {
  if (Array.isArray(obj)) return obj.map(toCamelCase);
  if (obj && typeof obj === 'object') {
    return Object.fromEntries(
      Object.entries(obj).map(([key, value]) => [
        key.replace(/_([a-z])/g, (_, g) => g.toUpperCase()),
        toCamelCase(value),
      ])
    );
  }
  return obj;
};

interface RequestOptions extends RequestInit {
  auth?: boolean;
}

async function request<T>(endpoint: string, options: RequestOptions = {}): Promise<T> {
  const { auth = true, headers, body, ...rest } = options;

  const config: RequestInit = {
    credentials: 'include',
    ...rest,
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      ...(headers || {}),
    },
    body: body
      ? typeof body === 'string'
        ? body
        : JSON.stringify(toSnakeCase(body))
      : undefined,
  };

  if (auth && accessToken) {
    (config.headers as Record<string, string>)['Authorization'] = `Bearer ${accessToken}`;
  }
  if (companyId) {
    (config.headers as Record<string, string>)['company_id'] = companyId;
  }
  if (locationId) {
    (config.headers as Record<string, string>)['location_id'] = locationId;
  }

  let response = await fetch(`${API_BASE_URL}${endpoint}`, config);

  if (response.status === 401 && auth && refreshToken) {
    const refreshResponse = await fetch(`${API_BASE_URL}/api/v1/auth/refresh-token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ refreshToken }),
    });

    if (refreshResponse.ok) {
      const tokens = (await refreshResponse.json()) as {
        accessToken: string;
        refreshToken: string;
      };
      setAuthTokens(tokens);
      (config.headers as Record<string, string>)['Authorization'] = `Bearer ${tokens.accessToken}`;
      response = await fetch(`${API_BASE_URL}${endpoint}`, config);
    } else {
      clearAuthTokens();
    }
  }

  if (!response.ok) {
    let errorMessage = response.statusText;
    try {
      const errorData = await response.json();
      errorMessage = errorData.message || errorMessage;
    } catch (err) {
      // ignore JSON parse errors
    }
    throw new Error(errorMessage);
  }

  if (response.status === 204) {
    return null as unknown as T;
  }

  const data = await response.json();
  return toCamelCase(data) as T;
}

const apiClient = {
  get: <T>(url: string, options?: RequestOptions) => request<T>(url, { ...options, method: 'GET' }),
  post: <T>(url: string, data?: any, options?: RequestOptions) =>
    request<T>(url, { ...options, method: 'POST', body: data }),
  put: <T>(url: string, data?: any, options?: RequestOptions) =>
    request<T>(url, { ...options, method: 'PUT', body: data }),
  patch: <T>(url: string, data?: any, options?: RequestOptions) =>
    request<T>(url, { ...options, method: 'PATCH', body: data }),
  delete: <T>(url: string, options?: RequestOptions) =>
    request<T>(url, { ...options, method: 'DELETE' }),
};

export default apiClient;
export { accessToken, refreshToken };
