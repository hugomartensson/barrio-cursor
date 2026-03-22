/* global window, document, localStorage, fetch, URLSearchParams */
(() => {
  const TOKEN_KEY = 'portal_token';
  const getToken = () => localStorage.getItem(TOKEN_KEY);

  const parseJsonSafe = async (response) => {
    const text = await response.text();
    if (!text) return {};
    try {
      return JSON.parse(text);
    } catch {
      throw new Error(`Server returned non-JSON (${response.status}).`);
    }
  };

  const errMsg = (e) => (e instanceof Error ? e.message : String(e));

  const login = async (email, password) => {
    const response = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    const json = await parseJsonSafe(response);
    if (!response.ok || !json.data?.token) {
      throw new Error(json.error?.message || `Login failed (${response.status}).`);
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
        throw new Error('Session expired — log in again.');
      }
      throw new Error(json.error?.message || json.message || `Request failed (${response.status})`);
    }
    return json;
  };

  const logout = () => localStorage.removeItem(TOKEN_KEY);

  function extractDraft(run) {
    const steps = run.steps || {};
    const hr = steps['human-review'];
    if (hr?.payload?.draft) return hr.payload.draft;
    if (hr?.suspendPayload?.draft) return hr.suspendPayload.draft;
    if (run.suspendPayload?.draft) return run.suspendPayload.draft;
    if (run.payload?.draft) return run.payload.draft;
    return null;
  }

  function isoToLocal(iso) {
    if (!iso) return '';
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return '';
    const pad = (n) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  function localToIso(v) {
    if (!v) return null;
    const d = new Date(v);
    return Number.isNaN(d.getTime()) ? null : d.toISOString();
  }

  /* ---------- Queue ---------- */
  const loginBtn = document.getElementById('ingestLoginBtn');
  const listEl = document.getElementById('list');
  if (loginBtn && listEl) {
    const $status = document.getElementById('status');
    const $loginSection = document.getElementById('login-section');
    const $loggedInSection = document.getElementById('logged-in-section');
    const $email = document.getElementById('email');
    const $password = document.getElementById('password');
    const $refreshBtn = document.getElementById('refreshBtn');
    const $logoutBtn = document.getElementById('logoutBtn');
    const $tabs = document.getElementById('tabs');

    let activeTab = 'spot';
    let rowCache = [];

    function showStatus(kind, text) {
      if (!$status) return;
      $status.hidden = false;
      $status.className = kind;
      $status.textContent = text;
    }

    function setAuthed(on) {
      if ($loginSection) $loginSection.hidden = on;
      if ($loggedInSection) $loggedInSection.hidden = !on;
    }

    async function loadQueue() {
      showStatus('ok', 'Loading…');
      const { runs = [] } = await fetchJson('/workflows/ingest/runs?status=suspended&perPage=50');
      const rows = [];
      for (const r of runs) {
        try {
          const detail = await fetchJson(
            `/workflows/ingest/runs/${encodeURIComponent(r.runId)}?fields=steps,status,payload`,
          );
          if (detail.status !== 'suspended') continue;
          const draft = extractDraft(detail);
          if (!draft) continue;
          rows.push({ runId: r.runId, draft });
        } catch {
          /* skip */
        }
      }
      rowCache = rows;
      render();
      showStatus('ok', `${rows.length} suspended run(s) loaded.`);
    }

    function render() {
      const filtered = rowCache.filter((x) => x.draft.type === activeTab);
      listEl.innerHTML = '';
      if (!filtered.length) {
        listEl.innerHTML = '<p>No items in this tab.</p>';
        return;
      }
      for (const { runId, draft } of filtered) {
        const card = document.createElement('div');
        card.className = 'card';
        if ((draft.flaggedFields || []).length) card.classList.add('warn');
        card.onclick = () => {
          window.location.href = `/admin/ingest/detail.html?runId=${encodeURIComponent(runId)}`;
        };
        const img = document.createElement('img');
        img.className = 'thumb';
        img.alt = '';
        if (draft.imageUrl) {
          img.src = draft.imageUrl;
        }
        const meta = document.createElement('div');
        meta.className = 'meta';
        const title = document.createElement('div');
        title.textContent = draft.name || 'Unnamed';
        const sub = document.createElement('div');
        sub.style.fontSize = '0.85rem';
        sub.style.color = '#999';
        sub.textContent = [draft.neighborhood, draft.category].filter(Boolean).join(' · ');
        meta.appendChild(title);
        meta.appendChild(sub);
        const badge = document.createElement('span');
        badge.className = 'badge';
        badge.textContent = `${(draft.flaggedFields || []).length} flags`;
        card.appendChild(img);
        card.appendChild(meta);
        card.appendChild(badge);
        listEl.appendChild(card);
      }
    }

    loginBtn.addEventListener('click', async () => {
      try {
        await login($email.value.trim(), $password.value);
        setAuthed(true);
        await loadQueue();
      } catch (e) {
        showStatus('error', errMsg(e));
      }
    });

    if ($refreshBtn) $refreshBtn.addEventListener('click', () => void loadQueue().catch((e) => showStatus('error', errMsg(e))));
    if ($logoutBtn)
      $logoutBtn.addEventListener('click', () => {
        logout();
        setAuthed(false);
        listEl.innerHTML = '';
      });

    if ($tabs) {
      $tabs.querySelectorAll('button[data-tab]').forEach((btn) => {
        btn.addEventListener('click', () => {
          activeTab = btn.getAttribute('data-tab');
          $tabs.querySelectorAll('button').forEach((b) => b.classList.remove('active'));
          btn.classList.add('active');
          render();
        });
      });
    }

    if (getToken()) {
      setAuthed(true);
      void loadQueue().catch((e) => showStatus('error', errMsg(e)));
    }
  }

  /* ---------- Detail ---------- */
  const backBtn = document.getElementById('backBtn');
  const formWrap = document.getElementById('form-wrap');
  if (backBtn && formWrap) {
    const params = new URLSearchParams(window.location.search);
    const runId = params.get('runId');
    const $status = document.getElementById('status');
    const $loginSection = document.getElementById('login-section');
    const $loggedInSection = document.getElementById('logged-in-section');
    const $email = document.getElementById('email');
    const $password = document.getElementById('password');
    const $loginBtn2 = document.getElementById('ingestLoginBtn');
    const $logoutBtn = document.getElementById('logoutBtn');

    function showStatus(kind, text) {
      if (!$status) return;
      $status.hidden = false;
      $status.className = kind;
      $status.textContent = text;
    }

    function setAuthed(on) {
      if ($loginSection) $loginSection.hidden = on;
      if ($loggedInSection) $loggedInSection.hidden = !on;
    }

    let currentDraft = null;

    function applyDraftToForm(draft) {
      currentDraft = draft;
      document.getElementById('name').value = draft.name || '';
      document.getElementById('description').value = draft.description || '';
      document.getElementById('category').value = draft.category || 'food';
      document.getElementById('address').value = draft.address || '';
      document.getElementById('neighborhood').value = draft.neighborhood || '';
      document.getElementById('imageUrl').value = draft.imageUrl || '';
      const hero = document.getElementById('hero');
      if (draft.imageUrl) hero.src = draft.imageUrl;
      const ev = document.getElementById('event-fields');
      if (draft.type === 'event') {
        ev.style.display = 'block';
        document.getElementById('startTime').value = isoToLocal(draft.startTime);
        document.getElementById('endTime').value = isoToLocal(draft.endTime);
      } else {
        ev.style.display = 'none';
      }
      const thumbs = document.getElementById('thumbs');
      thumbs.innerHTML = '';
      const urls = [draft.imageUrl, ...(draft.imageUrls || [])].filter(Boolean);
      const uniq = [...new Set(urls)];
      uniq.forEach((u) => {
        const im = document.createElement('img');
        im.className = 'thumb-pick';
        im.src = u;
        im.onclick = () => {
          thumbs.querySelectorAll('.thumb-pick').forEach((x) => x.classList.remove('selected'));
          im.classList.add('selected');
          document.getElementById('imageUrl').value = u;
          document.getElementById('hero').src = u;
        };
        thumbs.appendChild(im);
      });
      (draft.flaggedFields || []).forEach((field) => {
        const el = document.getElementById(field);
        if (el) el.classList.add('flagged');
      });
      const vn = document.getElementById('verifierNotes');
      if (draft.verifierNotes) {
        vn.hidden = false;
        vn.textContent = `Verifier: ${draft.verifierNotes}`;
      }
    }

    function readDraftFromForm() {
      const d = { ...currentDraft };
      d.name = document.getElementById('name').value || null;
      d.description = document.getElementById('description').value || null;
      d.category = document.getElementById('category').value;
      d.address = document.getElementById('address').value || null;
      d.neighborhood = document.getElementById('neighborhood').value || null;
      d.imageUrl = document.getElementById('imageUrl').value || null;
      if (d.type === 'event') {
        d.startTime = localToIso(document.getElementById('startTime').value);
        d.endTime = localToIso(document.getElementById('endTime').value);
      }
      return d;
    }

    async function loadDetail() {
      if (!runId) {
        showStatus('error', 'Missing runId');
        return;
      }
      const detail = await fetchJson(
        `/workflows/ingest/runs/${encodeURIComponent(runId)}?fields=steps,status,payload`,
      );
      const draft = extractDraft(detail);
      if (!draft) {
        showStatus('error', 'Could not read draft from run.');
        return;
      }
      document.getElementById('title').textContent = `Review: ${draft.name || 'Unnamed'}`;
      applyDraftToForm(draft);
      formWrap.hidden = false;
    }

    backBtn.addEventListener('click', () => {
      window.location.href = '/admin/ingest/';
    });

    if ($loginBtn2) {
      $loginBtn2.addEventListener('click', async () => {
        try {
          await login($email.value.trim(), $password.value);
          setAuthed(true);
          await loadDetail();
        } catch (e) {
          showStatus('error', errMsg(e));
        }
      });
    }
    if ($logoutBtn)
      $logoutBtn.addEventListener('click', () => {
        logout();
        setAuthed(false);
        formWrap.hidden = true;
      });

    document.getElementById('approveBtn').addEventListener('click', async () => {
      try {
        const corrected = readDraftFromForm();
        delete corrected.verifierNotes;
        const collectionId = document.getElementById('collectionId').value.trim() || null;
        await fetchJson(`/workflows/ingest/resume-async?runId=${encodeURIComponent(runId)}`, {
          method: 'POST',
          body: JSON.stringify({
            step: 'human-review',
            resumeData: {
              approved: true,
              correctedFields: corrected,
              collectionId,
            },
          }),
        });
        showStatus('ok', 'Approved — publishing…');
        window.location.href = '/admin/ingest/';
      } catch (e) {
        showStatus('error', errMsg(e));
      }
    });

    document.getElementById('skipBtn').addEventListener('click', async () => {
      try {
        await fetchJson(`/workflows/ingest/resume-async?runId=${encodeURIComponent(runId)}`, {
          method: 'POST',
          body: JSON.stringify({
            step: 'human-review',
            resumeData: { approved: false },
          }),
        });
        window.location.href = '/admin/ingest/';
      } catch (e) {
        showStatus('error', errMsg(e));
      }
    });

    if (getToken()) {
      setAuthed(true);
      void loadDetail().catch((e) => showStatus('error', errMsg(e)));
    }
  }
})();
