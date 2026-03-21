/**
 * Portal admin: API helpers + queue + draft pages in ONE file.
 * Reason: second script (queue.js) was often missing on deploy / 404 → zero UI behavior.
 * Helmet CSP blocks inline scripts; this file is always copied to dist/admin.
 */
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

/* ---------- Ingest queue (/admin/) ---------- */
(function initQueuePage() {
  const loginBtn = document.getElementById('loginBtn');
  if (!loginBtn) return;

  function showBootFatal(msg) {
    const el = document.getElementById('boot-fatal');
    if (el) {
      el.classList.add('visible');
      el.textContent = msg;
    }
  }

  if (!window.adminApi || typeof window.adminApi.login !== 'function') {
    showBootFatal('Portal admin script failed to initialize. Hard-refresh the page.');
    return;
  }

  const $status = document.getElementById('status');
  const $list = document.getElementById('list');
  const $count = document.getElementById('count');
  const $loginSection = document.getElementById('login-section');
  const $loggedInSection = document.getElementById('logged-in-section');
  const $loginBtn = loginBtn;
  const $refreshBtn = document.getElementById('refreshBtn');
  const $email = document.getElementById('email');
  const $password = document.getElementById('password');

  if (!$status || !$list || !$count || !$loginSection || !$loggedInSection || !$refreshBtn || !$email || !$password) {
    showBootFatal('Page markup is incomplete. Redeploy the API so /admin/index.html is up to date.');
    return;
  }

  function showStatus(kind, text) {
    $status.hidden = false;
    $status.className = kind;
    $status.textContent = text;
  }

  function hideStatus() {
    $status.hidden = true;
    $status.className = '';
    $status.textContent = '';
  }

  function errText(e) {
    return e && e.message ? e.message : String(e);
  }

  function setLoginBusy(busy) {
    $loginBtn.disabled = busy;
    $email.disabled = busy;
    $password.disabled = busy;
    $loginBtn.textContent = busy ? 'Signing in…' : 'Log in';
  }

  function setRefreshBusy(busy) {
    $refreshBtn.disabled = busy;
    $refreshBtn.textContent = busy ? 'Loading…' : 'Refresh';
  }

  function showLoggedIn(label) {
    $loginSection.style.display = 'none';
    $loggedInSection.style.display = 'flex';
    const ul = document.getElementById('user-label');
    if (ul) ul.textContent = label || 'Logged in';
  }

  function showLoggedOut() {
    $loginSection.style.display = 'flex';
    $loggedInSection.style.display = 'none';
    $count.textContent = '—';
    $list.innerHTML = '';
  }

  function render(drafts) {
    $count.textContent = `${drafts.length} draft${drafts.length !== 1 ? 's' : ''} pending`;
    $list.innerHTML = drafts
      .map((d) => {
        const flagged = Array.isArray(d.flaggedFields) ? d.flaggedFields.length : 0;
        return `<div class="card" data-id="${d.id}">
          <div class="title">${d.name || 'Unnamed'}</div>
          <div class="meta">
            <span class="pill">${d.itemType || '?'}</span>
            <span>${d.category || 'no category'}</span>
            <span>${new Date(d.createdAt).toLocaleString()}</span>
            ${flagged ? `<span class="pill warn">${flagged} flagged</span>` : ''}
          </div>
        </div>`;
      })
      .join('');
    document.querySelectorAll('.card').forEach((el) => {
      el.addEventListener('click', () => {
        window.location.href = `/admin/draft.html?id=${el.getAttribute('data-id')}`;
      });
    });
  }

  function loadDrafts() {
    showStatus('loading', 'Loading drafts…');
    return window.adminApi.fetchJson('/ingest/drafts').then((res) => {
      const drafts = res.data || [];
      render(drafts);
      if (!drafts.length) {
        showStatus(
          'ok',
          'Loaded successfully. No pending drafts.\n\nTip: send a link (https://…) to your Telegram bot to create one.'
        );
      } else {
        showStatus('ok', `Loaded ${drafts.length} draft(s). Click a row to review.`);
      }
    });
  }

  $loginBtn.addEventListener('click', () => {
    hideStatus();
    setLoginBusy(true);
    showStatus('loading', 'Contacting server…\n\nPOST /api/auth/login');
    window.adminApi
      .login($email.value.trim(), $password.value)
      .then((data) => {
        showLoggedIn(data.user && (data.user.email || data.user.name));
        showStatus('loading', 'Signed in. Loading drafts…');
        return loadDrafts();
      })
      .catch((e) => {
        showStatus('error', errText(e));
      })
      .finally(() => {
        setLoginBusy(false);
      });
  });

  $password.addEventListener('keydown', (ev) => {
    if (ev.key === 'Enter') $loginBtn.click();
  });

  $refreshBtn.addEventListener('click', () => {
    setRefreshBusy(true);
    loadDrafts()
      .catch((e) => {
        showStatus('error', errText(e));
        showLoggedOut();
      })
      .finally(() => {
        setRefreshBusy(false);
      });
  });

  const logoutBtn = document.getElementById('logoutBtn');
  if (logoutBtn) {
    logoutBtn.addEventListener('click', () => {
      window.adminApi.logout();
      showLoggedOut();
      hideStatus();
      showStatus('info', 'You are logged out. Enter email + password to sign in again.');
    });
  }

  if (!window.adminApi.hasToken()) {
    showStatus(
      'info',
      'Sign in with the same email and password you use for the Portal app (Supabase account).\nUse your email address — not your display name.'
    );
    return;
  }

  showLoggedIn();
  setRefreshBusy(true);
  loadDrafts()
    .catch((e) => {
      showStatus('error', errText(e));
      showLoggedOut();
    })
    .finally(() => {
      setRefreshBusy(false);
    });
})();

/* ---------- Draft detail (/admin/draft.html) ---------- */
(function initDraftPage() {
  const backBtn = document.getElementById('backBtn');
  const itemTypeEl = document.getElementById('itemType');
  if (!backBtn || !itemTypeEl) return;
  if (document.getElementById('loginBtn')) return;

  if (!window.adminApi) {
    const s = document.getElementById('status');
    if (s) {
      s.style.display = 'block';
      s.textContent = 'admin.js failed to load. Open /admin/ and sign in again.';
    }
    return;
  }

  const id = new URLSearchParams(window.location.search).get('id');
  const fields = [
    'itemType',
    'name',
    'description',
    'category',
    'address',
    'neighborhood',
    'tags',
    'imageUrl',
    'startTime',
    'endTime',
  ];
  let flagged = [];

  const toLocal = (value) => (value ? new Date(value).toISOString().slice(0, 16) : '');

  const readForm = () => ({
    itemType: document.getElementById('itemType').value || null,
    name: document.getElementById('name').value || null,
    description: document.getElementById('description').value || null,
    category: document.getElementById('category').value || null,
    address: document.getElementById('address').value || null,
    neighborhood: document.getElementById('neighborhood').value || null,
    tags: document
      .getElementById('tags')
      .value.split(',')
      .map((v) => v.trim())
      .filter(Boolean),
    imageUrl: document.getElementById('imageUrl').value || null,
    startTime: document.getElementById('startTime').value
      ? new Date(document.getElementById('startTime').value).toISOString()
      : null,
    endTime: document.getElementById('endTime').value
      ? new Date(document.getElementById('endTime').value).toISOString()
      : null,
  });

  const applyWarnings = () => {
    fields.forEach((field) => {
      const el = document.getElementById(field);
      if (!el) return;
      if (flagged.includes(field)) el.classList.add('warn');
      else el.classList.remove('warn');
    });
  };

  const showErr = (e) => {
    const el = document.getElementById('status');
    el.style.display = 'block';
    el.textContent = e instanceof Error ? e.message : String(e);
  };

  const loadDraft = () =>
    window.adminApi.fetchJson(`/ingest/drafts/${id}`).then((response) => {
      const d = response.data;
      document.getElementById('status').style.display = 'none';
      flagged = d.flaggedFields || [];
      document.getElementById('itemType').value = d.itemType || 'spot';
      document.getElementById('name').value = d.name || '';
      document.getElementById('description').value = d.description || '';
      document.getElementById('category').value = d.category || 'community';
      document.getElementById('address').value = d.address || '';
      document.getElementById('neighborhood').value = d.neighborhood || '';
      document.getElementById('tags').value = (d.tags || []).join(', ');
      document.getElementById('imageUrl').value = d.imageUrl || '';
      document.getElementById('preview').src = d.imageUrl || '';
      document.getElementById('startTime').value = toLocal(d.startTime);
      document.getElementById('endTime').value = toLocal(d.endTime);
      applyWarnings();
    });

  backBtn.addEventListener('click', () => {
    window.location.href = '/admin/';
  });

  document.getElementById('save').addEventListener('click', () => {
    window.adminApi
      .fetchJson(`/ingest/drafts/${id}`, {
        method: 'PATCH',
        body: JSON.stringify(readForm()),
      })
      .then(() => loadDraft())
      .catch(showErr);
  });

  document.getElementById('approve').addEventListener('click', () => {
    window.adminApi
      .fetchJson(`/ingest/drafts/${id}/approve`, { method: 'POST' })
      .then(() => {
        window.location.href = '/admin/';
      })
      .catch(showErr);
  });

  document.getElementById('skip').addEventListener('click', () => {
    window.adminApi
      .fetchJson(`/ingest/drafts/${id}/skip`, { method: 'POST' })
      .then(() => {
        window.location.href = '/admin/';
      })
      .catch(showErr);
  });

  document.getElementById('imageUrl').addEventListener('blur', (e) => {
    document.getElementById('preview').src = e.target.value || '';
  });

  if (window.adminApi.hasToken() && id) {
    loadDraft().catch(showErr);
  } else if (!window.adminApi.hasToken()) {
    showErr(
      new Error(
        'No API session. Go back to /admin/, log in with email/password, then open this draft again.'
      )
    );
  }
})();
