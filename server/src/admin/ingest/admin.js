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

    const $submitSection = document.getElementById('submit-section');
    const $urlInput = document.getElementById('urlInput');
    const $contextNote = document.getElementById('contextNote');
    const $submitUrlBtn = document.getElementById('submitUrlBtn');
    const $submitStatus = document.getElementById('submitStatus');

    function setSubmitStatus(kind, text) {
      if (!$submitStatus) return;
      $submitStatus.className = kind;
      $submitStatus.textContent = text;
    }

    function setAuthed(on) {
      if ($loginSection) $loginSection.hidden = on;
      if ($loggedInSection) $loggedInSection.hidden = !on;
      if ($submitSection) $submitSection.hidden = !on;
    }

    function pollSubmittedRun(runId) {
      const INTERVAL = 10_000;
      const DEADLINE = Date.now() + 12 * 60_000;
      const check = async () => {
        if (Date.now() > DEADLINE) {
          setSubmitStatus('error', 'Timed out waiting for workflow. Check the queue for results.');
          return;
        }
        try {
          const run = await fetchJson(`/workflows/ingest/runs/${encodeURIComponent(runId)}`);
          const s = run.status;
          if (s === 'suspended' || s === 'waiting') {
            const draft = extractDraft(run);
            const name = draft?.name || 'Unnamed';
            setSubmitStatus('ok', `Draft ready: "${name}" — appeared in queue below.`);
            void loadQueue();
          } else if (s === 'success') {
            setSubmitStatus('ok', 'Published directly (no review step required).');
            void loadQueue();
          } else if (s === 'failed' || s === 'bailed') {
            setSubmitStatus('error', `Workflow ${s}. Check logs for details.`);
          } else {
            setTimeout(() => void check(), INTERVAL);
          }
        } catch {
          setTimeout(() => void check(), INTERVAL);
        }
      };
      setTimeout(() => void check(), INTERVAL);
    }

    if ($submitUrlBtn) {
      $submitUrlBtn.addEventListener('click', async () => {
        const url = $urlInput ? $urlInput.value.trim() : '';
        if (!url) { setSubmitStatus('error', 'Please enter a URL.'); return; }
        $submitUrlBtn.disabled = true;
        setSubmitStatus('info', 'Submitting…');
        try {
          const { runId } = await fetchJson('/ingest/submit-url', {
            method: 'POST',
            body: JSON.stringify({ url, contextNote: $contextNote?.value?.trim() || undefined }),
          });
          if ($urlInput) $urlInput.value = '';
          if ($contextNote) $contextNote.value = '';
          setSubmitStatus('info', `Processing… (run ${runId.slice(0, 8)}). This takes 1–3 min. The draft will appear in the queue when ready.`);
          pollSubmittedRun(runId);
        } catch (e) {
          setSubmitStatus('error', errMsg(e));
        } finally {
          $submitUrlBtn.disabled = false;
        }
      });
    }

    async function loadQueue() {
      showStatus('ok', 'Loading…');
      // Mastra may use `waiting` (HITL) instead of `suspended` for the same state — fetch both.
      const [sus, wait] = await Promise.all([
        fetchJson('/workflows/ingest/runs?status=suspended&perPage=50'),
        fetchJson('/workflows/ingest/runs?status=waiting&perPage=50'),
      ]);
      const byId = new Map();
      for (const r of sus.runs || []) byId.set(r.runId, r);
      for (const r of wait.runs || []) byId.set(r.runId, r);
      const runs = Array.from(byId.values());
      const rows = [];
      for (const r of runs) {
        try {
          const detail = await fetchJson(
            `/workflows/ingest/runs/${encodeURIComponent(r.runId)}`,
          );
          if (detail.status !== 'suspended' && detail.status !== 'waiting') continue;
          const draft = extractDraft(detail);
          if (!draft) continue;
          rows.push({ runId: r.runId, draft });
        } catch {
          /* skip */
        }
      }
      rowCache = rows;
      render();
      showStatus('ok', `${rows.length} run(s) awaiting review loaded.`);
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
    /** Set when POST /ingest/validate-draft succeeds — merged into correctedFields on approve. */
    let validatedCoords = null;
    let validateTimer = null;

    function debounceValidate() {
      if (validateTimer) clearTimeout(validateTimer);
      validateTimer = setTimeout(() => {
        validateTimer = null;
        void validateDraft();
      }, 650);
    }

    function buildValidatePayload() {
      const d = readDraftFromForm();
      const img = (d.imageUrl || currentDraft?.imageUrl || '').trim();
      if (!img) return null;
      // Pass through coords if already resolved (from enrich step) — validate-draft skips geocoding when present.
      const lat = typeof d.latitude === 'number' ? d.latitude : undefined;
      const lng = typeof d.longitude === 'number' ? d.longitude : undefined;
      if (d.type === 'spot') {
        return {
          type: 'spot',
          name: d.name?.trim() || 'Unnamed',
          description: d.description?.trim() || '—',
          category: d.category || 'community',
          address: d.address?.trim() || '',
          neighborhood: d.neighborhood?.trim() || undefined,
          tags: [],
          image: { url: img },
          ...(lat !== undefined && lng !== undefined ? { latitude: lat, longitude: lng } : {}),
        };
      }
      const start = d.startTime || new Date().toISOString();
      return {
        type: 'event',
        title: d.name?.trim() || 'Untitled',
        description: d.description?.trim() || '—',
        category: d.category || 'community',
        address: d.address?.trim() || '',
        startTime: start,
        endTime: d.endTime ?? null,
        media: [{ url: img, type: 'photo' }],
        ...(lat !== undefined && lng !== undefined ? { latitude: lat, longitude: lng } : {}),
      };
    }

    async function validateDraft() {
      const approveBtn = document.getElementById('approveBtn');
      const payload = buildValidatePayload();
      validatedCoords = null;
      if (approveBtn) approveBtn.disabled = true;
      if (!getToken()) return;
      if (!payload) {
        showStatus('error', 'Image URL is required before validation.');
        return;
      }
      if (!String(payload.address || '').trim()) {
        showStatus('error', 'Address is required.');
        return;
      }
      try {
        showStatus('ok', 'Validating location…');
        const response = await fetch('/api/ingest/validate-draft', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${getToken()}`,
          },
          body: JSON.stringify(payload),
        });
        const json = await parseJsonSafe(response);
        if (response.status === 401) {
          localStorage.removeItem(TOKEN_KEY);
          showStatus('error', 'Session expired — log in again.');
          return;
        }
        if (!response.ok) {
          showStatus('error', json.error?.message || `Validate failed (${response.status})`);
          return;
        }
        if (!json.valid) {
          showStatus('error', json.error?.message || 'Could not validate this draft.');
          return;
        }
        validatedCoords = { latitude: json.latitude, longitude: json.longitude };
        if (approveBtn) approveBtn.disabled = false;
        showStatus('ok', `Location validated (${json.latitude.toFixed(5)}, ${json.longitude.toFixed(5)}) — you can approve.`);
      } catch (e) {
        showStatus('error', errMsg(e));
      }
    }

    function applyDraftToForm(draft) {
      currentDraft = draft;
      document.getElementById('name').value = draft.name || '';
      document.getElementById('description').value = draft.description || '';
      document.getElementById('category').value = draft.category || 'food';
      document.getElementById('address').value = draft.address || '';
      document.getElementById('neighborhood').value = draft.neighborhood || '';
      document.getElementById('imageUrl').value = draft.imageUrl || '';
      const hero = document.getElementById('hero');
      const heroLink = document.getElementById('heroLink');
      if (draft.imageUrl) {
        hero.referrerPolicy = 'no-referrer';
        hero.src = draft.imageUrl;
        hero.onerror = () => { hero.style.display = 'none'; };
        hero.onload = () => { hero.style.display = ''; };
        if (heroLink) { heroLink.href = draft.imageUrl; heroLink.textContent = draft.imageUrl; heroLink.hidden = false; }
      }
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
      uniq.forEach((u, i) => {
        const im = document.createElement('img');
        im.className = 'thumb-pick';
        im.referrerPolicy = 'no-referrer';
        im.src = u;
        im.title = u;
        if (i === 0) im.classList.add('selected');
        im.onerror = () => { im.style.opacity = '0.25'; im.title = `(failed) ${u}`; };
        im.onclick = () => {
          thumbs.querySelectorAll('.thumb-pick').forEach((x) => x.classList.remove('selected'));
          im.classList.add('selected');
          document.getElementById('imageUrl').value = u;
          const h = document.getElementById('hero');
          h.referrerPolicy = 'no-referrer';
          h.src = u;
          h.style.display = '';
          if (heroLink) { heroLink.href = u; heroLink.textContent = u; heroLink.hidden = false; }
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
        `/workflows/ingest/runs/${encodeURIComponent(runId)}`,
      );
      const draft = extractDraft(detail);
      if (!draft) {
        showStatus('error', 'Could not read draft from run.');
        return;
      }
      document.getElementById('title').textContent = `Review: ${draft.name || 'Unnamed'}`;
      applyDraftToForm(draft);
      formWrap.hidden = false;
      const approveBtn = document.getElementById('approveBtn');
      if (approveBtn) approveBtn.disabled = true;
      validatedCoords = null;
      await validateDraft();
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

    ['name', 'description', 'category', 'address', 'neighborhood', 'imageUrl', 'startTime', 'endTime'].forEach(
      (id) => {
        const el = document.getElementById(id);
        if (el) {
          el.addEventListener('input', () => debounceValidate());
          el.addEventListener('change', () => debounceValidate());
        }
      },
    );

    document.getElementById('approveBtn').addEventListener('click', async () => {
      try {
        await validateDraft();
        if (!validatedCoords) {
          showStatus('error', 'Fix validation errors before approving.');
          return;
        }
        const corrected = readDraftFromForm();
        delete corrected.verifierNotes;
        corrected.latitude = validatedCoords.latitude;
        corrected.longitude = validatedCoords.longitude;
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

    async function initAddressAutocomplete() {
      try {
        const { key } = await fetchJson('/ingest/maps-config');
        if (!key) return;
        await new Promise((resolve, reject) => {
          const s = document.createElement('script');
          s.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(key)}&libraries=places`;
          s.onload = resolve;
          s.onerror = reject;
          document.head.appendChild(s);
        });
        const addressEl = document.getElementById('address');
        // eslint-disable-next-line no-undef
        const ac = new google.maps.places.Autocomplete(addressEl, {
          types: ['establishment', 'geocode'],
          fields: ['formatted_address', 'geometry', 'address_components'],
        });
        ac.addListener('place_changed', () => {
          const place = ac.getPlace();
          if (!place.geometry?.location) return;
          addressEl.value = place.formatted_address || '';
          const comps = place.address_components || [];
          const neighborhood =
            comps.find((c) => c.types.includes('sublocality_level_1'))?.long_name ||
            comps.find((c) => c.types.includes('neighborhood'))?.long_name ||
            comps.find((c) => c.types.includes('sublocality'))?.long_name ||
            '';
          document.getElementById('neighborhood').value = neighborhood;
          if (currentDraft) {
            currentDraft.latitude = place.geometry.location.lat();
            currentDraft.longitude = place.geometry.location.lng();
          }
          void validateDraft();
        });
      } catch {
        /* autocomplete optional — address still works without it */
      }
    }

    if (getToken()) {
      setAuthed(true);
      void loadDetail()
        .then(() => initAddressAutocomplete())
        .catch((e) => showStatus('error', errMsg(e)));
    }
  }
})();
