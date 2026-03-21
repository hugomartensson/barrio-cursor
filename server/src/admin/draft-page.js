/* Draft detail page — external script only (Helmet CSP blocks inline scripts). */
(function () {
  if (!window.adminApi) {
    var s = document.getElementById('status');
    if (s) {
      s.style.display = 'block';
      s.textContent = 'admin.js failed to load. Open /admin/ and redeploy if needed.';
    }
    return;
  }

  var id = new URLSearchParams(window.location.search).get('id');
  var fields = [
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
  var flagged = [];

  function toLocal(value) {
    return value ? new Date(value).toISOString().slice(0, 16) : '';
  }

  function readForm() {
    return {
      itemType: document.getElementById('itemType').value || null,
      name: document.getElementById('name').value || null,
      description: document.getElementById('description').value || null,
      category: document.getElementById('category').value || null,
      address: document.getElementById('address').value || null,
      neighborhood: document.getElementById('neighborhood').value || null,
      tags: document
        .getElementById('tags')
        .value.split(',')
        .map(function (v) {
          return v.trim();
        })
        .filter(Boolean),
      imageUrl: document.getElementById('imageUrl').value || null,
      startTime: document.getElementById('startTime').value
        ? new Date(document.getElementById('startTime').value).toISOString()
        : null,
      endTime: document.getElementById('endTime').value
        ? new Date(document.getElementById('endTime').value).toISOString()
        : null,
    };
  }

  function applyWarnings() {
    fields.forEach(function (field) {
      var el = document.getElementById(field);
      if (!el) return;
      if (flagged.indexOf(field) !== -1) el.classList.add('warn');
      else el.classList.remove('warn');
    });
  }

  function showErr(e) {
    var el = document.getElementById('status');
    el.style.display = 'block';
    el.textContent = e instanceof Error ? e.message : String(e);
  }

  function load() {
    return window.adminApi.fetchJson('/ingest/drafts/' + id).then(function (response) {
      var d = response.data;
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
  }

  var backBtn = document.getElementById('backBtn');
  if (backBtn) {
    backBtn.addEventListener('click', function () {
      window.location.href = '/admin/';
    });
  }

  document.getElementById('save').addEventListener('click', function () {
    window.adminApi
      .fetchJson('/ingest/drafts/' + id, {
        method: 'PATCH',
        body: JSON.stringify(readForm()),
      })
      .then(function () {
        return load();
      })
      .catch(showErr);
  });

  document.getElementById('approve').addEventListener('click', function () {
    window.adminApi
      .fetchJson('/ingest/drafts/' + id + '/approve', { method: 'POST' })
      .then(function () {
        window.location.href = '/admin/';
      })
      .catch(showErr);
  });

  document.getElementById('skip').addEventListener('click', function () {
    window.adminApi
      .fetchJson('/ingest/drafts/' + id + '/skip', { method: 'POST' })
      .then(function () {
        window.location.href = '/admin/';
      })
      .catch(showErr);
  });

  document.getElementById('imageUrl').addEventListener('blur', function (e) {
    document.getElementById('preview').src = e.target.value || '';
  });

  if (window.adminApi.hasToken() && id) {
    load().catch(showErr);
  } else if (!window.adminApi.hasToken()) {
    showErr(
      new Error(
        'No API session. Go back to /admin/, log in with email/password, then open this draft again.'
      )
    );
  }
})();
