(() => {
  const TOKEN_KEY = 'portal_token';

  const getToken = () => localStorage.getItem(TOKEN_KEY);

  const parseJsonSafe = async (response) => {
    const text = await response.text();
    if (!text) return {};
    try {
      return JSON.parse(text);
    } catch {
      throw new Error(
        `Server returned non-JSON (${response.status}). You may be on the wrong URL or the API is down.`
      );
    }
  };

  const errMsg = (e) => (e instanceof Error ? e.message : String(e));

  const login = async (email, password) => {
    if (!email || !password) {
      throw new Error('Enter your email address and password (use email, not your display name).');
    }
    let response;
    try {
      response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
    } catch (e) {
      throw new Error(
        `Network error: ${errMsg(e)}. Check your connection and that this page URL matches your API (same site).`
      );
    }
    const json = await parseJsonSafe(response);
    if (!response.ok || !json.data?.token) {
      throw new Error(json.error?.message || `Login failed (HTTP ${response.status}).`);
    }
    localStorage.setItem(TOKEN_KEY, json.data.token);
    return json.data;
  };

  const fetchJson = async (path, options = {}) => {
    const token = getToken();
    if (!token) throw new Error('Not logged in — use Log in first.');
    let response;
    try {
      response = await fetch(`/api${path}`, {
        ...options,
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
          ...(options.headers || {}),
        },
      });
    } catch (e) {
      throw new Error(`Network error while loading data: ${errMsg(e)}`);
    }
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
