(() => {
  const TOKEN_KEY = 'portal_token';

  const getToken = () => localStorage.getItem(TOKEN_KEY);

  const parseJsonSafe = async (response) => {
    const text = await response.text();
    if (!text) return {};
    try { return JSON.parse(text); }
    catch { throw new Error(`Non-JSON response (${response.status})`); }
  };

  const login = async (email, password) => {
    if (!email || !password) throw new Error('Email and password are required.');
    const response = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    const json = await parseJsonSafe(response);
    if (!response.ok || !json.data?.token) {
      throw new Error(json.error?.message || 'Login failed — check email/password.');
    }
    localStorage.setItem(TOKEN_KEY, json.data.token);
    return json.data;
  };

  const fetchJson = async (path, options = {}) => {
    const token = getToken();
    if (!token) throw new Error('Not logged in.');
    const response = await fetch(`/api${path}`, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
        ...(options.headers || {}),
      },
    });
    const json = await parseJsonSafe(response);
    if (!response.ok) {
      if (response.status === 401) {
        localStorage.removeItem(TOKEN_KEY);
        throw new Error('Session expired — please log in again.');
      }
      throw new Error(json.error?.message || `Request failed (${response.status})`);
    }
    return json;
  };

  const logout = () => localStorage.removeItem(TOKEN_KEY);

  window.adminApi = { login, fetchJson, logout, hasToken: () => Boolean(getToken()) };
})();
