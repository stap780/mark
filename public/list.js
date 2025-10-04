(function() {
  'use strict';

  // Configuration
  const CONFIG = {
    apiBaseUrl: window.location.origin, // Use current domain
    endpoints: {
      addItem: '/api/accounts/{account_id}/lists/{list_id}/list_items',
      removeItem: '/api/accounts/{account_id}/lists/{list_id}/list_items/{item_id}',
      getItems: '/api/accounts/{account_id}/lists/{list_id}/list_items'
    },
    s3Fallback: {
      enabled: true,
      baseUrl: 'https://s3.twcstorage.ru',
      path: '/lists/{account_id}/{client_id}/{list_id}.json'
    },
    debug: {
      enabled: false, // Set to true to enable debug logging
      logLevel: 'info' // 'debug', 'info', 'warn', 'error'
    }
  };

  // Debug logging utility
  function debugLog(level, message, data = null) {
    if (!CONFIG.debug.enabled) return;
    
    const levels = { debug: 0, info: 1, warn: 2, error: 3 };
    const currentLevel = levels[CONFIG.debug.logLevel] || 1;
    const messageLevel = levels[level] || 1;
    
    if (messageLevel >= currentLevel) {
      const timestamp = new Date().toISOString();
      const prefix = `[List.js ${timestamp}] ${level.toUpperCase()}:`;
      
      if (data) {
        console[level](prefix, message, data);
      } else {
        console[level](prefix, message);
      }
    }
  }

  // Utility functions
  function getClient() {
    debugLog('debug', 'Getting client information');
    return new Promise((resolve, reject) => {
      if (typeof ajaxAPI !== 'undefined' && ajaxAPI.shop && ajaxAPI.shop.client) {
        ajaxAPI.shop.client.get().done((client) => {
          debugLog('info', 'Client retrieved successfully', client);
          resolve(client);
        }).fail((error) => {
          debugLog('error', 'Failed to get client', error);
          reject(error);
        });
      } else {
        debugLog('error', 'Client API not available');
        reject(new Error('Client API not available'));
      }
    });
  }

  function getShopConfig() {
    if (typeof Shop !== 'undefined' && Shop.config) {
      return Shop.config.get();
    }
    return null;
  }

  function getCurrentProductData() {
    const productElement = document.querySelector('[data-product-id]');
    if (!productElement) return null;

    return {
      productId: productElement.dataset.productId,
      variantId: productElement.dataset.variantId || null,
      listId: productElement.dataset.listId || null
    };
  }

  // API functions
  function buildApiUrl(endpoint, params) {
    let url = CONFIG.endpoints[endpoint];
    Object.keys(params).forEach(key => {
      url = url.replace(`{${key}}`, params[key]);
    });
    return CONFIG.apiBaseUrl + url;
  }

  function makeApiRequest(url, method = 'GET', data = null, queryParams = null) {
    return new Promise((resolve, reject) => {
      const options = {
        url: url,
        method: method,
        dataType: 'json',
        headers: {
          'Content-Type': 'application/json'
        }
      };

      if (data && method !== 'GET') {
        options.data = JSON.stringify(data);
      }

      if (queryParams && method === 'GET') {
        options.data = queryParams;
      }

      $.ajax(options).done(resolve).fail(reject);
    });
  }

  function getS3FallbackUrl(accountId, clientId, listId) {
    return CONFIG.s3Fallback.baseUrl + 
           CONFIG.s3Fallback.path
             .replace('{account_id}', accountId)
             .replace('{client_id}', clientId)
             .replace('{list_id}', listId);
  }

  // Main API functions
  async function addListItem(listId, productId, variantId = null, metadata = {}) {
    debugLog('info', 'Adding list item', { listId, productId, variantId, metadata });
    try {
      const client = await getClient();
      const shop = getShopConfig();
      
      if (!shop || !shop.account_id) {
        debugLog('error', 'Shop configuration not available');
        throw new Error('Shop configuration not available');
      }

      const url = buildApiUrl('addItem', {
        account_id: shop.account_id,
        list_id: listId
      });

      const data = {
        external_client_id: client.id,
        external_product_id: productId,
        external_variant_id: variantId,
        metadata: metadata
      };

      debugLog('debug', 'Making API request', { url, data });
      const response = await makeApiRequest(url, 'POST', data);
      debugLog('info', 'List item added successfully', response);
      return response;
    } catch (error) {
      debugLog('error', 'Error adding list item', error);
      console.error('Error adding list item:', error);
      throw error;
    }
  }

  async function removeListItem(listId, itemId) {
    try {
      const shop = getShopConfig();
      
      if (!shop || !shop.account_id) {
        throw new Error('Shop configuration not available');
      }

      const url = buildApiUrl('removeItem', {
        account_id: shop.account_id,
        list_id: listId,
        item_id: itemId
      });

      const response = await makeApiRequest(url, 'DELETE');
      return response;
    } catch (error) {
      console.error('Error removing list item:', error);
      throw error;
    }
  }

  async function getListItems(listId, useS3Fallback = true) {
    try {
      const client = await getClient();
      const shop = getShopConfig();
      
      if (!shop || !shop.account_id) {
        throw new Error('Shop configuration not available');
      }

      // Try API first
      try {
        const url = buildApiUrl('getItems', {
          account_id: shop.account_id,
          list_id: listId
        });

        const response = await makeApiRequest(url, 'GET', null, {
          external_client_id: client.id
        });
        return response;
      } catch (apiError) {
        console.warn('API request failed, trying S3 fallback:', apiError);
        
        if (useS3Fallback && CONFIG.s3Fallback.enabled) {
          // Try S3 fallback
          const s3Url = getS3FallbackUrl(shop.account_id, client.id, listId);
          const s3Response = await makeApiRequest(s3Url, 'GET');
          return s3Response;
        } else {
          throw apiError;
        }
      }
    } catch (error) {
      console.error('Error getting list items:', error);
      throw error;
    }
  }

  // UI Helper functions
  function updateListCounter(count) {
    const counter = document.querySelector('[data-ui-list-counter]');
    if (counter) {
      counter.textContent = count;
      counter.classList.remove('list-empty');
    }
  }

  function updateListButton(productId, isAdded = false) {
    const button = document.querySelector(`[data-list-product="${productId}"]`);
    if (button) {
      if (isAdded) {
        button.classList.add('list-added');
      } else {
        button.classList.remove('list-added');
      }
    }
  }

  function showListItems(items) {
    const container = document.querySelector('[data-list-items-container]');
    if (!container) return;

    if (!items || items.length === 0) {
      container.innerHTML = '<div class="empty-list-message">Список пуст</div>';
      return;
    }

    // Clear existing items
    container.innerHTML = '';

    // Add items (assuming items have product data)
    items.forEach(item => {
      const itemElement = createListItemElement(item);
      container.appendChild(itemElement);
    });

    // Initialize any UI components if needed
    if (typeof LazyLoad !== 'undefined') {
      new LazyLoad({
        container: container,
        elements_selector: '.lazyload'
      });
    }
  }

  function createListItemElement(item) {
    // This is a basic template - customize based on your needs
    const element = document.createElement('div');
    element.className = 'list-item';
    element.dataset.itemId = item.id;
    element.dataset.productId = item.item_id;

    element.innerHTML = `
      <div class="list-item-content">
        <div class="list-item-image">
          <img src="${item.metadata?.image_url || '/placeholder.jpg'}" alt="${item.metadata?.title || 'Product'}" class="lazyload">
        </div>
        <div class="list-item-info">
          <h3 class="list-item-title">${item.metadata?.title || 'Product'}</h3>
          <p class="list-item-price">${item.metadata?.price || ''}</p>
        </div>
        <div class="list-item-actions">
          <button class="remove-list-item-btn" data-item-id="${item.id}">
            <span class="icon-remove"></span>
          </button>
        </div>
      </div>
    `;

    return element;
  }

  // Event handlers
  function handleListToggle(event) {
    const element = event.target.closest('[data-list-product]');
    if (!element) return;

    const productId = element.dataset.listProduct;
    const listId = element.dataset.listId;
    const productData = getCurrentProductData();
    
    if (!productData || !listId) {
      console.error('Missing product data or list ID');
      return;
    }

    const isAdded = element.classList.contains('list-added');
    
    if (isAdded) {
      // Remove from list
      removeListItem(listId, productId)
        .then(() => {
          updateListButton(productId, false);
          updateListCounter(getListItemsCount() - 1);
        })
        .catch(error => {
          console.error('Failed to remove item:', error);
          alert('Ошибка при удалении из списка');
        });
    } else {
      // Add to list
      addListItem(listId, productData.productId, productData.variantId)
        .then(() => {
          updateListButton(productId, true);
          updateListCounter(getListItemsCount() + 1);
        })
        .catch(error => {
          console.error('Failed to add item:', error);
          alert('Ошибка при добавлении в список');
        });
    }
  }

  function handleRemoveItem(event) {
    const element = event.target.closest('[data-item-id]');
    if (!element) return;

    const itemId = element.dataset.itemId;
    const listId = element.dataset.listId;
    
    if (!listId) {
      console.error('Missing list ID');
      return;
    }

    removeListItem(listId, itemId)
      .then(() => {
        element.remove();
        updateListCounter(getListItemsCount() - 1);
      })
      .catch(error => {
        console.error('Failed to remove item:', error);
        alert('Ошибка при удалении элемента');
      });
  }

  function getListItemsCount() {
    const counter = document.querySelector('[data-ui-list-counter]');
    return counter ? parseInt(counter.textContent) || 0 : 0;
  }

  // Initialize list items on page load
  async function initializeListItems() {
    const listId = document.querySelector('[data-list-id]')?.dataset.listId;
    if (!listId) return;

    try {
      const items = await getListItems(listId);
      showListItems(items.items || items);
      updateListCounter(items.items?.length || items.length || 0);
    } catch (error) {
      console.error('Failed to initialize list items:', error);
    }
  }

  // Initialize favorite buttons on page load
  async function initializeListButtons() {
    try {
      const items = await getListItems(document.querySelector('[data-list-id]')?.dataset.listId);
      const productIds = items.items?.map(item => item.item_id) || items.map(item => item.item_id) || [];
      
      productIds.forEach(productId => {
        updateListButton(productId, true);
      });
    } catch (error) {
      console.error('Failed to initialize list buttons:', error);
    }
  }

  // Public API
  window.ListAPI = {
    addItem: addListItem,
    removeItem: removeListItem,
    getItems: getListItems,
    updateCounter: updateListCounter,
    updateButton: updateListButton,
    showItems: showListItems,
    // Debug utilities
    enableDebug: () => { CONFIG.debug.enabled = true; },
    disableDebug: () => { CONFIG.debug.enabled = false; },
    setDebugLevel: (level) => { CONFIG.debug.logLevel = level; }
  };

  // Initialize when DOM is ready
  $(document).ready(function() {
    // Set up event listeners
    $(document).on('click', '[data-list-product]', handleListToggle);
    $(document).on('click', '.remove-list-item-btn', handleRemoveItem);

    // Initialize based on page type
    if (document.querySelector('[data-list-items-container]')) {
      // This is a list items page
      initializeListItems();
    } else {
      // This is a product page with list buttons
      initializeListButtons();
    }
  });

  // Event bus integration (if available)
  if (typeof EventBus !== 'undefined') {
    EventBus.subscribe('list-item-added', (data) => {
      updateListButton(data.productId, true);
      updateListCounter(getListItemsCount() + 1);
    });

    EventBus.subscribe('list-item-removed', (data) => {
      updateListButton(data.productId, false);
      updateListCounter(getListItemsCount() - 1);
    });
  }

  // ============================================================================
  // USAGE EXAMPLES
  // ============================================================================
  
  /*
  Usage Examples
  ==============
  
  Product Page (like favorites snippet)
  ------------------------------------
  
  Add this HTML to your product page:
  
  <div data-product-id="123" data-variant-id="456">
    <h3>Sample Product</h3>
    
    <!-- Add to Favorites Button -->
    <button class="list-button" 
            data-list-product="123" 
            data-list-id="1">
      Add to Favorites
    </button>
    
    <!-- Add to Wishlist Button -->
    <button class="list-button" 
            data-list-product="123" 
            data-list-id="2">
      Add to Wishlist
    </button>
    
    <!-- Counter Display -->
    <span class="list-counter" data-ui-list-counter>0</span>
  </div>
  
  The script will automatically:
  - Handle button clicks
  - Update button states (added/not added)
  - Update counter display
  - Make API calls to add/remove items
  
  List Items Page (like favorites products page)
  ---------------------------------------------
  
  Add this HTML to show all items in a list:
  
  <div data-list-id="1">
    <h3>My Favorites</h3>
    <div data-list-items-container>
      <!-- Items will be loaded here automatically -->
    </div>
  </div>
  
  The script will automatically:
  - Load items from API
  - Display them in the container
  - Handle remove buttons
  - Update counters
  
  // 1. BASIC HTML SETUP
  
  <!-- Product Page with List Buttons -->
  <div data-product-id="123" data-variant-id="456">
    <h3>Sample Product</h3>
    
    <!-- Add to Favorites Button -->
    <button class="list-button" 
            data-list-product="123" 
            data-list-id="1">
      Add to Favorites
    </button>
    
    <!-- Add to Wishlist Button -->
    <button class="list-button" 
            data-list-product="123" 
            data-list-id="2">
      Add to Wishlist
    </button>
    
    <!-- Counter Display -->
    <span class="list-counter" data-ui-list-counter>0</span>
  </div>
  
  <!-- List Items Page -->
  <div data-list-id="1">
    <h3>My Favorites</h3>
    <div data-list-items-container>
      <!-- Items will be loaded here automatically -->
    </div>
  </div>
  
  // 2. JAVASCRIPT API USAGE
  
  // Enable debug mode
  ListAPI.enableDebug();
  ListAPI.setDebugLevel('debug'); // 'debug', 'info', 'warn', 'error'
  
  // Add item to list
  ListAPI.addItem('1', '123', '456', { title: 'Sample Product' })
    .then(response => {
      console.log('Item added:', response);
      // response: { item: {...}, total_count: 5 }
    })
    .catch(error => {
      console.error('Failed to add item:', error);
    });
  
  // Get list items
  ListAPI.getItems('1')
    .then(response => {
      console.log('List items:', response);
      // response: { items: [...], total_count: 5 }
    })
    .catch(error => {
      console.error('Failed to get items:', error);
    });
  
  // Remove item from list
  ListAPI.removeItem('1', 'item_123')
    .then(response => {
      console.log('Item removed:', response);
      // response: { total_count: 4 }
    })
    .catch(error => {
      console.error('Failed to remove item:', error);
    });
  
  // Update UI manually
  ListAPI.updateCounter(5);
  ListAPI.updateButton('123', true); // true = added, false = not added
  
  // 3. CUSTOM EVENT HANDLING
  
  // Listen for list events
  document.addEventListener('click', function(event) {
    if (event.target.matches('[data-list-product]')) {
      const productId = event.target.dataset.listProduct;
      const listId = event.target.dataset.listId;
      
      console.log(`Toggling product ${productId} in list ${listId}`);
    }
  });
  
  // 4. INTEGRATION WITH EXISTING SYSTEMS
  
  // Mock Shop configuration (replace with your actual implementation)
  window.Shop = {
    config: {
      get: function() {
        return {
          account_id: '3' // Your account ID
        };
      }
    }
  };
  
  // Mock ajaxAPI (replace with your actual implementation)
  window.ajaxAPI = {
    shop: {
      client: {
        get: function() {
          return $.Deferred().resolve({
            id: 'client_123' // Your client ID
          });
        }
      }
    }
  };
  
  // 5. CUSTOM STYLING
  
  .list-button {
    padding: 10px 20px;
    border: 2px solid #ccc;
    background: white;
    cursor: pointer;
    border-radius: 5px;
    transition: all 0.3s;
  }
  
  .list-button.list-added {
    background: #4CAF50;
    color: white;
    border-color: #4CAF50;
  }
  
  .list-counter {
    display: inline-block;
    padding: 5px 10px;
    background: #f0f0f0;
    border-radius: 15px;
    margin-left: 10px;
  }
  
  .list-counter.list-empty {
    opacity: 0.5;
  }
  
  .list-item {
    border: 1px solid #ddd;
    padding: 15px;
    margin: 10px 0;
    border-radius: 5px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  
  // 6. DEBUGGING
  
  // Enable debug mode in console
  ListAPI.enableDebug();
  ListAPI.setDebugLevel('debug');
  
  // Check current configuration
  console.log('Current config:', CONFIG);
  
  // Test API endpoints manually
  fetch('/api/accounts/3/lists/1/list_items?external_client_id=client_123')
    .then(response => response.json())
    .then(data => console.log('API test:', data));
  
  // 7. ERROR HANDLING
  
  // Wrap API calls in try-catch
  try {
    const result = await ListAPI.addItem('1', '123', '456');
    console.log('Success:', result);
  } catch (error) {
    console.error('Error details:', {
      message: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString()
    });
  }
  
  // 8. PERFORMANCE OPTIMIZATION
  
  // Debounce rapid clicks
  let clickTimeout;
  document.addEventListener('click', function(event) {
    if (event.target.matches('[data-list-product]')) {
      clearTimeout(clickTimeout);
      clickTimeout = setTimeout(() => {
        // Handle click after 300ms delay
      }, 300);
    }
  });
  
  // Cache list items to avoid repeated API calls
  const listCache = new Map();
  
  async function getCachedListItems(listId) {
    if (listCache.has(listId)) {
      return listCache.get(listId);
    }
    
    const items = await ListAPI.getItems(listId);
    listCache.set(listId, items);
    return items;
  }
  */

})();
