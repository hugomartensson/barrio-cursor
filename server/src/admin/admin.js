(() => {
  const TOKEN_KEY = 'portal_admin_token';

  const getToken = () => sessionStorage.getItem(TOKEN_KEY);

  const login = async (email, password) => {
    const response = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    const json = await response.json();
    if (!response.ok || !json.data?.token) {
      throw new Error(json.error?.message || 'Login failed');
    }
    sessionStorage.setItem(TOKEN_KEY, json.data.token);
    return json.data.token;
  };

  const fetchJson = async (path, options = {}) => {
    const token = getToken();
    if (!token) throw new Error('Please login first');
    const response = await fetch(`/api${path}`, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
        ...(options.headers || {}),
      },
    });
    const json = await response.json();
    if (!response.ok) {
      throw new Error(json.error?.message || `Request failed (${response.status})`);
    }
    return json;
  };

  window.adminApi = {
    login,
    fetchJson,
    hasToken: () => Boolean(getToken()),
  };
})();
