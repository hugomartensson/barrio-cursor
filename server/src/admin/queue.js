/* Portal ingest queue page — must be external script (Helmet CSP blocks inline scripts). */
(function () {
  function showBootFatal(msg) {
    var el = document.getElementById('boot-fatal');
    if (el) {
      el.classList.add('visible');
      el.textContent = msg;
    }
  }

  if (!window.adminApi || typeof window.adminApi.login !== 'function') {
    showBootFatal(
      'Could not load admin.js. Helmet blocks inline scripts in production — use an external bundle. ' +
        'Hard-refresh (Ctrl+Shift+R). If this persists, redeploy so dist/admin includes all .js files.'
    );
    return;
  }

  var $status = document.getElementById('status');
  var $list = document.getElementById('list');
  var $count = document.getElementById('count');
  var $loginSection = document.getElementById('login-section');
  var $loggedInSection = document.getElementById('logged-in-section');
  var $loginBtn = document.getElementById('loginBtn');
  var $refreshBtn = document.getElementById('refreshBtn');
  var $email = document.getElementById('email');
  var $password = document.getElementById('password');

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
    document.getElementById('user-label').textContent = label || 'Logged in';
  }

  function showLoggedOut() {
    $loginSection.style.display = 'flex';
    $loggedInSection.style.display = 'none';
    $count.textContent = '—';
    $list.innerHTML = '';
  }

  function render(drafts) {
    $count.textContent =
      drafts.length + ' draft' + (drafts.length !== 1 ? 's' : '') + ' pending';
    $list.innerHTML = drafts
      .map(function (d) {
        var flagged = Array.isArray(d.flaggedFields) ? d.flaggedFields.length : 0;
        return (
          '<div class="card" data-id="' +
          d.id +
          '">' +
          '<div class="title">' +
          (d.name || 'Unnamed') +
          '</div>' +
          '<div class="meta">' +
          '<span class="pill">' +
          (d.itemType || '?') +
          '</span>' +
          '<span>' +
          (d.category || 'no category') +
          '</span>' +
          '<span>' +
          new Date(d.createdAt).toLocaleString() +
          '</span>' +
          (flagged ? '<span class="pill warn">' + flagged + ' flagged</span>' : '') +
          '</div></div>'
        );
      })
      .join('');
    document.querySelectorAll('.card').forEach(function (el) {
      el.addEventListener('click', function () {
        window.location.href = '/admin/draft.html?id=' + el.getAttribute('data-id');
      });
    });
  }

  function load() {
    showStatus('loading', 'Loading drafts…');
    return window.adminApi.fetchJson('/ingest/drafts').then(function (res) {
      var drafts = res.data || [];
      render(drafts);
      if (!drafts.length) {
        showStatus(
          'ok',
          'Loaded successfully. No pending drafts.\n\nTip: send a link (https://…) to your Telegram bot to create one.'
        );
      } else {
        showStatus('ok', 'Loaded ' + drafts.length + ' draft(s). Click a row to review.');
      }
    });
  }

  function ensureAdminApi() {
    if (!window.adminApi || typeof window.adminApi.login !== 'function') {
      showStatus('error', 'admin.js did not load. See the red message at the top.');
      return false;
    }
    return true;
  }

  $loginBtn.addEventListener('click', function () {
    if (!ensureAdminApi()) return;
    hideStatus();
    setLoginBusy(true);
    showStatus('loading', 'Contacting server…\n\nPOST /api/auth/login');
    window.adminApi
      .login($email.value.trim(), $password.value)
      .then(function (data) {
        showLoggedIn(data.user && (data.user.email || data.user.name));
        showStatus('loading', 'Signed in. Loading drafts…');
        return load();
      })
      .catch(function (e) {
        showStatus('error', errText(e));
      })
      .finally(function () {
        setLoginBusy(false);
      });
  });

  $password.addEventListener('keydown', function (ev) {
    if (ev.key === 'Enter') $loginBtn.click();
  });

  $refreshBtn.addEventListener('click', function () {
    if (!ensureAdminApi()) return;
    setRefreshBusy(true);
    load()
      .catch(function (e) {
        showStatus('error', errText(e));
        showLoggedOut();
      })
      .finally(function () {
        setRefreshBusy(false);
      });
  });

  document.getElementById('logoutBtn').addEventListener('click', function () {
    if (window.adminApi) window.adminApi.logout();
    showLoggedOut();
    hideStatus();
    showStatus('info', 'You are logged out. Enter email + password to sign in again.');
  });

  if (!window.adminApi.hasToken()) {
    showStatus(
      'info',
      'Sign in with the same email and password you use for the Portal app (Supabase account).\nUse your email address — not your display name.'
    );
    return;
  }

  showLoggedIn();
  setRefreshBusy(true);
  load()
    .catch(function (e) {
      showStatus('error', errText(e));
      showLoggedOut();
    })
    .finally(function () {
      setRefreshBusy(false);
    });
})();
