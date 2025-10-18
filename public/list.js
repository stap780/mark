(function() {
  
  const S3_BASE = 'https://s3.twcstorage.ru/ae4cd7ee-b62e0601-19d6-483e-bbf1-416b386e5c23';
  let DEBUG = false; // Debug disabled
  
  // S3 URL builders
  function buildS3AccountListsUrl(accountId) {
    return S3_BASE + '/lists/list_' + accountId + '.json';
  }
  function buildS3ClientListItemsUrl(accountId, clientId) {
    return S3_BASE + '/lists/list_' + accountId + '_client_' + clientId + '_list_items.json';
  }
  
  // Version logging
  console.log('[list][v_0.48][loaded]');
  
  // Immediate debug check
  console.log('[list][debug] Script loaded, DEBUG:', DEBUG);
  // console.log('[list][debug] Document ready state:', document.readyState);

  function debugLog(){
    if (!DEBUG) return;
    try { console.log('[list]', ...arguments); } catch(e) { /* noop */ }
  }
  
  // Special debug function for pagination
  function paginationDebugLog(){
    if (!DEBUG) return;
    try { console.log('[pagination]', ...arguments); } catch(e) { /* noop */ }
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
    wrapper.setAttribute('style', 'display:flex;gap:12px;align-items:center;flex-wrap:wrap;');
    debugLog('createListsContainer:init', { lists_count: (lists||[]).length, containerSelector: containerSelector, attach: attach });

    (lists || []).forEach(function(list) {
      debugLog('createListsContainer:item', list);
      var item = document.createElement('span');
      item.setAttribute('style', 'display:inline-flex;align-items:center;gap:8px;cursor:pointer;width:24px;z-index: 100;');
      item.setAttribute('class', 'twc-list-item');
      item.setAttribute('data-list-id', String(list.id));
      item.setAttribute('data-list-name', list.name || '');
      item.setAttribute('data-icon-style', list.icon_style || 'icon_one');
      item.setAttribute('data-icon-color', list.icon_color || '#999999');
      item.setAttribute('data-added', 'false');

      var iconHtml = renderIcon(list.icon_style || 'icon_one', list.icon_color || '#999999', false);
      item.innerHTML = iconHtml;

      // listEl.appendChild(item);
      wrapper.appendChild(item);
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
            grid.setAttribute('style', 'display:grid;grid-template-columns:repeat(5,minmax(180px,1fr));gap:12px;');
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

  // Favorites page renderer: builds sections per list using S3 data directly (no ajaxAPI call)
  function renderFavoritesPageFromS3Direct(accountId) {
    if (!/favorites/i.test(window.location.href)) { return; }
    
    // Prevent multiple simultaneous calls
    if (window._renderFavoritesPageFromS3DirectRunning) {
      debugLog('renderFavoritesPageFromS3Direct:already_running', { accountId: accountId });
      return;
    }
    window._renderFavoritesPageFromS3DirectRunning = true;
    return getClient().then(function(client){
      var clientId = client && client.id;
      if (!clientId) return;
      var url = buildS3ClientListItemsUrl(accountId, clientId) + '?t=' + Date.now();
      debugLog('favorites:page:direct:url', url);
      return fetch(url, { credentials: 'omit', cache: 'no-cache' })
        .then(function(r){ if (!r.ok) throw new Error('S3 not available'); return r.json(); })
             .then(function(data){
               var listsData = (data && data.lists) || [];
               window.currentListsData = listsData; // Store globally for recreateEntireSection
               debugLog('favorites:page:direct:data', listsData);
          var main = document.querySelector('.lists-wrapper');
          debugLog('favorites:page:direct:main_selector', { found: !!main, selector: '.lists-wrapper' });
          if (!main) {
            main = document.querySelector('main');
            debugLog('favorites:page:direct:main_selector', { found: !!main, selector: 'main' });
          }
          if (!main) {
            main = document.querySelector('body');
            debugLog('favorites:page:direct:main_selector', { found: !!main, selector: 'body' });
          }
          if (!main) {
            debugLog('favorites:page:direct:no_main_container', 'No suitable container found');
            return;
          }
          
          debugLog('favorites:page:direct:main_clearing', { main: main, tagName: main.tagName, childrenBeforeClear: main.children.length });
          main.innerHTML = '';
          debugLog('favorites:page:direct:main_cleared', { main: main, childrenAfterClear: main.children.length });
          debugLog('favorites:page:direct:processing_lists', { listsCount: listsData.length, listsData: listsData });
          
          // Add MutationObserver to main container to track DOM changes
          if (window.MutationObserver && main) {
            var mainObserver = new MutationObserver(function(mutations) {
              mutations.forEach(function(mutation) {
                if (mutation.type === 'childList') {
                  debugLog('favorites:page:direct:main_mutation', { 
                    addedNodes: mutation.addedNodes.length, 
                    removedNodes: mutation.removedNodes.length,
                    currentChildren: main.children.length
                  });
                }
              });
            });
            mainObserver.observe(main, { childList: true, subtree: false });
          }
          
               listsData.forEach(function(block, index){
                 var items = block.items || [];
                 debugLog('renderFavoritesPageFromS3Direct:processing_list', { 
                   index: index,
                   listId: block.id, 
                   itemsCount: items.length, 
                   listName: block.name,
                   block: block
                 });
                 
                 if (!items.length) {
                   debugLog('renderFavoritesPageFromS3Direct:skipping_empty_list', { listId: block.id, listName: block.name });
                   return;
                 }
                 
                 var section = document.createElement('section');
                 section.setAttribute('style', 'margin:20px 0;padding: 20px;');
                 section.setAttribute('data-list-id', String(block.id)); // Ensure it's a string
                 
                 var h2 = document.createElement('h2');
                 h2.textContent = block.name || ('List #' + block.id);
                 h2.setAttribute('style', 'font-size:20px;margin:0 0 12px;');
                 
                 var grid = document.createElement('div');
                 grid.setAttribute('style', 'display:grid;grid-template-columns:repeat(5,minmax(180px,1fr));gap:12px;');
                 grid.setAttribute('class', 'twc-list-cards');
                 grid.setAttribute('data-list-id', String(block.id)); // Ensure it's a string
                 
                 section.appendChild(h2);
                 section.appendChild(grid);
                 if (main) { 
                   main.appendChild(section); 
                   
                   // Add MutationObserver to track section content changes
                   if (window.MutationObserver) {
                     var sectionObserver = new MutationObserver(function(mutations) {
                       mutations.forEach(function(mutation) {
                         if (mutation.type === 'childList') {
                           debugLog('renderFavoritesPageFromS3Direct:section_mutation', { 
                             listId: block.id,
                             addedNodes: mutation.addedNodes.length, 
                             removedNodes: mutation.removedNodes.length,
                             currentChildren: section.children.length,
                             targetTagName: mutation.target.tagName,
                             targetClassName: mutation.target.className
                           });
                         } else if (mutation.type === 'characterData') {
                           debugLog('renderFavoritesPageFromS3Direct:text_mutation', { 
                             listId: block.id,
                             targetTagName: mutation.target.tagName,
                             currentChildren: section.children.length
                           });
                         }
                       });
                     });
                     sectionObserver.observe(section, { childList: true, subtree: true, characterData: true });
                   }
                   
                   // Store original innerHTML to detect changes
                   var originalHTML = section.innerHTML;
                   var checkHTML = function() {
                     if (section.innerHTML !== originalHTML) {
                       debugLog('renderFavoritesPageFromS3Direct:innerHTML_changed', { 
                         listId: block.id,
                         originalLength: originalHTML.length,
                         newLength: section.innerHTML.length,
                         currentChildren: section.children.length,
                         addedContent: section.innerHTML.substring(originalHTML.length, originalHTML.length + 200) + '...'
                       });
                       originalHTML = section.innerHTML; // Update for next check
                     }
                   };
                   
                   // Check for innerHTML changes every 10ms for the first 200ms
                   var checkInterval = setInterval(function() {
                     checkHTML();
                   }, 10);
                   setTimeout(function() {
                     clearInterval(checkInterval);
                   }, 200);
                   
                   debugLog('renderFavoritesPageFromS3Direct:section_added', { 
                     listId: block.id, 
                     listName: block.name,
                     mainChildren: main.children.length,
                     sectionChildren: section.children.length
                   });
                 }

                 // Add pagination for this list
                 debugLog('renderFavoritesPageFromS3Direct:adding_pagination', { listId: block.id, listIdType: typeof block.id });
                 addPaginationToSection(section, items, String(block.id), 20, block); // Pass the block data
               });
        })
        .catch(function(err){ debugLog('favorites:page:direct:error', err && err.message ? err.message : err); });
    }).catch(function(err){ debugLog('favorites:page:direct:no_client', err && err.message ? err.message : err); })
    .finally(function() {
      window._renderFavoritesPageFromS3DirectRunning = false;
    });
  }

  // Add pagination functionality to a section
  function addPaginationToSection(section, items, listId, itemsPerPage, listData) {
    var grid = section.querySelector('.twc-list-cards');
    if (!grid) return;
    
    var totalItems = items.length;
    var totalPages = Math.ceil(totalItems / itemsPerPage);
    
    paginationDebugLog('addPaginationToSection', { listId: listId, totalItems: totalItems, totalPages: totalPages, itemsPerPage: itemsPerPage });
    
    if (totalPages <= 1) {
      // No pagination needed, show all items
      paginationDebugLog('addPaginationToSection:no_pagination_needed', { listId: listId });
      renderItemsForPage(grid, items, 0, itemsPerPage, listId, listData);
      return;
    }
    
    // Create pagination container
    var paginationContainer = document.createElement('div');
    paginationContainer.className = 'twc-pagination-container';
    paginationContainer.setAttribute('style', 'display:flex;justify-content:center;align-items:center;gap:8px;margin:20px 0;');
    paginationContainer.setAttribute('data-list-id', listId);
    paginationContainer.setAttribute('data-all-items', JSON.stringify(items));
    paginationContainer.setAttribute('data-items-per-page', itemsPerPage);
    
    // Create pagination controls
    var paginationControls = createPaginationControls(listId, totalPages, listData);
    paginationContainer.appendChild(paginationControls);
    
    // Add pagination after the grid
    section.appendChild(paginationContainer);
    
    // Also store on grid element for defensive recreation
    grid.setAttribute('data-all-items', JSON.stringify(items));
    grid.setAttribute('data-items-per-page', itemsPerPage);
    
    // Store references for later use
    section._paginationContainer = paginationContainer;
    section._paginationControls = paginationControls;
    
    paginationDebugLog('addPaginationToSection:container_added', { 
      listId: listId, 
      sectionChildren: section.children.length,
      paginationContainerExists: !!paginationContainer,
      paginationControlsExists: !!paginationControls,
      sectionHTML: section.innerHTML.substring(0, 300) + '...'
    });
    
    // Debug: Check if pagination container is actually in the DOM after a short delay
    setTimeout(function() {
      var actualPaginationContainer = section.querySelector('.twc-pagination-container');
      paginationDebugLog('addPaginationToSection:dom_check', { 
        listId: listId, 
        sectionChildren: section.children.length,
        paginationContainerInDOM: !!actualPaginationContainer,
        paginationContainerExists: !!paginationContainer,
        sectionHTML: section.innerHTML.substring(0, 200) + '...'
      });
    }, 50);
    
    // Add a mutation observer to track when the pagination container is removed
    if (window.MutationObserver) {
      var observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
          if (mutation.type === 'childList') {
            mutation.removedNodes.forEach(function(node) {
              if (node === paginationContainer || (node.nodeType === 1 && node.classList && node.classList.contains('twc-pagination-container'))) {
                paginationDebugLog('addPaginationToSection:pagination_container_removed', { 
                  listId: listId, 
                  removedNode: node.tagName || node.nodeType,
                  sectionChildren: section.children.length,
                  removedBy: mutation.target.tagName || 'unknown'
                });
              }
            });
          }
        });
      });
      observer.observe(section, { childList: true, subtree: true });
      
      // Store observer for cleanup
      section._paginationObserver = observer;
    }
    
         // Show first page initially
         // paginationDebugLog('addPaginationToSection:showing_first_page', { listId: listId });
         renderItemsForPage(grid, items, 0, itemsPerPage, listId, listData);
    
    // Use setTimeout to ensure DOM is updated before calling updatePaginationState
    // Store reference to the section to avoid issues with DOM queries
    var sectionRef = section;
    setTimeout(function() {
      paginationDebugLog('setTimeout:callback', { 
        listId: listId, 
        sectionFound: !!sectionRef,
        hasPaginationContainer: sectionRef ? !!sectionRef.querySelector('.twc-pagination-container') : false,
        sectionChildren: sectionRef ? sectionRef.children.length : 0
      });
      
      if (sectionRef && sectionRef.querySelector('.twc-pagination-container')) {
        updatePaginationState(listId, 1, totalPages);
      }
    }, 100);
  }
  
  // Recreate pagination for a section that lost its pagination container
  function recreatePaginationForSection(section, items, listId, itemsPerPage, totalPages) {
    paginationDebugLog('recreatePaginationForSection:start', { listId: listId, totalPages: totalPages });
    
    // Create pagination container
    var paginationContainer = document.createElement('div');
    paginationContainer.className = 'twc-pagination-container';
    paginationContainer.setAttribute('style', 'display:flex;justify-content:center;align-items:center;gap:8px;margin:20px 0;');
    paginationContainer.setAttribute('data-list-id', listId);
    paginationContainer.setAttribute('data-all-items', JSON.stringify(items));
    paginationContainer.setAttribute('data-items-per-page', itemsPerPage);
    
    // Create pagination controls
    var paginationControls = createPaginationControls(listId, totalPages, listData);
    paginationContainer.appendChild(paginationControls);
    
    // Add pagination after the grid
    section.appendChild(paginationContainer);
    
    // Store references for later use
    section._paginationContainer = paginationContainer;
    section._paginationControls = paginationControls;
    
    // paginationDebugLog('recreatePaginationForSection:completed', { 
    //   listId: listId, 
    //   sectionChildren: section.children.length,
    //   paginationContainerExists: !!paginationContainer
    // });
    
    // Update pagination state
    updatePaginationState(listId, 1, totalPages);
  }
  
  // Handle item removal from pagination
  function handleItemRemoval(listId, removedItemId) {
    paginationDebugLog('handleItemRemoval:start', { listId: listId, removedItemId: removedItemId });
    
    // Find the section and pagination container
    var section = document.querySelector('[data-list-id="' + listId + '"]');
    if (!section) {
      paginationDebugLog('handleItemRemoval:section_not_found', { listId: listId });
      return;
    }
    
    var paginationContainer = section.querySelector('.twc-pagination-container');
    if (!paginationContainer) {
      paginationDebugLog('handleItemRemoval:pagination_not_found', { listId: listId });
      return;
    }
    
    // Get current items from stored data
    var storedItems = paginationContainer.getAttribute('data-all-items');
    if (!storedItems) {
      paginationDebugLog('handleItemRemoval:no_stored_items', { listId: listId });
      return;
    }
    
    try {
      var items = JSON.parse(storedItems);
      var originalCount = items.length;
      
      // Remove the item from the stored data
      items = items.filter(function(item) {
        return item.external_item_id !== removedItemId;
      });
      
      var newCount = items.length;
      paginationDebugLog('handleItemRemoval:item_removed', { 
        listId: listId, 
        originalCount: originalCount, 
        newCount: newCount 
      });
      
      // Update stored data
      paginationContainer.setAttribute('data-all-items', JSON.stringify(items));
      
      // Also update grid data
      var grid = section.querySelector('.twc-list-cards');
      if (grid) {
        grid.setAttribute('data-all-items', JSON.stringify(items));
      }
      
      // Recalculate pagination
      var itemsPerPage = parseInt(paginationContainer.getAttribute('data-items-per-page')) || 20;
      var totalPages = Math.ceil(items.length / itemsPerPage);
      
      // Update pagination controls
      var controls = paginationContainer.querySelector('.twc-pagination-controls');
      if (controls) {
        controls.setAttribute('data-total-pages', totalPages);
      }
      
      // Re-render current page
      var currentPage = parseInt(controls.getAttribute('data-current-page')) || 1;
      if (currentPage > totalPages && totalPages > 0) {
        currentPage = totalPages;
      }
      
      paginationDebugLog('handleItemRemoval:recalculating', { 
        listId: listId, 
        totalPages: totalPages, 
        currentPage: currentPage 
      });
      
      // Re-render the current page
      if (grid && items.length > 0) {
        var startIndex = (currentPage - 1) * itemsPerPage;
        // Get currentListData from global data
        var currentListData = null;
        if (window.currentListsData) {
          currentListData = window.currentListsData.find(function(list) {
            return String(list.id) === String(listId);
          });
        }
        renderItemsForPage(grid, items, startIndex, itemsPerPage, listId, currentListData);
        updatePaginationState(listId, currentPage, totalPages);
      } else if (items.length === 0) {
        // No items left, remove pagination
        paginationContainer.remove();
        paginationDebugLog('handleItemRemoval:no_items_left', { listId: listId });
      }
      
    } catch (e) {
      paginationDebugLog('handleItemRemoval:error', { listId: listId, error: e.message });
    }
  }
  
  // Recreate entire section when it has been corrupted
  function recreateEntireSection(listId, items, itemsPerPage, totalPages, listData) {
    paginationDebugLog('recreateEntireSection:start', { listId: listId, totalPages: totalPages, hasItems: !!items });
    
    // Find the main container
    var main = document.querySelector('.lists-wrapper') || document.querySelector('main') || document.querySelector('body');
    if (!main) {
      paginationDebugLog('recreateEntireSection:no_main_container', { listId: listId });
      return;
    }
    
    // Remove ALL sections with this list ID (there might be duplicates)
    var corruptedSections = document.querySelectorAll('[data-list-id="' + listId + '"]');
    paginationDebugLog('recreateEntireSection:removing_sections', { 
      listId: listId, 
      foundSections: corruptedSections.length 
    });
    
    corruptedSections.forEach(function(section, index) {
      paginationDebugLog('recreateEntireSection:removing_section', { 
        listId: listId, 
        sectionIndex: index,
        sectionChildren: section.children.length
      });
      section.remove();
    });
    
    // Try to find the original list data from the global data
    var originalList = null;
    var listName = 'List #' + listId; // Default fallback
    try {
      // Look for the list name in the current listsData if available
      if (typeof window.currentListsData !== 'undefined' && Array.isArray(window.currentListsData)) {
        originalList = window.currentListsData.find(function(list) {
          return String(list.id) === String(listId);
        });
        if (originalList && originalList.name) {
          listName = originalList.name;
        }
      }
    } catch (e) {
      paginationDebugLog('recreateEntireSection:name_fallback', { listId: listId, error: e.message });
    }
    
    // If we don't have items, try to get them from the original list data
    if (!items && originalList && originalList.items) {
      items = originalList.items;
      paginationDebugLog('recreateEntireSection:items_recovered', { listId: listId, itemsCount: items.length });
    }
    
    // Create new section
    var section = document.createElement('section');
    section.setAttribute('style', 'margin:20px 0;padding: 20px;');
    section.setAttribute('data-list-id', String(listId));
    
    var h2 = document.createElement('h2');
    h2.textContent = listName;
    h2.setAttribute('style', 'font-size:20px;margin:0 0 12px;');
    
    var grid = document.createElement('div');
    grid.setAttribute('style', 'display:grid;grid-template-columns:repeat(5,minmax(180px,1fr));gap:12px;');
    grid.setAttribute('class', 'twc-list-cards');
    grid.setAttribute('data-list-id', String(listId));
    
    section.appendChild(h2);
    section.appendChild(grid);
    main.appendChild(section);
    
    paginationDebugLog('recreateEntireSection:section_created', { 
      listId: listId, 
      listName: listName,
      sectionChildren: section.children.length,
      hasItems: !!items
    });
    
    // Now add pagination to the new section if we have items
    if (items && items.length > 0) {
      addPaginationToSection(section, items, listId, itemsPerPage || 20, listData || originalList);
    } else {
      paginationDebugLog('recreateEntireSection:no_items_to_paginate', { listId: listId });
    }
  }
    
  // Create pagination controls (Previous, page numbers, Next)
  function createPaginationControls(listId, totalPages, listData) {
    paginationDebugLog('createPaginationControls:start', { listId: listId, totalPages: totalPages });
    
    var controls = document.createElement('div');
    controls.className = 'twc-pagination-controls';
    controls.setAttribute('style', 'display:flex;gap:4px;align-items:center;');
    
    // Previous button
    var prevBtn = document.createElement('button');
    prevBtn.textContent = '‹';
    prevBtn.className = 'twc-pagination-btn twc-pagination-prev';
    prevBtn.setAttribute('style', 'padding:8px 12px;border:1px solid #ddd;background:#fff;cursor:pointer;border-radius:4px;');
    prevBtn.setAttribute('data-list-id', listId);
    prevBtn.setAttribute('data-action', 'prev');
    controls.appendChild(prevBtn);
    
    // Page numbers container
    var pageNumbersContainer = document.createElement('div');
    pageNumbersContainer.className = 'twc-pagination-numbers';
    pageNumbersContainer.setAttribute('style', 'display:flex;gap:4px;');
    pageNumbersContainer.setAttribute('data-list-id', listId);
    controls.appendChild(pageNumbersContainer);
    
    // Next button
    var nextBtn = document.createElement('button');
    nextBtn.textContent = '›';
    nextBtn.className = 'twc-pagination-btn twc-pagination-next';
    nextBtn.setAttribute('style', 'padding:8px 12px;border:1px solid #ddd;background:#fff;cursor:pointer;border-radius:4px;');
    nextBtn.setAttribute('data-list-id', listId);
    nextBtn.setAttribute('data-action', 'next');
    controls.appendChild(nextBtn);
    
    // Bind click handlers
    controls.addEventListener('click', function(e) {
      if (e.target.classList.contains('twc-pagination-btn')) {
        var action = e.target.getAttribute('data-action');
        var currentPage = parseInt(controls.getAttribute('data-current-page') || '1');
        var newPage;
        
        if (action === 'prev') {
          newPage = Math.max(1, currentPage - 1);
        } else if (action === 'next') {
          newPage = Math.min(totalPages, currentPage + 1);
        } else if (e.target.hasAttribute('data-page')) {
          newPage = parseInt(e.target.getAttribute('data-page'));
        } else {
          // Try to parse page number from text content
          newPage = parseInt(e.target.textContent);
        }
        
        if (newPage && newPage !== currentPage && newPage >= 1 && newPage <= totalPages) {
          paginationDebugLog('pagination:click', { listId: listId, currentPage: currentPage, newPage: newPage, action: action });
          goToPage(listId, newPage, totalPages, listData);
        }
      }
    });
    
    paginationDebugLog('createPaginationControls:completed', { 
      listId: listId, 
      controlsChildren: controls.children.length,
      prevBtn: !!prevBtn,
      nextBtn: !!nextBtn,
      pageNumbersContainer: !!pageNumbersContainer
    });
    
    return controls;
  }
  
  // Render items for a specific page
  function renderItemsForPage(grid, items, startIndex, itemsPerPage, listId, listData) {
    paginationDebugLog('renderItemsForPage:start', { 
      listId: listId, 
      startIndex: startIndex, 
      itemsPerPage: itemsPerPage, 
      totalItems: items.length, 
      gridExists: !!grid,
      listData: listData,
      hasListData: !!listData
    });
    
    if (!grid) {
      paginationDebugLog('renderItemsForPage:no_grid', { listId: listId });
      return;
    }
    
    // Clear existing items
    grid.innerHTML = '';
    
    var endIndex = Math.min(startIndex + itemsPerPage, items.length);
    var pageItems = items.slice(startIndex, endIndex);
    
    paginationDebugLog('renderItemsForPage:items', { endIndex: endIndex, pageItemsCount: pageItems.length, firstItem: pageItems[0] });
    
    pageItems.forEach(function(item, index) {
      try {
        var card = buildMiniCardFromS3Data(item, [], listData);
        if (card) {
          grid.appendChild(card);
        } else {
          paginationDebugLog('renderItemsForPage:card_creation_failed', { index: index, item: item });
        }
      } catch (e) {
        paginationDebugLog('renderItemsForPage:card_error', { index: index, error: e.message, item: item });
      }
    });
    
    paginationDebugLog('renderItemsForPage:completed', { renderedCount: pageItems.length, gridChildrenCount: grid.children.length });
  }
  
  // Go to specific page
  function goToPage(listId, page, totalPages, listData) {
    paginationDebugLog('goToPage:start', { listId: listId, page: page, totalPages: totalPages });
    
    // Try different selectors to find the section
    var section = document.querySelector('[data-list-id="' + listId + '"]');
    if (!section) {
      // Try finding by class and data attribute
      section = document.querySelector('section[data-list-id="' + listId + '"]');
    }
    if (!section) {
      // Try finding all sections and check their data-list-id
      var allSections = document.querySelectorAll('section');
      for (var i = 0; i < allSections.length; i++) {
        if (allSections[i].getAttribute('data-list-id') === String(listId)) {
          section = allSections[i];
          break;
        }
      }
    }
    
    if (!section) {
      paginationDebugLog('goToPage:section_not_found', { listId: listId, allSections: document.querySelectorAll('section').length });
      // Debug: log all sections and their data-list-id attributes
      var allSections = document.querySelectorAll('section');
      allSections.forEach(function(s, index) {
        paginationDebugLog('goToPage:section_debug', { index: index, dataListId: s.getAttribute('data-list-id'), className: s.className });
      });
      return;
    }
    
    var grid = section.querySelector('.twc-list-cards');
    var paginationContainer = section._paginationContainer || section.querySelector('.twc-pagination-container');
    
    paginationDebugLog('goToPage:elements_found', { 
      section: !!section, 
      grid: !!grid, 
      container: !!paginationContainer,
      sectionDataListId: section ? section.getAttribute('data-list-id') : 'none',
      sectionChildren: section ? section.children.length : 0,
      sectionChildrenDetails: section ? Array.from(section.children).map(function(child, index) {
        return { index: index, tagName: child.tagName, className: child.className };
      }) : [],
      sectionHTML: section ? section.innerHTML.substring(0, 200) + '...' : 'none'
    });
    
    if (!grid || !paginationContainer) {
      paginationDebugLog('goToPage:grid_or_container_not_found', { 
        grid: !!grid, 
        container: !!paginationContainer,
        sectionChildren: section ? section.children.length : 0
      });
      return;
    }
    
    // Get all items for this list
    var allItems = paginationContainer.getAttribute('data-all-items');
    var itemsPerPage = parseInt(paginationContainer.getAttribute('data-items-per-page')) || 20;
    
    if (!allItems) {
      paginationDebugLog('goToPage:no_items_data');
      return;
    }
    
    try {
      var items = JSON.parse(allItems);
      var startIndex = (page - 1) * itemsPerPage;
      
      paginationDebugLog('goToPage:rendering', { itemsCount: items.length, startIndex: startIndex, itemsPerPage: itemsPerPage });
      
      renderItemsForPage(grid, items, startIndex, itemsPerPage, listId, listData);
      updatePaginationState(listId, page, totalPages);
      
      paginationDebugLog('goToPage:completed', { page: page });
    } catch (e) {
      paginationDebugLog('pagination:error', e);
    }
  }
  
  // Update pagination state (active page, button states)
  function updatePaginationState(listId, currentPage, totalPages) {
    paginationDebugLog('updatePaginationState:start', { listId: listId, currentPage: currentPage, totalPages: totalPages });
    
    var section = document.querySelector('[data-list-id="' + listId + '"]');
    if (!section) {
      paginationDebugLog('updatePaginationState:section_not_found', { listId: listId });
      return;
    }
    
    // Try to get pagination container from stored reference first, then fallback to querySelector
    var paginationContainer = section._paginationContainer || section.querySelector('.twc-pagination-container');
    
    paginationDebugLog('updatePaginationState:container_found', { 
      listId: listId, 
      container: !!paginationContainer,
      fromStored: !!section._paginationContainer,
      fromQuery: !!section.querySelector('.twc-pagination-container'),
      sectionChildren: section.children.length,
      sectionHTML: section.innerHTML.substring(0, 200) + '...',
      sectionChildrenDetails: Array.from(section.children).map(function(child, index) {
        return { index: index, tagName: child.tagName, className: child.className };
      })
    });
    
    if (!paginationContainer) {
      paginationDebugLog('updatePaginationState:container_not_found', { 
        listId: listId, 
        sectionChildren: section.children.length,
        sectionHTML: section.innerHTML.substring(0, 200) + '...'
      });
      
      // Try to recreate pagination if it's missing
      var grid = section.querySelector('.twc-list-cards');
      if (grid) {
        paginationDebugLog('updatePaginationState:attempting_recreation', { listId: listId });
        // Get stored items from the grid's data attribute
        var storedItems = grid.getAttribute('data-all-items');
        var storedItemsPerPage = grid.getAttribute('data-items-per-page');
        if (storedItems) {
          try {
            var items = JSON.parse(storedItems);
            var itemsPerPage = storedItemsPerPage ? parseInt(storedItemsPerPage) : 20;
            var totalPages = Math.ceil(items.length / itemsPerPage);
            addPaginationToSection(section, items, listId, itemsPerPage, null);
            paginationDebugLog('updatePaginationState:recreation_success', { listId: listId });
          } catch (e) {
            paginationDebugLog('updatePaginationState:recreation_failed', { listId: listId, error: e.message });
          }
        } else {
          paginationDebugLog('updatePaginationState:no_stored_items', { listId: listId });
        }
      } else {
        paginationDebugLog('updatePaginationState:no_grid_found', { listId: listId });
        // Try to recreate the entire section if it's corrupted
        recreateEntireSection(listId, null, 20, 0, null);
      }
      return;
    }
    
    var controls = paginationContainer.querySelector('.twc-pagination-controls');
    var pageNumbersContainer = paginationContainer.querySelector('.twc-pagination-numbers');
    
    if (!controls || !pageNumbersContainer) {
      // paginationDebugLog('updatePaginationState:controls_not_found', { 
      //   listId: listId, 
      //   controls: !!controls, 
      //   pageNumbersContainer: !!pageNumbersContainer 
      // });
      return;
    }
    
    // Update current page attribute
    controls.setAttribute('data-current-page', currentPage);
    
    // Update prev/next button states
    var prevBtn = controls.querySelector('.twc-pagination-prev');
    var nextBtn = controls.querySelector('.twc-pagination-next');
    
    if (prevBtn) {
      prevBtn.disabled = currentPage === 1;
      prevBtn.style.opacity = currentPage === 1 ? '0.5' : '1';
      prevBtn.style.cursor = currentPage === 1 ? 'not-allowed' : 'pointer';
    }
    
    if (nextBtn) {
      nextBtn.disabled = currentPage === totalPages;
      nextBtn.style.opacity = currentPage === totalPages ? '0.5' : '1';
      nextBtn.style.cursor = currentPage === totalPages ? 'not-allowed' : 'pointer';
    }
    
    // Update page numbers
    pageNumbersContainer.innerHTML = '';
    
    // Show page numbers (max 5 visible at a time)
    var startPage = Math.max(1, currentPage - 2);
    var endPage = Math.min(totalPages, currentPage + 2);
    
    for (var i = startPage; i <= endPage; i++) {
      var pageBtn = document.createElement('button');
      pageBtn.textContent = i;
      pageBtn.className = 'twc-pagination-btn twc-pagination-page';
      pageBtn.setAttribute('style', 'padding:8px 12px;border:1px solid #ddd;background:' + (i === currentPage ? '#007bff' : '#fff') + ';color:' + (i === currentPage ? '#fff' : '#333') + ';cursor:pointer;border-radius:4px;');
      pageBtn.setAttribute('data-list-id', listId);
      pageBtn.setAttribute('data-page', i);
      pageNumbersContainer.appendChild(pageBtn);
    }
  }

  // Build mini card from S3 data directly
  function buildMiniCardFromS3Data(item, listsData, currentListData) {
    var card = document.createElement('div');
    var url = item.item_link || '#';
    card.setAttribute('style', 'display:flex;flex-direction:column;gap:8px;height:100%;border:1px solid #e5e7eb;border-radius:8px;padding:10px;text-decoration:none;color:#111827;background:#fff;');
    card.className = 'twc-list-card';
    
    // Wrap image in twc-list-card-img-wrap
    var imgWrap = document.createElement('div');
    imgWrap.className = 'twc-list-card-img-wrap';
    
    // Create link wrapper for image
    var imgLink = document.createElement('a');
    imgLink.setAttribute('href', url);
    imgLink.setAttribute('style', 'display:block;');
    
    var img = document.createElement('img');
    img.setAttribute('src', item.item_image || '');
    img.setAttribute('alt', item.item_title || '');
    img.setAttribute('style', 'width:100%;height:180px;object-fit:cover;border-radius:6px;display:block;');
    
    imgLink.appendChild(img);
    imgWrap.appendChild(imgLink);
    
    // Wrap title in twc-list-card-title-wrap
    var titleWrap = document.createElement('div');
    titleWrap.className = 'twc-list-card-title-wrap';
    
    var title = document.createElement('a');
    title.setAttribute('href', url);
    title.setAttribute('style', 'margin-top:8px;font-size:14px;line-height:1.3;color:#333;text-decoration:none;');
    title.textContent = item.item_title || ('#' + item.external_item_id);
    title.className = 'twc-list-card-title';
    
    titleWrap.appendChild(title);
    
    // Wrap controls in twc-list-card-controls-wrap
    var controlsWrap = document.createElement('div');
    controlsWrap.className = 'twc-list-card-controls-wrap';
    
    // Controls host for lists buttons
    var controlsHost = document.createElement('div');
    controlsHost.setAttribute('data-ui-favorites-trigger-twc', item.external_item_id || '');
    controlsHost.setAttribute('style', 'margin-top:auto;');
    
    // Show icon that corresponds to the current list
    debugLog('buildMiniCardFromS3Data:currentListData', { 
      currentListData: currentListData, 
      hasCurrentListData: !!currentListData,
      itemId: item.external_item_id 
    });
    
    if (currentListData) {
      var listItem = document.createElement('span');
      listItem.setAttribute('style', 'display:inline-flex;align-items:center;gap:8px;cursor:pointer;width:24px;z-index: 100;');
      listItem.setAttribute('class', 'twc-list-item');
      listItem.setAttribute('data-list-id', String(currentListData.id));
      listItem.setAttribute('data-list-name', currentListData.name || '');
      listItem.setAttribute('data-icon-style', currentListData.icon_style || 'icon_one');
      listItem.setAttribute('data-icon-color', currentListData.icon_color || '#999999');
      listItem.setAttribute('data-added', 'true'); // Item is in this list
      
      var iconHtml = renderIcon(currentListData.icon_style || 'icon_one', currentListData.icon_color || '#999999', true);
      listItem.innerHTML = iconHtml;
      
      controlsHost.appendChild(listItem);
      debugLog('buildMiniCardFromS3Data:icon_added', { 
        listId: currentListData.id, 
        listName: currentListData.name,
        iconStyle: currentListData.icon_style 
      });
    } else {
      debugLog('buildMiniCardFromS3Data:no_currentListData', { 
        itemId: item.external_item_id,
        currentListData: currentListData 
      });
    }
    
    controlsWrap.appendChild(controlsHost);
    
    // Price
    var priceWrap = document.createElement('div');
    priceWrap.className = 'twc-list-card-price-wrap';
    
    var price = document.createElement('div');
    price.setAttribute('style', 'font-size:16px;font-weight:bold;color:#333;margin-top:8px;');
    price.textContent = item.item_price || '0';
    price.className = 'twc-list-card-price';
    
    priceWrap.appendChild(price);
    
    // Buy button
    var buyButtonWrap = document.createElement('div');
    buyButtonWrap.className = 'twc-list-card-buy-button-wrap';
    
    var buyButton = document.createElement('a');
    buyButton.setAttribute('href', url);
    buyButton.setAttribute('style', 'display:flex;align-items:center;justify-content:center;width:100%;padding:8px 12px;background:#007bff;color:white;text-decoration:none;border-radius:4px;margin-top:8px;');
    buyButton.className = 'twc-list-card-buy-button';
    
    // Add cart SVG icon
    var cartIcon = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    cartIcon.setAttribute('width', '16');
    cartIcon.setAttribute('height', '16');
    cartIcon.setAttribute('viewBox', '0 0 640 512');
    cartIcon.setAttribute('fill', 'white');
    cartIcon.innerHTML = '<path d="M24-16C10.7-16 0-5.3 0 8S10.7 32 24 32l45.3 0c3.9 0 7.2 2.8 7.9 6.6l52.1 286.3c6.2 34.2 36 59.1 70.8 59.1L456 384c13.3 0 24-10.7 24-24s-10.7-24-24-24l-255.9 0c-11.6 0-21.5-8.3-23.6-19.7l-5.1-28.3 303.6 0c30.8 0 57.2-21.9 62.9-52.2L568.9 69.9C572.6 50.2 557.5 32 537.4 32l-412.7 0-.4-2c-4.8-26.6-28-46-55.1-46L24-16zM208 512a48 48 0 1 0 0-96 48 48 0 1 0 0 96zm224 0a48 48 0 1 0 0-96 48 48 0 1 0 0 96z"/>';
    
    buyButton.appendChild(cartIcon);
    buyButtonWrap.appendChild(buyButton);
        
    card.appendChild(imgWrap);
    card.appendChild(titleWrap);
    card.appendChild(controlsWrap);
    card.appendChild(priceWrap);
    card.appendChild(buyButtonWrap);
    return card;
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
    
    // Create link wrapper for image
    var imgLink = document.createElement('a');
    imgLink.setAttribute('href', url || '#');
    imgLink.setAttribute('style', 'display:block;');
    
    var img = document.createElement('img');
    img.setAttribute('src', imgUrl || '');
    img.setAttribute('alt', product.title || '');
    img.setAttribute('style', 'width:100%;height:180px;object-fit:cover;border-radius:6px;display:block;');
    
    imgLink.appendChild(img);
    imgWrap.appendChild(imgLink);
    
    // Wrap title in twc-list-card-title-wrap
    var titleWrap = document.createElement('div');
    titleWrap.className = 'twc-list-card-title-wrap';
    
    var title = document.createElement('a');
    title.setAttribute('href', url || '#');
    title.setAttribute('style', 'margin-top:8px;font-size:14px;line-height:1.3;color:#333;text-decoration:none;');
    title.textContent = product.title || ('#' + (product.id || ''));
    title.className = 'twc-list-card-title';
    
    titleWrap.appendChild(title);
    
    // Wrap controls in twc-list-card-controls-wrap
    var controlsWrap = document.createElement('div');
    controlsWrap.className = 'twc-list-card-controls-wrap';
    
    // Controls host for lists buttons
    var controlsHost = document.createElement('div');
    controlsHost.setAttribute('data-ui-favorites-trigger-twc', externalProductId || (product && product.id) || '');
    controlsHost.setAttribute('style', 'margin-top:auto;');
    
    controlsWrap.appendChild(controlsHost);
    
    // Price
    var priceWrap = document.createElement('div');
    priceWrap.className = 'twc-list-card-price-wrap';
    
    var price = document.createElement('div');
    price.setAttribute('style', 'font-size:16px;font-weight:bold;color:#333;margin-top:8px;');
    price.textContent = product.price_min;
    price.className = 'twc-list-card-price';
    
    priceWrap.appendChild(price);
    
    // Buy button
    var buyButtonWrap = document.createElement('div');
    buyButtonWrap.className = 'twc-list-card-buy-button-wrap';
    
    var buyButton = document.createElement('a');
    buyButton.setAttribute('href', url || '#');
    buyButton.setAttribute('style', 'display:flex;align-items:center;justify-content:center;width:100%;padding:8px 12px;background:#007bff;color:white;text-decoration:none;border-radius:4px;margin-top:8px;');
    buyButton.className = 'twc-list-card-buy-button';
    
    // Add cart SVG icon
    var cartIcon = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    cartIcon.setAttribute('width', '16');
    cartIcon.setAttribute('height', '16');
    cartIcon.setAttribute('viewBox', '0 0 640 512');
    cartIcon.setAttribute('fill', 'white');
    cartIcon.innerHTML = '<path d="M24-16C10.7-16 0-5.3 0 8S10.7 32 24 32l45.3 0c3.9 0 7.2 2.8 7.9 6.6l52.1 286.3c6.2 34.2 36 59.1 70.8 59.1L456 384c13.3 0 24-10.7 24-24s-10.7-24-24-24l-255.9 0c-11.6 0-21.5-8.3-23.6-19.7l-5.1-28.3 303.6 0c30.8 0 57.2-21.9 62.9-52.2L568.9 69.9C572.6 50.2 557.5 32 537.4 32l-412.7 0-.4-2c-4.8-26.6-28-46-55.1-46L24-16zM208 512a48 48 0 1 0 0-96 48 48 0 1 0 0 96zm224 0a48 48 0 1 0 0-96 48 48 0 1 0 0 96z"/>';
    
    buyButton.appendChild(cartIcon);
    
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
                  var card = itemNode.closest('.twc-list-card');
                  if (card && card.parentNode) { 
                    // Get the productId and listId BEFORE removing the card
                    var section = card.closest('[data-list-id]');
                    var productId = itemNode.closest('[data-ui-favorites-trigger-twc]').getAttribute('data-ui-favorites-trigger-twc');
                    var listId = section ? section.getAttribute('data-list-id') : null;
                    
                    // Remove the card from DOM
                    card.parentNode.removeChild(card);
                    
                    // Update pagination after removing item
                    if (section && listId && productId) {
                      // Use the new handleItemRemoval function
                      handleItemRemoval(listId, productId);
                    }
                  }
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
        // Only run initListItemStatesFromS3 if NOT on favorites page
        if (!/favorites/i.test(window.location.href)) {
          initListItemStatesFromS3(accountId).then(function() {
            // Add a small delay to ensure initListItemStatesFromS3 has completely finished
            setTimeout(function() {
              // Update header info
              updateHeaderInfo(accountId);
              // renderFavoritesPageFromS3(accountId);
              // Render favorites page using direct S3 data
              renderFavoritesPageFromS3Direct(accountId);
            }, 50);
          }).catch(function(err) {
            debugLog('initListItemStatesFromS3:failed', err && err.message ? err.message : err);
            // Still render favorites page even if initListItemStatesFromS3 fails
            updateHeaderInfo(accountId);
            renderFavoritesPageFromS3Direct(accountId);
          });
        } else {
          // On favorites page, skip initListItemStatesFromS3 completely and go directly to rendering
          updateHeaderInfo(accountId);
          // Only render if not already rendered (avoid recreating pagination)
          if (!document.querySelector('[data-list-id]')) {
            renderFavoritesPageFromS3Direct(accountId);
          }
        }
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