const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || '';

interface RequestOptions extends RequestInit {
  auth?: boolean;
}

async function request<T>(endpoint: string, options: RequestOptions = {}): Promise<T> {
  const { auth = true, headers, body, ...rest } = options;

  const config: RequestInit = {
    ...rest,
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      ...(headers || {}),
    },
    body: body ? (typeof body === 'string' ? body : JSON.stringify(body)) : undefined,
  };

  if (auth && typeof window !== 'undefined') {
    const token = localStorage.getItem('token');
    if (token) {
      (config.headers as Record<string, string>)['Authorization'] = `Bearer ${token}`;
    }
  }

  const response = await fetch(`${API_BASE_URL}${endpoint}`, config);

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
    // No Content
    return null as unknown as T;
  }

  return (await response.json()) as T;
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
