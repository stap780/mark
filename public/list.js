(function() {
  
  const S3_BASE = 'https://s3.twcstorage.ru/ae4cd7ee-b62e0601-19d6-483e-bbf1-416b386e5c23';
  let DEBUG = false;

  function debugLog(){
    if (!DEBUG) return;
    try { console.log('[list]', ...arguments); } catch(e) { /* noop */ }
  }

  function getAccountIdFromScript() {
    const scripts = document.getElementsByTagName('script');
    for (let i = 0; i < scripts.length; i++) {
      const src = scripts[i].getAttribute('src') || '';
      if (src.includes('list.js')) {
        try {
          const url = new URL(src, window.location.origin);
          const id = url.searchParams.get('id');
          const dbg = url.searchParams.get('debug');
          if (dbg === '1' || dbg === 'true') DEBUG = true;
          if (id) return id;
        } catch (e) {
          // ignore
        }
      }
    }
    return null;
  }

  function fetchListJson(accountId) {
    const jsonUrl = `${S3_BASE}/lists/list_${accountId}.json`;
    debugLog('fetchListJson:url', jsonUrl);
    return fetch(jsonUrl, { credentials: 'omit' }).then(function(res) {
      debugLog('fetchListJson:status', res.status);
      if (!res.ok) throw new Error('Failed to load list json');
      return res.json();
    }).then(function(json){
      debugLog('fetchListJson:success lists_count', Array.isArray(json && json.lists) ? json.lists.length : 0, json);
      return json;
    }).catch(function(err){
      debugLog('fetchListJson:error', err && err.message ? err.message : err);
      throw err;
    });
  }
  // Step 1: Get client from Insales store via ajaxAPI
  function getClient() {
    return new Promise(function(resolve, reject) {
      if (typeof ajaxAPI !== 'undefined' && ajaxAPI.shop && ajaxAPI.shop.client) {
        ajaxAPI.shop.client.get().done(resolve).fail(reject);
      } else {
        reject(new Error('ajaxAPI.shop.client is not available'));
      }
    });
  }

  // Minimal API helpers
  function buildApiBase(accountId, listId) {
    return 'https://app.teletri.ru/api/accounts/' + encodeURIComponent(accountId) + '/lists/' + encodeURIComponent(listId) + '/list_items';
  }

  function apiGetListItems(accountId, listId, externalClientId) {
    var url = buildApiBase(accountId, listId) + '?external_client_id=' + encodeURIComponent(externalClientId);
    debugLog('api:get', url);
    return fetch(url, { method: 'GET', credentials: 'omit' })
      .then(function(r){ return r.json(); });
  }

  function apiAddItem(accountId, listId, externalClientId, externalProductId, externalVariantId) {
    var url = buildApiBase(accountId, listId);
    var params = new URLSearchParams();
    params.append('external_client_id', externalClientId);
    params.append('external_product_id', externalProductId);
    if (externalVariantId) params.append('external_variant_id', externalVariantId);
    debugLog('api:post', url, params.toString());
    return fetch(url, { method: 'POST', body: params, credentials: 'omit' })
      .then(function(r){ return r.json(); });
  }

  function apiRemoveItem(accountId, listId, listItemId) {
    var url = buildApiBase(accountId, listId) + '/' + encodeURIComponent(listItemId);
    debugLog('api:delete', url);
    return fetch(url, { method: 'DELETE', credentials: 'omit' })
      .then(function(r){ return r.json(); });
  }

  // Step 2: Create HTML container for all user lists with selected icon
  function renderIcon(iconStyle, color, active) {
    var stroke = color || '#999999';
    var fill = active ? (color || '#999999') : 'none';
    switch (iconStyle) {
      case 'icon_one':
        // Heart
        return '<svg xmlns="http://www.w3.org/2000/svg" style="pointer-events:none;display:block;" viewBox="0 0 24 24" fill="' + fill + '" stroke="' + stroke + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 1 0-7.78 7.78L12 21.23l8.84-8.84a5.5 5.5 0 0 0 0-7.78z"/></svg>';
      case 'icon_two':
        // Wishlist (bookmark)
        return '<svg xmlns="http://www.w3.org/2000/svg" style="pointer-events:none;display:block;" viewBox="0 0 24 24" fill="' + fill + '" stroke="' + stroke + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/></svg>';
      case 'icon_three':
        // Like (thumb/finger up)
        return '<svg xmlns="http://www.w3.org/2000/svg" style="pointer-events:none;display:block;" viewBox="0 0 24 24" fill="' + fill + '" stroke="' + stroke + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 21h4V9H2v12z"/><path d="M22 11c0-1.1-.9-2-2-2h-6l1-5-5 6v11h9c1.1 0 2-.9 2-2l1-8z"/></svg>';
      default:
        return '';
    }
  }

  function createListsContainer(lists, options) {
    options = options || {};
    var containerSelector = options.containerSelector || '[data-lists-root]';
    var attach = options.attach !== undefined ? options.attach : true;

    var wrapper = document.createElement('div');
    wrapper.setAttribute('style', 'display:block;z-index: 100;');
    debugLog('createListsContainer:init', { lists_count: (lists||[]).length, containerSelector: containerSelector, attach: attach });

    var listEl = document.createElement('div');
    listEl.setAttribute('style', 'display:flex;gap:12px;align-items:center;flex-wrap:wrap;');
    wrapper.appendChild(listEl);

    (lists || []).forEach(function(list) {
      debugLog('createListsContainer:item', list);
      var item = document.createElement('span');
      item.setAttribute('style', 'display:inline-flex;align-items:center;gap:8px;cursor:pointer;width:24px;');
      item.setAttribute('class', 'twc-list-item');
      item.setAttribute('data-list-id', String(list.id));
      item.setAttribute('data-list-name', list.name || '');
      item.setAttribute('data-icon-style', list.icon_style || 'icon_one');
      item.setAttribute('data-icon-color', list.icon_color || '#999999');
      item.setAttribute('data-added', 'false');

      var iconHtml = renderIcon(list.icon_style || 'icon_one', list.icon_color || '#999999', false);
      item.innerHTML = iconHtml;

      listEl.appendChild(item);
    });

    if (attach) {
      var host = document.querySelector(containerSelector);
      if (host) { host.innerHTML = ''; host.appendChild(wrapper); debugLog('createListsContainer:attached', host); }
      else { debugLog('createListsContainer:host_not_found', containerSelector); }
    }

    return wrapper;
  }
  
  // Step 3: Find all favorites triggers and update with lists container
  function updateFavoritesTriggers(lists, options) {
    var nodes = document.querySelectorAll('[data-ui-favorites-trigger]');
    debugLog('updateFavoritesTriggers:found_nodes', nodes.length);
    if (!nodes || !nodes.length) { debugLog('updateFavoritesTriggers:no_nodes'); return []; }
    var results = [];
    nodes.forEach(function(node) {
      var container = createListsContainer(lists, { attach: false });
      node.innerHTML = '';
      node.appendChild(container);
      debugLog('updateFavoritesTriggers:updated_node', node);
      results.push(node);

      // Update attribute: move data-ui-favorites-trigger to data-ui-favorites-trigger-twc
      var productId = node.getAttribute('data-ui-favorites-trigger');
      if (productId) {
        node.removeAttribute('data-ui-favorites-trigger');
        node.setAttribute('data-ui-favorites-trigger-twc', productId);
      }
    });
    return results;
  }

  // Initialize added/not-added state for each rendered list item on page load
  function initListItemStates(accountId) {
    return getClient().then(function(client){
      var clientId = client && client.id;
      if (!clientId) return;
      var hosts = document.querySelectorAll('[data-ui-favorites-trigger-twc]');
      hosts.forEach(function(host){
        var productId = host.getAttribute('data-ui-favorites-trigger-twc');
        var items = host.querySelectorAll('.twc-list-item');
        // Group by list_id to avoid redundant requests per host
        var byList = {};
        items.forEach(function(it){
          var listId = it.getAttribute('data-list-id');
          (byList[listId] ||= []).push(it);
        });
        Object.keys(byList).forEach(function(listId){
          apiGetListItems(accountId, listId, clientId).then(function(resp){
            var arr = (resp && resp.items) || [];
            var isInList = arr.some(function(x){ return String(x.item_id) === String(productId); });
            byList[listId].forEach(function(node){
              var iconStyle = node.getAttribute('data-icon-style');
              var iconColor = node.getAttribute('data-icon-color');
              if (isInList) {
                node.setAttribute('data-added', 'true');
                node.innerHTML = renderIcon(iconStyle, iconColor, true);
              } else {
                node.setAttribute('data-added', 'false');
                node.innerHTML = renderIcon(iconStyle, iconColor, false);
              }
            });
          }).catch(function(err){ debugLog('initListItemStates:error', err && err.message ? err.message : err); });
        });
      });
    }).catch(function(err){ debugLog('initListItemStates:no_client', err && err.message ? err.message : err); });
  }

  // Step 4: Click handler on twc-list-item; report product id, list id, client id
  function bindListItemClickHandlers() {
    document.addEventListener('click', function(evt) {
      if (!evt.target || !evt.target.classList || !evt.target.classList.contains('twc-list-item')) return;
      var itemNode = evt.target;
      var triggerHost = itemNode.closest('[data-ui-favorites-trigger-twc]');
      if (!triggerHost) return;
      var productId = triggerHost.getAttribute('data-ui-favorites-trigger-twc');
      var listId = itemNode.getAttribute('data-list-id');
      var iconStyle = itemNode.getAttribute('data-icon-style');
      var iconColor = itemNode.getAttribute('data-icon-color');
      var added = itemNode.getAttribute('data-added') === 'true';
      getClient()
        .then(function(client){
          var clientId = client && client.id;
          debugLog('lists:click', { clientId: clientId, productId: productId, listId: listId, added: added });
          var accountId = getAccountIdFromScript();
          if (!accountId) { debugLog('lists:click:no_account_id'); return; }

          if (added) {
            // find list_item id by productId via index then delete
            apiGetListItems(accountId, listId, clientId).then(function(resp){
              debugLog('apiGetListItems =>', resp);
              var items = (resp && resp.items) || [];
              var match = items.find(function(x){ return String(x.item_id) === String(productId); });
              if (!match) { debugLog('lists:remove:not_found'); return; }
              return apiRemoveItem(accountId, listId, match.id).then(function(){
                itemNode.setAttribute('data-added', 'false');
                itemNode.innerHTML = renderIcon(iconStyle, iconColor, false);
                debugLog('lists:removed', { list_item_id: match.id });
              });
            }).catch(function(err){ debugLog('lists:remove:error', err && err.message ? err.message : err); });
          } else {
            apiAddItem(accountId, listId, clientId, productId, null).then(function(resp){
              itemNode.setAttribute('data-added', 'true');
              itemNode.innerHTML = renderIcon(iconStyle, iconColor, true);
              debugLog('lists:added', resp);
            }).catch(function(err){ debugLog('lists:add:error', err && err.message ? err.message : err); });
          }
        })
        .catch(function(){
          debugLog('lists:click:no_client');
          try { alert('Please register'); } catch(e) {}
        });
    });
  }

  document.addEventListener('DOMContentLoaded', function() {
    debugLog('dom:ready');
    const accountId = getAccountIdFromScript();
    if (!accountId) { debugLog('dom:no_account_id'); return; }
  
    fetchListJson(accountId)
      .then(data => {
        debugLog('dom:update_triggers');
        updateFavoritesTriggers(data.lists);
        // After rendering, initialize active states
        initListItemStates(accountId);
      })
      .catch(function(err){ debugLog('dom:error', err && err.message ? err.message : err); console.error(err); });

    // Always bind click handlers
    bindListItemClickHandlers();
  });


})();


