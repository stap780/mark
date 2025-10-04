// lists.js
// Lightweight storefront helper for rendering lists with API-first and S3 fallback

(function() {
  let DEBUG = false;

  function debugLog() {
    if (!DEBUG) return;
    try { console.log('[lists]', ...arguments); } catch (e) {}
  }

  function getParamsFromScript() {
    const scripts = document.getElementsByTagName('script');
    for (let i = 0; i < scripts.length; i++) {
      const src = scripts[i].getAttribute('src') || '';
      if (src.includes('lists.js')) {
        try {
          const url = new URL(src, window.location.origin);
          const accountId = url.searchParams.get('account_id');
          const clientId = url.searchParams.get('client_id');
          const dbg = url.searchParams.get('debug');
          if (dbg === '1' || dbg === 'true') DEBUG = true;
          return { accountId, clientId };
        } catch (e) { /* ignore */ }
      }
    }
    return { accountId: null, clientId: null };
  }

  // S3/public fallback: /lists/<account_id>/clients/<client_id>.json
  function fetchS3Lists(accountId, clientId) {
    const path = `/lists/${accountId}/clients/${clientId}.json`;
    debugLog('fetchS3Lists', path);
    return fetch(path, { credentials: 'omit' }).then(function(res) {
      if (!res.ok) throw new Error('s3 json not found');
      return res.json();
    });
  }

  // Minimal render: expects data as [{ list_id, name, items: [{item_type, item_id, metadata}, ...] }, ...]
  function renderLists(container, data) {
    if (!Array.isArray(data) || data.length === 0) {
      container.innerHTML = '<div class="text-sm text-gray-600">No items.</div>';
      return;
    }
    const frag = document.createDocumentFragment();
    data.forEach(function(list) {
      const wrap = document.createElement('div');
      wrap.className = 'twc-list-block';
      const h = document.createElement('h3');
      h.textContent = list.name || 'List';
      h.style.margin = '8px 0';
      wrap.appendChild(h);
      const ul = document.createElement('ul');
      (list.items || []).forEach(function(it) {
        const li = document.createElement('li');
        li.textContent = `${it.item_type || 'Item'} #${it.item_id}`;
        ul.appendChild(li);
      });
      wrap.appendChild(ul);
      frag.appendChild(wrap);
    });
    container.innerHTML = '';
    container.appendChild(frag);
  }

  function init() {
    const params = getParamsFromScript();
    const accountId = params.accountId;
    const clientId = params.clientId;
    const container = document.querySelector('[data-lists-container]') || document.getElementById('lists-container');
    if (!container) { debugLog('no container'); return; }
    if (!accountId || !clientId) { debugLog('missing ids'); return; }

    // For now use S3/public fallback. API usage can be added when endpoints are available
    fetchS3Lists(accountId, clientId)
      .then(function(payload) {
        debugLog('payload', payload);
        renderLists(container, payload);
      })
      .catch(function(err) {
        // eslint-disable-next-line no-console
        console.warn('lists.js error:', err);
      });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();


