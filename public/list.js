(function() {
  
  const S3_BASE = 'https://s3.twcstorage.ru/ae4cd7ee-b62e0601-19d6-483e-bbf1-416b386e5c23';
  let DEBUG = false;
  
  // S3 URL builders
  function buildS3AccountListsUrl(accountId) {
    return S3_BASE + '/lists/list_' + accountId + '.json';
  }
  function buildS3ClientListItemsUrl(accountId, clientId) {
    return S3_BASE + '/lists/list_' + accountId + '_client_' + clientId + '_list_items.json';
  }
  
  // Version logging
  console.log('[list][v_0.2][loaded]');
  
  // Immediate debug check
  console.log('[list][debug] Script loaded, DEBUG:', DEBUG);
  // console.log('[list][debug] Document ready state:', document.readyState);

  function debugLog(){
    if (!DEBUG) return;
    try { console.log('[list]', ...arguments); } catch(e) { /* noop */ }
  }

  function getAccountIdFromScript() {
    const scripts = document.getElementsByTagName('script');
    console.log('[list][debug] Scanning', scripts.length, 'scripts for list.js');
    for (let i = 0; i < scripts.length; i++) {
      const src = scripts[i].getAttribute('src') || '';
      // console.log('[list][debug] Script', i, ':', src);
      if (src.includes('list.js')) {
        try {
          const url = new URL(src, window.location.origin);
          const id = url.searchParams.get('id');
          const dbg = url.searchParams.get('debug');
          // console.log('[list][debug] Found list.js with id:', id, 'debug:', dbg);
          if (dbg === '1' || dbg === 'true') {
            DEBUG = true;
            console.log('[list][debug] DEBUG mode ENABLED');
          }
          if (id) return id;
        } catch (e) {
          console.log('[list][debug] Error parsing URL:', e);
        }
      }
    }
    console.log('[list][debug] No list.js script found or no account ID');
    return null;
  }

  function fetchListJson(accountId) {
    const jsonUrl = buildS3AccountListsUrl(accountId) + `?t=${Date.now()}`;
    debugLog('fetchListJson:url', jsonUrl);
    return fetch(jsonUrl, { credentials: 'omit', cache: 'no-cache' }).then(function(res) {
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

  // Initialize state using S3 JSON cache per account/client
  function initListItemStatesFromS3(accountId) {
    return getClient().then(function(client){
      var clientId = client && client.id;
      if (!clientId) return;
      var url = buildS3ClientListItemsUrl(accountId, clientId) + '?t=' + Date.now();
      debugLog('initListItemStatesFromS3:url', url);
      return fetch(url, { credentials: 'omit', cache: 'no-cache' })
        .then(function(r){ if (!r.ok) throw new Error('S3 not available'); return r.json(); })
        .then(function(data){
          var listsData = (data && data.lists) || [];
          debugLog('initListItemStatesFromS3:data', listsData);
          var byId = {};
          listsData.forEach(function(l){ byId[String(l.id)] = l; });

          var hosts = document.querySelectorAll('[data-ui-favorites-trigger-twc]');
          hosts.forEach(function(host){
            var productId = host.getAttribute('data-ui-favorites-trigger-twc');
            var items = host.querySelectorAll('.twc-list-item');
            items.forEach(function(node){
              var listId = node.getAttribute('data-list-id');
              var iconStyle = node.getAttribute('data-icon-style');
              var iconColor = node.getAttribute('data-icon-color');
              var listBlock = byId[String(listId)];
              var present = false;
              if (listBlock && Array.isArray(listBlock.items)) {
                present = listBlock.items.some(function(it){ return String(it.external_item_id) === String(productId); });
              }
              // debugLog('S3:state', { listId: listId, productId: productId, present: present, items_len: (listBlock && listBlock.items ? listBlock.items.length : 0) });
              if (present) {
                node.setAttribute('data-added', 'true');
                node.innerHTML = renderIcon(iconStyle, iconColor, true);
                // debugLog('S3:apply', 'active', { listId: listId, productId: productId });
              } else {
                node.setAttribute('data-added', 'false');
                node.innerHTML = renderIcon(iconStyle, iconColor, false);
                // debugLog('S3:apply', 'inactive', { listId: listId, productId: productId });
              }
            });
          });
        })
        .catch(function(err){ debugLog('initListItemStatesFromS3:error', err && err.message ? err.message : err); });
    }).catch(function(err){ debugLog('initListItemStatesFromS3:no_client', err && err.message ? err.message : err); });
  }

  // Favorites page renderer: builds simple sections per list using Insales ajaxAPI.product.getList
  function renderFavoritesPageFromS3(accountId) {
    if (!/favorites/i.test(window.location.href)) { return; }
    return getClient().then(function(client){
      var clientId = client && client.id;
      if (!clientId) return;
      var url = buildS3ClientListItemsUrl(accountId, clientId) + '?t=' + Date.now();
      debugLog('favorites:page:url', url);
      return fetch(url, { credentials: 'omit', cache: 'no-cache' })
        .then(function(r){ if (!r.ok) throw new Error('S3 not available'); return r.json(); })
        .then(function(data){
          var listsData = (data && data.lists) || [];
          debugLog('favorites:page:data', listsData);
          var main = document.querySelector('.lists-wrapper');
          debugLog('favorites:page:main_selector', { found: !!main, selector: '.lists-wrapper' });
          if (!main) {
            main = document.querySelector('main');
            debugLog('favorites:page:main_selector', { found: !!main, selector: 'main' });
          }
          if (main) { 
            debugLog('favorites:page:main_clearing', { main: main });
            main.innerHTML = ''; 
          }
          listsData.forEach(function(block){
            var ids = (block.items || []).map(function(it){ return it.external_item_id; }).filter(Boolean);
            if (!ids.length) return;
            var section = document.createElement('section');
            section.setAttribute('style', 'margin:20px 0;padding: 20px;');
            var h2 = document.createElement('h2');
            h2.textContent = block.name || ('List #' + block.id);
            h2.setAttribute('style', 'font-size:20px;margin:0 0 12px;');
            var grid = document.createElement('div');
            grid.setAttribute('style', 'display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:12px;');
            grid.setAttribute('class', 'twc-list-cards');
            section.appendChild(h2);
            section.appendChild(grid);
            if (main) { main.appendChild(section); }

            if (typeof ajaxAPI !== 'undefined' && ajaxAPI.product && typeof ajaxAPI.product.getList === 'function') {
              ajaxAPI.product.getList(ids)
                .done(function(onDone){
                  debugLog('favorites:ajaxAPI:done', onDone);
                  try {
                    var products = onDone; // expected structure depends on Insales; assume array-like or id-map
                    var arr = Array.isArray(products) ? products : ids.map(function(id){ return products[id]; });
                    arr.forEach(function(p, idx){
                      if (!p) return;
                      var productId = ids[idx] || p.id;
                      var card = buildMiniCard(p, productId);
                      grid.appendChild(card);
                      // Inject list controls into each card
                      var host = card.querySelector('[data-ui-favorites-trigger-twc]');
                      if (host) {
                        var container = createListsContainer(listsData, { attach: false });
                        host.appendChild(container);
                        // Set state for current block list id using S3 data
                        var itemsForList = (block.items || []);
                        var present = itemsForList.some(function(it){ return String(it.external_item_id) === String(productId); });
                        var controls = host.querySelectorAll('.twc-list-item');
                        controls.forEach(function(ctrl){
                          var lid = ctrl.getAttribute('data-list-id');
                          var iconStyle = ctrl.getAttribute('data-icon-style');
                          var iconColor = ctrl.getAttribute('data-icon-color');
                          var isThisList = String(lid) === String(block.id);
                          var added = isThisList ? present : false;
                          ctrl.setAttribute('data-added', added ? 'true' : 'false');
                          if (added) {
                            ctrl.innerHTML = renderIcon(iconStyle, iconColor, added);
                          } else {
                            ctrl.setAttribute('style', 'display:none;');
                          }
                        });
                        // Remove card if not added to this block list
                        var currentCtrl = host.querySelector('.twc-list-item[data-list-id="' + String(block.id) + '"]');
                        if (!(currentCtrl && currentCtrl.getAttribute('data-added') === 'true')) {
                          // Call API to remove item from this list
                          getClient().then(function(client){
                            var clientId = client && client.id;
                            if (!clientId) return;
                            apiGetListItems(accountId, block.id, clientId).then(function(resp){
                              var items = (resp && resp.items) || [];
                              var match = items.find(function(x){ return String(x.item_id) === String(productId); });
                              if (match) {
                                apiRemoveItem(accountId, block.id, match.id).then(function(){
                                  debugLog('favorites:auto_remove', { list_item_id: match.id, product_id: productId });
                                  // Update header after removal
                                  updateHeaderInfo(accountId);
                                }).catch(function(err){ debugLog('favorites:auto_remove:error', err); });
                              }
                            }).catch(function(err){ debugLog('favorites:auto_remove:get_error', err); });
                          }).catch(function(err){ debugLog('favorites:auto_remove:no_client', err); });
                          card.remove();
                        }
                      }
                    });
                  } catch(e){ debugLog('favorites:render:error', e && e.message ? e.message : e); }
                })
                .fail(function(onFail){ debugLog('favorites:ajaxAPI:fail', onFail); });
            } else {
              debugLog('favorites:ajaxAPI:not_available');
            }
          });
        })
        .catch(function(err){ debugLog('favorites:page:error', err && err.message ? err.message : err); });
    }).catch(function(err){ debugLog('favorites:page:no_client', err && err.message ? err.message : err); });
  }

  function buildMiniCard(product, externalProductId) {
    var card = document.createElement('div');
    var url = product && (product.url || product.link || ('/products/' + (product.id || '')));
    // card.setAttribute('href', url || '#');
    card.setAttribute('style', 'display:flex;flex-direction:column;gap:8px;height:100%;border:1px solid #e5e7eb;border-radius:8px;padding:10px;text-decoration:none;color:#111827;background:#fff;');
    card.className = 'twc-list-card';
    var imgUrl = (product.first_image && product.first_image.large_url) || (product.images && product.images[0] && product.images[0].large_url) || product.image || '';
    
    // Wrap image in twc-list-card-img-wrap
    var imgWrap = document.createElement('div');
    imgWrap.className = 'twc-list-card-img-wrap';
    
    var img = document.createElement('img');
    img.setAttribute('src', imgUrl || '');
    img.setAttribute('alt', product.title || '');
    img.setAttribute('style', 'width:100%;height:140px;object-fit:cover;border-radius:6px;display:block;');
    
    imgWrap.appendChild(img);
    
    // Wrap title in twc-list-card-title-wrap
    var titleWrap = document.createElement('div');
    titleWrap.className = 'twc-list-card-title-wrap';
    
    var title = document.createElement('div');
    title.textContent = product.title || ('#' + (product.id || ''));
    title.setAttribute('style', 'margin-top:8px;font-size:14px;line-height:1.3;');
    
    titleWrap.appendChild(title);
    
    // Wrap controls in twc-list-card-controls-wrap
    var controlsWrap = document.createElement('div');
    controlsWrap.className = 'twc-list-card-controls-wrap';
    
    // Controls host for lists buttons
    var controlsHost = document.createElement('div');
    controlsHost.setAttribute('data-ui-favorites-trigger-twc', externalProductId || (product && product.id) || '');
    controlsHost.setAttribute('style', 'margin-top:auto;');
    
    // Price
    var priceWrap = document.createElement('div');
    priceWrap.className = 'twc-list-card-price-wrap';
    
    var price = document.createElement('div');
    price.setAttribute('style', 'font-size:16px;font-weight:bold;color:#333;margin-top:8px;');
    price.textContent = product.price_min ? ('₽' + product.price_min) : '';
    price.className = 'twc-list-card-price';
    
    priceWrap.appendChild(price);
    
    // Buy button
    var buyButtonWrap = document.createElement('div');
    buyButtonWrap.className = 'twc-list-card-buy-button-wrap';
    
    var buyButton = document.createElement('a');
    buyButton.setAttribute('href', url || '#');
    buyButton.setAttribute('style', 'display:block;width:100%;padding:8px 12px;background:#007bff;color:white;text-align:center;text-decoration:none;border-radius:4px;font-size:14px;margin-top:8px;');
    buyButton.textContent = 'Buy';
    buyButton.className = 'twc-list-card-buy-button';
    
    buyButtonWrap.appendChild(buyButton);
        
    card.appendChild(imgWrap);
    card.appendChild(titleWrap);
    card.appendChild(controlsWrap);
    card.appendChild(priceWrap);
    card.appendChild(buyButtonWrap);
    return card;
  }

  // Helper function to create list icon element
  function createListIconElement(list, itemCount) {
    var listIcon = document.createElement('span');
    listIcon.setAttribute('class', 'twc-header-list-item');
    listIcon.setAttribute('style', 'position:relative;margin-left:8px;display:block;width:24px;');
    listIcon.setAttribute('data-list-id', String(list.id));
    listIcon.setAttribute('data-list-name', list.name || '');
    listIcon.setAttribute('data-icon-style', list.icon_style || 'icon_one');
    listIcon.setAttribute('data-icon-color', list.icon_color || '#999999');
    
    var iconHtml = renderIcon(list.icon_style || 'icon_one', list.icon_color || '#999999', true);
    listIcon.innerHTML = iconHtml;
    
    // Add badge with count
    var badge = document.createElement('span');
    badge.setAttribute('class', 'header__control-bage twc-list-badge');
    badge.setAttribute('style', 'position:absolute;top:-8px;right:-8px;background:#ff4444;color:white;border-radius:50%;min-width:18px;height:18px;font-size:11px;display:flex;align-items:center;justify-content:center;padding:0 4px;');
    badge.textContent = String(itemCount);
    listIcon.appendChild(badge);
    
    return listIcon;
  }

  // Helper: delay header update to allow S3 JSON to refresh
  function delayedHeaderUpdate(accountId, delayMs) {
    var ms = typeof delayMs === 'number' ? delayMs : 300;
    setTimeout(function(){ updateHeaderInfo(accountId); }, ms);
  }

  // Update header info: first render all lists with 0, then update counts if client-specific data is available
  function updateHeaderInfo(accountId) {
    return new Promise(function(resolve) {
      var headerContainer = document.querySelector('.header__favorite');
      if (!headerContainer) {
        debugLog('updateHeaderInfo:header_not_found');
        return resolve();
      }

      // 1) Render base header with all lists and count 0
      fetchListJson(accountId)
        .then(function(baseData){
          var baseLists = (baseData && baseData.lists) || [];
          headerContainer.innerHTML = '';
          headerContainer.setAttribute('style', 'display:flex;gap:5px;');
          baseLists.forEach(function(list){
            var listIcon = createListIconElement(list, 0);
            headerContainer.appendChild(listIcon);
          });
          debugLog('updateHeaderInfo:base_rendered', { lists_count: baseLists.length });

          // 2) Try to update counts using client-specific S3 JSON
          getClient()
            .then(function(client){
              var clientId = client && client.id;
              if (!clientId) { debugLog('updateHeaderInfo:no_client'); return resolve(); }
        var url = buildS3ClientListItemsUrl(accountId, clientId) + '?t=' + Date.now();
              debugLog('updateHeaderInfo:url', url);
              return fetch(url, { credentials: 'omit', cache: 'no-cache' })
                .then(function(r){ if (!r.ok) throw new Error('S3 not available'); return r.json(); })
                .then(function(s3Data){
                  var listsData = (s3Data && s3Data.lists) || [];
                  debugLog('updateHeaderInfo:s3_lists', listsData);
                  // Build map of counts per list id
                  var countsById = {};
                  listsData.forEach(function(l){ countsById[String(l.id)] = (l.items || []).length; });
                  // Update existing badges in header
                  var icons = headerContainer.querySelectorAll('.twc-header-list-item');
                  icons.forEach(function(icon){
                    var lid = icon.getAttribute('data-list-id');
                    var badge = icon.querySelector('.twc-list-badge');
                    if (badge) { badge.textContent = String(countsById[lid] || 0); }
                  });
                  debugLog('updateHeaderInfo:updated_counts');
                  resolve();
                })
                .catch(function(err){ debugLog('updateHeaderInfo:s3_error', err && err.message ? err.message : err); resolve(); });
            })
            .catch(function(err){ debugLog('updateHeaderInfo:getClient_error', err && err.message ? err.message : err); resolve(); });
        })
        .catch(function(err){
          debugLog('updateHeaderInfo:base_error', err && err.message ? err.message : err);
          resolve();
        });
    });
  }

  // Step 4: Click handler on twc-list-item; report product id, list id, client id
  function bindListItemClickHandlers() {
    document.addEventListener('click', function(evt) {
      if (!evt.target || !evt.target.classList || !evt.target.classList.contains('twc-list-item')) return;
      // Prevent anchor navigation when clicking controls inside cards
      evt.preventDefault();
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
                // If on favorites page, remove the enclosing product card from the grid
                if (/favorites/i.test(window.location.href)) {
                  var card = itemNode.closest('.list-item');
                  if (card && card.parentNode) { card.parentNode.removeChild(card); }
                }
                // Update header info after remove (delay for S3 refresh)
                delayedHeaderUpdate(accountId, 300);
              });
            }).catch(function(err){ debugLog('lists:remove:error', err && err.message ? err.message : err); });
          } else {
            apiAddItem(accountId, listId, clientId, productId, null).then(function(resp){
              itemNode.setAttribute('data-added', 'true');
              itemNode.innerHTML = renderIcon(iconStyle, iconColor, true);
              debugLog('lists:added', resp);
              // Update header info after add (delay for S3 refresh)
              delayedHeaderUpdate(accountId, 300);
            }).catch(function(err){ debugLog('lists:add:error', err && err.message ? err.message : err); });
          }
        })
        .catch(function(){
          debugLog('lists:click:no_client');
          try { alert('Пожалуйста, зарегистрируйтесь, чтобы добавить товар в список! А ещё вы сможете смотреть свой список на любом устройстве или отправить себе на почту'); } catch(e) {}
        });
    });
  }

  // console.log('[list][debug] About to attach DOMContentLoaded listener');
  
  // Function to run initialization
  function runInitialization() {
    console.log('[list][debug] DOM ready, DEBUG status:', DEBUG);
    const accountId = getAccountIdFromScript();
    // console.log('[list][debug] Account ID:', accountId);
    // if (!accountId) { debugLog('dom:no_account_id'); return; }

    fetchListJson(accountId)
      .then(data => {
        debugLog('dom:update_triggers');
        updateFavoritesTriggers(data.lists);
        // After rendering, initialize active states
        // initListItemStates(accountId);
        // Fallback/init via S3 cache as well
        initListItemStatesFromS3(accountId);
        // Update header info
        updateHeaderInfo(accountId);
        // If favorites page, render content
        renderFavoritesPageFromS3(accountId);
      })
      .catch(function(err){ debugLog('dom:error', err && err.message ? err.message : err); console.error(err); });

    // Always bind click handlers
    bindListItemClickHandlers();
  }
  
  // Check if DOM is already loaded
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', runInitialization);
  } else {
    console.log('[list][debug] DOM already loaded, running initialization immediately');
    runInitialization();
  }
  

})();