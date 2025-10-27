/**
 * Modern ES6 Class-based Lists Manager
 * Refactored from list.js with pagination support
 * Version: v_1.2.7
 */

// Configuration constants
const CONFIG = {
  s3Base: 'https://s3.twcstorage.ru/ae4cd7ee-b62e0601-19d6-483e-bbf1-416b386e5c23',
  apiBase: 'https://app.teletri.ru/api',
  itemsPerPage: 20,
  maxVisiblePages: 100,
  version: 'v_1.2.7'
};

// Debug logging utility
class Logger {
  constructor(debug = false) {
    this.debug = debug;
  }

  log(...args) {
    if (this.debug) {
      console.log('[ListsManager]', ...args);
    }
  }

  error(...args) {
    if (this.debug) {
      console.error('[ListsManager]', ...args);
    }
  }
}

// Data Manager (без кэширования)
class DataManager {
  constructor(logger) {
    this.logger = logger;
    this.s3Base = CONFIG.s3Base;
  }

  /**
   * Build S3 URL for account lists
   */
  buildS3AccountListsUrl(accountId) {
    return `${this.s3Base}/lists/list_${accountId}.json`;
  }

  /**
   * Build S3 URL for client list items
   */
  buildS3ClientListItemsUrl(accountId, clientId) {
    return `${this.s3Base}/lists/list_${accountId}_client_${clientId}_list_items.json`;
  }

  /**
   * Fetch lists data from S3 (без кэширования)
   */
  async fetchListsData(accountId) {
    const url = this.buildS3AccountListsUrl(accountId) + `?t=${Date.now()}`;
    this.logger.log('Fetching lists data from:', url);

    try {
      const response = await fetch(url, { credentials: 'omit', cache: 'no-cache' });
      if (!response.ok) throw new Error('Failed to load lists data');
      
      const data = await response.json();
      this.logger.log('Lists data fetched successfully:', data);
      return data;
    } catch (error) {
      this.logger.error('Failed to fetch lists data:', error);
      throw error;
    }
  }

  /**
   * Fetch client-specific list items from S3 (без кэширования)
   */
  async fetchClientListsData(accountId, clientId) {
    const url = this.buildS3ClientListItemsUrl(accountId, clientId) + `?t=${Date.now()}`;
    this.logger.log('Fetching client lists data from:', url);

    try {
      const response = await fetch(url, { credentials: 'omit', cache: 'no-cache' });
      if (!response.ok) throw new Error('Failed to load client lists data');
      
      const data = await response.json();
      this.logger.log('Client lists data fetched successfully:', data);
      return data;
    } catch (error) {
      this.logger.error('Failed to fetch client lists data:', error);
      throw error;
    }
  }

}

// UI Renderer
class UIRenderer {
  constructor(logger) {
    this.logger = logger;
    this.iconStyles = {
      icon_one: 'heart',
      icon_two: 'bookmark',
      icon_three: 'thumb'
    };
    this.paginationRenderer = new PaginationRenderer(logger);
  }

  /**
   * Render icon based on style and state
   */
  renderIcon(iconStyle, color, active) {
    const stroke = color || '#999999';
    const fill = active ? (color || '#999999') : 'none';
    
    switch (iconStyle) {
      case 'icon_one':
        // Heart
        return `<svg xmlns="http://www.w3.org/2000/svg" style="pointer-events:none;display:block;" viewBox="0 0 24 24" fill="${fill}" stroke="${stroke}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 1 0-7.78 7.78L12 21.23l8.84-8.84a5.5 5.5 0 0 0 0-7.78z"/></svg>`;
      case 'icon_two':
        // Wishlist (bookmark)
        return `<svg xmlns="http://www.w3.org/2000/svg" style="pointer-events:none;display:block;" viewBox="0 0 24 24" fill="${fill}" stroke="${stroke}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/></svg>`;
      case 'icon_three':
        // Like (thumb/finger up)
        return `<svg xmlns="http://www.w3.org/2000/svg" style="pointer-events:none;display:block;" viewBox="0 0 24 24" fill="${fill}" stroke="${stroke}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 21h4V9H2v12z"/><path d="M22 11c0-1.1-.9-2-2-2h-6l1-5-5 6v11h9c1.1 0 2-.9 2-2l1-8z"/></svg>`;
      default:
        return '';
    }
  }

  /**
   * Create lists container for favorites triggers
   */
  createListsContainer(lists, options = {}) {
    const { attach = true, containerSelector = '[data-lists-root]' } = options;
    
    this.logger.log(`Creating lists container for ${lists.length} lists`);
    
    const wrapper = document.createElement('div');
    wrapper.className = 'twc-lists-container';
    
    lists.forEach(list => {
      const item = document.createElement('span');
      item.className = 'twc-list-item';
      item.setAttribute('data-list-id', String(list.id));
      item.setAttribute('data-list-name', list.name || '');
      item.setAttribute('data-icon-style', list.icon_style || 'icon_one');
      item.setAttribute('data-icon-color', list.icon_color || '#999999');
      item.setAttribute('data-added', 'false');
      
      const iconHtml = this.renderIcon(list.icon_style || 'icon_one', list.icon_color || '#999999', false);
      item.innerHTML = iconHtml;
      
      wrapper.appendChild(item);
    });
    
    if (attach) {
      const host = document.querySelector(containerSelector);
      if (host) {
        host.innerHTML = '';
        host.appendChild(wrapper);
        this.logger.log('Attached container to host');
      } else {
        this.logger.log(`Host not found: ${containerSelector}`);
      }
    }
    
    return wrapper;
  }

  /**
   * Render product card from S3 data
   */
  renderProductCard(item, listData) {
    const card = document.createElement('div');
    const url = item.item_link || '#';
    card.className = 'twc-list-card';
    
    // Image wrapper
    const imgWrap = document.createElement('div');
    imgWrap.className = 'twc-list-card-img-wrap';
    
    const imgLink = document.createElement('a');
    imgLink.setAttribute('href', url);
    
    const img = document.createElement('img');
    img.setAttribute('src', item.item_image || '');
    img.setAttribute('alt', item.item_title || '');
    
    imgLink.appendChild(img);
    imgWrap.appendChild(imgLink);
    
    // Title wrapper
    const titleWrap = document.createElement('div');
    titleWrap.className = 'twc-list-card-title-wrap';
    
    const title = document.createElement('a');
    title.setAttribute('href', url);
    title.textContent = item.item_title || ('#' + item.external_item_id);
    title.className = 'twc-list-card-title';
    
    titleWrap.appendChild(title);
    
    // Controls wrapper
    const controlsWrap = document.createElement('div');
    controlsWrap.className = 'twc-list-card-controls-wrap';
    
    const controlsHost = document.createElement('div');
    controlsHost.setAttribute('data-ui-favorites-trigger-twc', item.external_item_id || '');
    
    // Show icon that corresponds to the current list
    if (listData) {
      const listItem = document.createElement('span');
      listItem.className = 'twc-list-item';
      listItem.setAttribute('data-list-id', String(listData.id));
      listItem.setAttribute('data-list-name', listData.name || '');
      listItem.setAttribute('data-icon-style', listData.icon_style || 'icon_one');
      listItem.setAttribute('data-icon-color', listData.icon_color || '#999999');
      listItem.setAttribute('data-added', 'true'); // Item is in this list
      
      const iconHtml = this.renderIcon(listData.icon_style || 'icon_one', listData.icon_color || '#999999', true);
      listItem.innerHTML = iconHtml;
      
      controlsHost.appendChild(listItem);
    }
    
    controlsWrap.appendChild(controlsHost);
    
    // Price wrapper
    const priceWrap = document.createElement('div');
    priceWrap.className = 'twc-list-card-price-wrap';
    
    const price = document.createElement('div');
    price.textContent = item.item_price || '0';
    price.className = 'twc-list-card-price';
    
    priceWrap.appendChild(price);
    
    // Buy button wrapper
    const buyButtonWrap = document.createElement('div');
    buyButtonWrap.className = 'twc-list-card-buy-button-wrap';
    
    const buyButton = document.createElement('a');
    buyButton.setAttribute('href', url);
    buyButton.className = 'twc-list-card-buy-button';
    // buyButton.textContent = 'Купить';
    buyButtonWrap.appendChild(buyButton);
    
    card.appendChild(imgWrap);
    card.appendChild(titleWrap);
    card.appendChild(controlsWrap);
    card.appendChild(priceWrap);
    card.appendChild(buyButtonWrap);
    
    return card;
  }

  /**
   * Render section for a list
   */
  renderSection(listData, page = 1) {
    const section = document.createElement('section');
    section.setAttribute('data-list-id', String(listData.id));
    
    // Header
    const h2 = document.createElement('h2');
    h2.textContent = listData.name || ('List #' + listData.id);
    
    // Grid
    const grid = document.createElement('div');
    grid.className = 'twc-list-cards';
    grid.setAttribute('data-list-id', String(listData.id));
    
    section.appendChild(h2);
    section.appendChild(grid);
    
    // Render items for current page
    this.renderItemsForPage(grid, listData, page);
    
    // Add pagination if needed
    if (listData.items && listData.items.length > CONFIG.itemsPerPage) {
      this.addPaginationToSection(section, listData);
    }
    
    return section;
  }

  /**
   * Render items for a specific page
   */
  renderItemsForPage(grid, listData, page) {
    if (!listData.items || !listData.items.length) {
      const emptyMessage = document.createElement('div');
      emptyMessage.className = 'twc-error-state';
      emptyMessage.textContent = 'Нет товаров в этом списке';
      grid.appendChild(emptyMessage);
      return;
    }

    const startIndex = (page - 1) * CONFIG.itemsPerPage;
    const endIndex = Math.min(startIndex + CONFIG.itemsPerPage, listData.items.length);
    const pageItems = listData.items.slice(startIndex, endIndex);
    
    this.logger.log(`Rendering ${pageItems.length} items for page ${page}`);
    
    // Clear existing items
    grid.innerHTML = '';
    
    // Render items
    pageItems.forEach(item => {
      const card = this.renderProductCard(item, listData);
      grid.appendChild(card);
    });
  }

  /**
   * Add pagination to section
   */
  addPaginationToSection(section, listData) {
    const totalItems = listData.items.length;
    const totalPages = Math.ceil(totalItems / CONFIG.itemsPerPage);
    
    if (totalPages <= 1) return;
    
    // Create pagination container
    const paginationContainer = document.createElement('div');
    paginationContainer.className = 'twc-pagination-container';
    paginationContainer.setAttribute('data-list-id', String(listData.id));
    paginationContainer.setAttribute('data-all-items', JSON.stringify(listData.items));
    paginationContainer.setAttribute('data-items-per-page', CONFIG.itemsPerPage);
    
    // Create pagination controls
    const paginationControls = this.createPaginationControls(listData.id, totalPages);
    paginationControls.setAttribute('data-current-page', '1');
    paginationControls.setAttribute('data-total-pages', totalPages);
    paginationContainer.appendChild(paginationControls);
    
    // Add pagination after the grid
    section.appendChild(paginationContainer);
    
    this.logger.log(`Pagination container added to section for list ${listData.id}`);
    this.logger.log(`Section now has ${section.children.length} children`);
    this.logger.log(`Pagination container exists: ${!!section.querySelector('.twc-pagination-container')}`);
    
    this.logger.log(`Added pagination for list ${listData.id}: ${totalPages} pages`);
  }

  /**
   * Create pagination controls
   */
  createPaginationControls(listId, totalPages) {
    const controls = document.createElement('div');
    controls.className = 'twc-pagination-controls';
    
    // Previous button
    const prevBtn = document.createElement('button');
    prevBtn.textContent = '‹';
    prevBtn.className = 'twc-pagination-btn twc-pagination-prev';
    prevBtn.setAttribute('data-list-id', listId);
    prevBtn.setAttribute('data-action', 'prev');
    controls.appendChild(prevBtn);
    
    // Page numbers container
    const pageNumbersContainer = document.createElement('div');
    pageNumbersContainer.className = 'twc-pagination-numbers';
    pageNumbersContainer.setAttribute('data-list-id', listId);
    controls.appendChild(pageNumbersContainer);
    
    // Next button
    const nextBtn = document.createElement('button');
    nextBtn.textContent = '›';
    nextBtn.className = 'twc-pagination-btn twc-pagination-next';
    nextBtn.setAttribute('data-list-id', listId);
    nextBtn.setAttribute('data-action', 'next');
    controls.appendChild(nextBtn);
    
    return controls;
  }
}

// Pagination Renderer
class PaginationRenderer {
  constructor(logger) {
    this.logger = logger;
    this.itemsPerPage = CONFIG.itemsPerPage;
    this.maxVisiblePages = CONFIG.maxVisiblePages;
  }

  /**
   * Update pagination state (active page, button states)
   */
  updatePaginationState(listId, currentPage, totalPages) {
    this.logger.log(`Updating pagination state for list ${listId}: page ${currentPage}/${totalPages}`);
    
    // Find the section that has pagination container (same logic as handlePaginationClick)
    const sections = document.querySelectorAll(`[data-list-id="${listId}"]`);
    
    let section = null;
    for (let i = 0; i < sections.length; i++) {
      const paginationContainer = sections[i].querySelector('.twc-pagination-container');
      if (paginationContainer) {
        section = sections[i];
        break;
      }
    }
    
    if (!section) {
      this.logger.error(`No section with pagination found for list ${listId}`);
      return;
    }
    
    const paginationContainer = section.querySelector('.twc-pagination-container');
    if (!paginationContainer) {
      this.logger.error(`Pagination container not found for list ${listId}`);
      return;
    }
    
    const controls = paginationContainer.querySelector('.twc-pagination-controls');
    const pageNumbersContainer = paginationContainer.querySelector('.twc-pagination-numbers');
    
    if (!controls || !pageNumbersContainer) {
      this.logger.error(`Pagination controls not found for list ${listId}`);
      return;
    }
    
    // Update current page attribute
    controls.setAttribute('data-current-page', currentPage);
    
    // Update prev/next button states
    const prevBtn = controls.querySelector('.twc-pagination-prev');
    const nextBtn = controls.querySelector('.twc-pagination-next');
    
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
    const startPage = Math.max(1, currentPage - 2);
    const endPage = Math.min(totalPages, currentPage + 2);
    
    for (let i = startPage; i <= endPage; i++) {
      const pageBtn = document.createElement('button');
      pageBtn.textContent = i;
      pageBtn.className = 'twc-pagination-btn twc-pagination-page';
      if (i === currentPage) {
        pageBtn.classList.add('active');
      }
      pageBtn.setAttribute('data-list-id', listId);
      pageBtn.setAttribute('data-page', i);
      pageNumbersContainer.appendChild(pageBtn);
    }
    
    this.logger.log(`Pagination state updated for list ${listId}`);
  }

  /**
   * Go to specific page
   */
  goToPage(listId, page, totalPages, uiRenderer) {
    this.logger.log(`Going to page ${page} for list ${listId}`);
    
    // Find the section that has pagination container (same logic as handlePaginationClick)
    const sections = document.querySelectorAll(`[data-list-id="${listId}"]`);
    this.logger.log(`Found ${sections.length} sections with listId ${listId}`);
    
    let section = null;
    for (let i = 0; i < sections.length; i++) {
      const paginationContainer = sections[i].querySelector('.twc-pagination-container');
      if (paginationContainer) {
        section = sections[i];
        this.logger.log(`Found section with pagination at index ${i}`);
        break;
      }
    }
    
    if (!section) {
      this.logger.error(`No section with pagination found for list ${listId}`);
      return;
    }
    
    const grid = section.querySelector('.twc-list-cards');
    const paginationContainer = section.querySelector('.twc-pagination-container');
    
    if (!grid || !paginationContainer) {
      this.logger.error(`Grid or pagination container not found for list ${listId}`);
      return;
    }
    
    // Get all items for this list
    const allItems = paginationContainer.getAttribute('data-all-items');
    const itemsPerPage = parseInt(paginationContainer.getAttribute('data-items-per-page')) || CONFIG.itemsPerPage;
    
    if (!allItems) {
      this.logger.error(`No items data found for list ${listId}`);
      return;
    }
    
    try {
      const items = JSON.parse(allItems);
      const startIndex = (page - 1) * itemsPerPage;
      
      this.logger.log(`Rendering page ${page}: ${items.length} items, start index ${startIndex}`);
      
      this.logger.log(`window.currentListsData structure:`, window.currentListsData);
      
      // Get list data for rendering
      const listData = window.currentListsData?.lists?.find(list => String(list.id) === String(listId));
      
      this.logger.log(`List data for rendering:`, { listId, listData: !!listData, itemsCount: listData?.items?.length });
      
      if (!listData) {
        this.logger.error(`List data not found for list ${listId}`);
        return;
      }
      
      uiRenderer.renderItemsForPage(grid, listData, page);
      this.updatePaginationState(listId, page, totalPages);
      
      this.logger.log(`Page ${page} rendered successfully`);
    } catch (error) {
      this.logger.error(`Error rendering page ${page}:`, error);
    }
  }

  /**
   * Handle item removal from pagination
   */
  handleItemRemoval(listId, removedItemId, uiRenderer) {
    this.logger.log(`Handling item removal: ${removedItemId} from list ${listId}`);
    
    const section = document.querySelector(`[data-list-id="${listId}"]`);
    if (!section) {
      this.logger.error(`Section not found for list ${listId}`);
      return;
    }
    
    const paginationContainer = section.querySelector('.twc-pagination-container');
    if (!paginationContainer) {
      this.logger.error(`Pagination container not found for list ${listId}`);
      return;
    }
    
    // Get current items from stored data
    const storedItems = paginationContainer.getAttribute('data-all-items');
    if (!storedItems) {
      this.logger.error(`No stored items found for list ${listId}`);
      return;
    }
    
    try {
      const items = JSON.parse(storedItems);
      const originalCount = items.length;
      
      // Remove the item from the stored data
      const filteredItems = items.filter(item => item.external_item_id !== removedItemId);
      
      const newCount = filteredItems.length;
      this.logger.log(`Item removed: ${originalCount} -> ${newCount} items`);
      
      // Update stored data
      paginationContainer.setAttribute('data-all-items', JSON.stringify(filteredItems));
      
      // Also update grid data
      const grid = section.querySelector('.twc-list-cards');
      if (grid) {
        grid.setAttribute('data-all-items', JSON.stringify(filteredItems));
      }
      
      // Recalculate pagination
      const itemsPerPage = parseInt(paginationContainer.getAttribute('data-items-per-page')) || CONFIG.itemsPerPage;
      const totalPages = Math.ceil(filteredItems.length / itemsPerPage);
      
      // Update pagination controls
      const controls = paginationContainer.querySelector('.twc-pagination-controls');
      if (controls) {
        controls.setAttribute('data-total-pages', totalPages);
      }
      
      // Re-render current page
      const currentPage = parseInt(controls.getAttribute('data-current-page')) || 1;
      let pageToRender = currentPage;
      
      if (currentPage > totalPages && totalPages > 0) {
        pageToRender = totalPages;
      }
      
      this.logger.log(`Re-rendering page ${pageToRender} after removal`);
      
      // Re-render the current page
      if (grid && filteredItems.length > 0) {
        const listData = window.currentListsData?.lists?.find(list => String(list.id) === String(listId));
        if (listData) {
          // Update list data with filtered items
          listData.items = filteredItems;
          uiRenderer.renderItemsForPage(grid, listData, pageToRender);
          this.updatePaginationState(listId, pageToRender, totalPages);
        }
      } else if (filteredItems.length === 0) {
        // No items left, remove pagination and show empty message
        paginationContainer.remove();
        grid.innerHTML = '<div style="text-align:center;padding:40px;color:#666;">Нет товаров в этом списке</div>';
        this.logger.log(`No items left in list ${listId}, pagination removed`);
      }
      
    } catch (error) {
      this.logger.error(`Error handling item removal:`, error);
    }
  }
}

// API Client
class APIClient {
  constructor(logger) {
    this.logger = logger;
    this.apiBase = CONFIG.apiBase;
  }

  /**
   * Build API base URL
   */
  buildApiBase(accountId, listId) {
    return `${this.apiBase}/accounts/${encodeURIComponent(accountId)}/lists/${encodeURIComponent(listId)}/list_items`;
  }

  /**
   * Get list items from API
   */
  async getListItems(accountId, listId, externalClientId) {
    const url = this.buildApiBase(accountId, listId) + `?external_client_id=${encodeURIComponent(externalClientId)}`;
    this.logger.log('API GET:', url);
    
    try {
      const response = await fetch(url, { method: 'GET', credentials: 'omit' });
      const data = await response.json();
      this.logger.log('API GET response:', data);
      return data;
    } catch (error) {
      this.logger.error('API GET failed:', error);
      throw error;
    }
  }

  /**
   * Add item to list
   */
  async addItem(accountId, listId, externalClientId, externalProductId, externalVariantId = null) {
    const url = this.buildApiBase(accountId, listId);
    const params = new URLSearchParams();
    params.append('external_client_id', externalClientId);
    params.append('external_product_id', externalProductId);
    if (externalVariantId) params.append('external_variant_id', externalVariantId);
    
    this.logger.log('API POST:', url, params.toString());
    
    try {
      const response = await fetch(url, { 
        method: 'POST', 
        body: params, 
        credentials: 'omit' 
      });
      const data = await response.json();
      this.logger.log('API POST response:', data);
      return data;
    } catch (error) {
      this.logger.error('API POST failed:', error);
      throw error;
    }
  }

  /**
   * Remove item from list
   */
  async removeItem(accountId, listId, listItemId) {
    const url = this.buildApiBase(accountId, listId) + '/' + encodeURIComponent(listItemId);
    this.logger.log('API DELETE:', url);
    
    try {
      const response = await fetch(url, { method: 'DELETE', credentials: 'omit' });
      const data = await response.json();
      this.logger.log('API DELETE response:', data);
      return data;
    } catch (error) {
      this.logger.error('API DELETE failed:', error);
      throw error;
    }
  }
}

// Event Handler
class EventHandler {
  constructor(manager, logger) {
    this.manager = manager;
    this.logger = logger;
    this.paginationRenderer = new PaginationRenderer(logger);
  }

  /**
   * Bind all event handlers
   */
  bindEvents() {
    this.logger.log('Binding event handlers');
    
    // Bind click handlers for list items
    document.addEventListener('click', (event) => {
      this.handleItemClick(event);
    });
    
    // Bind pagination click handlers
    document.addEventListener('click', (event) => {
      this.handlePaginationClick(event);
    });
    
    this.logger.log('Event handlers bound');
  }

  /**
   * Handle click on list item (add/remove from list)
   */
  async handleItemClick(event) {
    if (!event.target || !event.target.classList || !event.target.classList.contains('twc-list-item')) {
      return;
    }
    
    // Prevent anchor navigation when clicking controls inside cards
    event.preventDefault();
    
    const itemNode = event.target;
    const triggerHost = itemNode.closest('[data-ui-favorites-trigger-twc]');
    if (!triggerHost) return;
    
    const productId = triggerHost.getAttribute('data-ui-favorites-trigger-twc');
    const listId = itemNode.getAttribute('data-list-id');
    const iconStyle = itemNode.getAttribute('data-icon-style');
    const iconColor = itemNode.getAttribute('data-icon-color');
    const added = itemNode.getAttribute('data-added') === 'true';
    
    this.logger.log(`Item click: ${added ? 'remove' : 'add'} product ${productId} from list ${listId}`);
    
    try {
      const client = await this.manager.getClient();
      const clientId = client && client.id;
      
      if (!clientId) {
        this.logger.error('No client available');
        return;
      }
      
      if (added) {
        // Remove item from list
        await this.removeItem(listId, productId, clientId, itemNode, iconStyle, iconColor);
      } else {
        // Add item to list
        await this.addItem(listId, productId, clientId, itemNode, iconStyle, iconColor);
      }
      
    } catch (error) {
      this.logger.error('Item click handling failed:', error);
    }
  }

  /**
   * Handle pagination click
   */
  handlePaginationClick(event) {
    this.logger.log('Pagination click detected:', event.target);
    
    if (!event.target || !event.target.classList || !event.target.classList.contains('twc-pagination-btn')) {
      this.logger.log('Not a pagination button, ignoring');
      return;
    }
    
    const action = event.target.getAttribute('data-action');
    const page = event.target.getAttribute('data-page');
    const listId = event.target.getAttribute('data-list-id');
    
    this.logger.log(`Pagination click: action=${action}, page=${page}, listId=${listId}`);
    
    if (!listId) {
      this.logger.error('No listId found on pagination button');
      return;
    }
    
    this.logger.log(`Looking for section with data-list-id="${listId}"`);
    const sections = document.querySelectorAll(`[data-list-id="${listId}"]`);
    this.logger.log(`Found ${sections.length} sections with listId ${listId}`);
    
    // Find the section that has pagination container
    let section = null;
    for (let i = 0; i < sections.length; i++) {
      const paginationContainer = sections[i].querySelector('.twc-pagination-container');
      if (paginationContainer) {
        section = sections[i];
        this.logger.log(`Found section with pagination at index ${i}`);
        break;
      }
    }
    
    if (!section) {
      this.logger.error(`No section with pagination found for listId ${listId}`);
      return;
    }
    
    this.logger.log(`Section found, looking for pagination container`);
    this.logger.log(`Section children:`, Array.from(section.children).map(child => child.className));
    const paginationContainer = section.querySelector('.twc-pagination-container');
    if (!paginationContainer) {
      this.logger.error(`Pagination container not found for listId ${listId}`);
      this.logger.error(`Available elements in section:`, Array.from(section.children).map(child => ({
        tagName: child.tagName,
        className: child.className,
        id: child.id
      })));
      return;
    }
    
    const controls = paginationContainer.querySelector('.twc-pagination-controls');
    const currentPage = parseInt(controls.getAttribute('data-current-page') || '1');
    const totalPages = parseInt(controls.getAttribute('data-total-pages') || '1');
    
    this.logger.log(`Pagination state: currentPage=${currentPage}, totalPages=${totalPages}`);
    
    let newPage = currentPage;
    
    if (action === 'prev') {
      newPage = Math.max(1, currentPage - 1);
    } else if (action === 'next') {
      newPage = Math.min(totalPages, currentPage + 1);
    } else if (page) {
      newPage = parseInt(page);
    }
    
    this.logger.log(`Calculated newPage: ${newPage}, condition check: ${newPage && newPage !== currentPage && newPage >= 1 && newPage <= totalPages}`);
    
    if (newPage && newPage !== currentPage && newPage >= 1 && newPage <= totalPages) {
      this.logger.log(`Pagination click: list ${listId}, page ${currentPage} -> ${newPage}`);
      this.logger.log(`this.manager exists:`, !!this.manager);
      this.logger.log(`this.manager.uiRenderer exists:`, !!this.manager?.uiRenderer);
      this.paginationRenderer.goToPage(listId, newPage, totalPages, this.manager.uiRenderer);
    } else {
      this.logger.log(`Pagination click ignored: newPage=${newPage}, currentPage=${currentPage}, totalPages=${totalPages}`);
    }
  }

  /**
   * Update global data after adding item
   */
  updateGlobalDataAfterAdd(listId, productId, apiResult) {
    this.logger.log(`Updating global data after adding item ${productId} to list ${listId}`);
    
    if (!window.currentListsData || !window.currentListsData.lists) {
      this.logger.error('No global lists data found');
      return;
    }
    
    const list = window.currentListsData.lists.find(l => String(l.id) === String(listId));
    if (!list) {
      this.logger.error(`List ${listId} not found in global data`);
      return;
    }
    
    // Check if item already exists
    const existingItem = list.items.find(item => String(item.external_item_id) === String(productId));
    if (existingItem) {
      this.logger.log(`Item ${productId} already exists in list ${listId}`);
      return;
    }
    
    // Create new item from API result or basic data
    const newItem = apiResult && apiResult.item ? {
      id: apiResult.item.id,
      item_type: 'Product',
      external_item_id: productId,
      created_at: new Date().toISOString(),
      item_link: `/product_by_id/${productId}`,
      item_image: apiResult.item.item_image || '',
      item_price: apiResult.item.item_price || '0',
      item_title: apiResult.item.item_title || `Product ${productId}`
    } : {
      id: Date.now(), // Fallback ID
      item_type: 'Product',
      external_item_id: productId,
      created_at: new Date().toISOString(),
      item_link: `/product_by_id/${productId}`,
      item_image: '',
      item_price: '0',
      item_title: `Product ${productId}`
    };
    
    // Add item to list
    if (!list.items) {
      list.items = [];
    }
    list.items.push(newItem);
    
    this.logger.log(`Added item to global data: list ${listId} now has ${list.items.length} items`);
  }

  /**
   * Update global data after removing item
   */
  updateGlobalDataAfterRemove(listId, productId) {
    this.logger.log(`Updating global data after removing item ${productId} from list ${listId}`);
    
    if (!window.currentListsData || !window.currentListsData.lists) {
      this.logger.error('No global lists data found');
      return;
    }
    
    const list = window.currentListsData.lists.find(l => String(l.id) === String(listId));
    if (!list || !list.items) {
      this.logger.error(`List ${listId} not found or has no items`);
      return;
    }
    
    const originalCount = list.items.length;
    
    // Remove item from list
    list.items = list.items.filter(item => String(item.external_item_id) !== String(productId));
    
    const newCount = list.items.length;
    this.logger.log(`Removed item from global data: list ${listId} now has ${newCount} items (was ${originalCount})`);
  }

  /**
   * Add item to list
   */
  async addItem(listId, productId, clientId, itemNode, iconStyle, iconColor) {
    this.logger.log(`Adding item ${productId} to list ${listId}`);
    
    try {
      const result = await this.manager.apiClient.addItem(this.manager.accountId, listId, clientId, productId);
      
      // Update UI
      itemNode.setAttribute('data-added', 'true');
      itemNode.innerHTML = this.manager.uiRenderer.renderIcon(iconStyle, iconColor, true);
      
      this.logger.log(`Item ${productId} added to list ${listId}`, result);
      
      // Update global data with new item
      this.updateGlobalDataAfterAdd(listId, productId, result);
      
      // Update header counts
      await this.manager.updateHeader(window.currentListsData);
      
    } catch (error) {
      this.logger.error(`Failed to add item ${productId}:`, error);
      // Show error to user
      try {
        alert('Ошибка при добавлении товара в список. Попробуйте еще раз.');
      } catch (e) {
        // Ignore alert errors
      }
    }
  }

  /**
   * Remove item from list
   */
  async removeItem(listId, productId, clientId, itemNode, iconStyle, iconColor) {
    this.logger.log(`Removing item ${productId} from list ${listId}`);
    
    try {
      // First, get the list item ID from API
      const listItems = await this.manager.apiClient.getListItems(this.manager.accountId, listId, clientId);
      const items = (listItems && listItems.items) || [];
      const match = items.find(item => String(item.item_id) === String(productId));
      
      if (!match) {
        this.logger.error(`Item ${productId} not found in list ${listId}`);
        return;
      }
      
      // Remove the item
      const result = await this.manager.apiClient.removeItem(this.manager.accountId, listId, match.id);
      
      // Update UI
      itemNode.setAttribute('data-added', 'false');
      itemNode.innerHTML = this.manager.uiRenderer.renderIcon(iconStyle, iconColor, false);
      
      this.logger.log(`Item ${productId} removed from list ${listId}`, result);
      
      // Update global data after removal
      this.updateGlobalDataAfterRemove(listId, productId);
      
      // If on favorites page, remove the card and handle pagination
      if (this.manager.isFavoritesPage()) {
        const card = itemNode.closest('.twc-list-card');
        if (card && card.parentNode) {
          card.parentNode.removeChild(card);
          
          // Handle pagination update
          this.paginationRenderer.handleItemRemoval(listId, productId, this.manager.uiRenderer);
        }
      }
      
      // Update header counts
      await this.manager.updateHeader(window.currentListsData);
      
    } catch (error) {
      this.logger.error(`Failed to remove item ${productId}:`, error);
      // Show error to user
      try {
        alert('Ошибка при удалении товара из списка. Попробуйте еще раз.');
      } catch (e) {
        // Ignore alert errors
      }
    }
  }
}

// Main Lists Manager
class ListsManager {
  constructor(accountId, options = {}) {
    this.accountId = accountId;
    this.debug = options.debug || false;
    this.logger = new Logger(this.debug);
    this.dataManager = new DataManager(this.logger);
    this.uiRenderer = new UIRenderer(this.logger);
    this.apiClient = new APIClient(this.logger);
    this.eventHandler = new EventHandler(this, this.logger);
    
    this.logger.log(`ListsManager initialized with accountId: ${accountId}`);
  }

  /**
   * Get account ID from script tag
   */
  static getAccountIdFromScript() {
    const scripts = document.getElementsByTagName('script');
    for (let i = 0; i < scripts.length; i++) {
      const src = scripts[i].getAttribute('src') || '';
      if (src.includes('list.js')) {
        try {
          const url = new URL(src, window.location.origin);
          const id = url.searchParams.get('id');
          if (id) return id;
        } catch (e) {
          // Ignore URL parsing errors
        }
      }
    }
    return null;
  }

  /**
   * Get client from Insales API
   */
  async getClient() {
    return new Promise((resolve, reject) => {
      if (typeof ajaxAPI !== 'undefined' && ajaxAPI.shop && ajaxAPI.shop.client) {
        ajaxAPI.shop.client.get().done(resolve).fail(reject);
      } else {
        reject(new Error('ajaxAPI.shop.client is not available'));
      }
    });
  }

  /**
   * Check if current page is favorites page
   */
  isFavoritesPage() {
    return /favorites/i.test(window.location.href);
  }

  /**
   * Get main container element
   */
  getMainContainer() {
    let main = document.querySelector('.lists-wrapper');
    if (!main) {
      main = document.querySelector('main');
    }
    if (!main) {
      main = document.querySelector('body');
    }
    return main;
  }

  /**
   * Load CSS dynamically
   */
  async loadCSS() {
    return new Promise((resolve) => {
      const link = document.createElement('link');
      link.rel = 'stylesheet';
      link.href = 'https://s3.twcstorage.ru/ae4cd7ee-b62e0601-19d6-483e-bbf1-416b386e5c23/scripts/list.css';
      link.onload = () => {
        this.logger.log('CSS loaded');
        resolve();
      };
      link.onerror = () => {
        this.logger.log('CSS not found, continuing without styles');
        resolve();
      };
      document.head.appendChild(link);
    });
  }

  /**
   * Initialize the Lists Manager
   */
  async initialize() {
    try {
      this.logger.log(`Starting initialization... (${CONFIG.version})`);
      
      // Load CSS
      await this.loadCSS();
      
      // Get client
      const client = await this.getClient().catch((e) => {
        this.logger.error('Failed to get client, switching to guest mode:', e);
        return null;
      });
      if (!client || !client.id) {
        this.logger.log('[GuestMode] No client available - rendering preview icons');
        await this.setupGuestMode();
        return;
      }
      
      this.logger.log('Client loaded:', client);
      
      // Load lists data
      const listsData = await this.dataManager.fetchClientListsData(this.accountId, client.id);
      
      // Store globally for other functions
      window.currentListsData = listsData;
      
      // Render favorites page if needed
      if (this.isFavoritesPage()) {
        await this.renderFavoritesPage(listsData);
      }
      
      // Initialize item states for category/product pages
      if (!this.isFavoritesPage()) {
        await this.initializeItemStates(listsData);
      }
      
      // Update header
      this.logger.log('=== Starting header update ===');
      this.debugSectionContents();
      await this.updateHeader(listsData);
      this.debugSectionContents();
      this.logger.log('=== Header update completed ===');
      
      // Bind event handlers
      this.logger.log('=== Starting event binding ===');
      this.debugSectionContents();
      this.eventHandler.bindEvents();
      this.debugSectionContents();
      this.logger.log('=== Event binding completed ===');
            
    } catch (error) {
      this.logger.error('Initialization failed:', error);
      // As a safety net, try guest mode too
      try {
        await this.setupGuestMode();
      } catch (_) {}
    }
  }

  /**
   * Guest mode: render icons on category/product pages and header, bind alert on click
   */
  async setupGuestMode() {
    const logger = this.logger;
    const ui = this.uiRenderer;
    logger.log('[GuestMode] Enabled');
    // Load lists from S3: list_{accountId}.json
    let guestLists = [];
    try {
      if (this.accountId) {
        const listsData = await this.dataManager.fetchListsData(this.accountId);
        if (listsData && Array.isArray(listsData.lists)) {
          guestLists = listsData.lists.map(l => ({
            id: l.id,
            name: l.name,
            icon_style: l.icon_style || 'icon_one',
            icon_color: l.icon_color || '#999999'
          }));
          logger.log(`[GuestMode] Loaded ${guestLists.length} lists from S3`);
        }
      }
    } catch (e) {
      logger.log('[GuestMode] Failed to load list_{accountId}.json');
    }
    // If lists are not available, do not render anything in guest mode
    if (!guestLists.length) {
      logger.log('[GuestMode] No lists available, skipping icon rendering');
      return;
    }
    // Render triggers and header icons using shared helpers
    this.renderTriggersFromLists(guestLists);
    this.renderHeaderFromLists(guestLists);
    // Bind alert on clicks (idempotent: harmless if added twice)
    document.addEventListener('click', (event) => {
      if (!event.target || !event.target.classList) return;
      if (event.target.classList.contains('twc-list-item') || event.target.classList.contains('twc-header-list-item')) {
        event.preventDefault();
        try { alert('зарегистрируйтесь чтобы сохранить свой список'); } catch (e) {}
      }
    });
  }

  /**
   * Shared: render triggers for category/product hosts from lists
   */
  renderTriggersFromLists(lists) {
    const nodes = document.querySelectorAll('[data-ui-favorites-trigger]');
    this.logger.log(`[Shared] Found ${nodes.length} elements with data-ui-favorites-trigger`);
    nodes.forEach(node => {
      const productId = node.getAttribute('data-ui-favorites-trigger');
      const container = this.uiRenderer.createListsContainer(lists, { attach: false });
      node.innerHTML = '';
      node.appendChild(container);
      if (productId) {
        node.removeAttribute('data-ui-favorites-trigger');
        node.setAttribute('data-ui-favorites-trigger-twc', productId);
      }
    });
  }

  /**
   * Shared: render header icons from lists
   */
  renderHeaderFromLists(lists) {
    try {
      const headerContainer = document.querySelector('.header__favorite');
      if (!headerContainer) {
        this.logger.log('[Shared] Header container not found');
        return;
      }
      headerContainer.innerHTML = '';
      lists.forEach(list => {
        const listIcon = this.createListIconElement({
          id: list.id,
          name: list.name,
          icon_style: list.icon_style || 'icon_one',
          icon_color: list.icon_color || '#999999',
          items: list.items || [] // Use actual items if available
        });
        headerContainer.appendChild(listIcon);
      });
      this.logger.log('[Shared] Header icons rendered');
    } catch (e) {
      this.logger.log('[Shared] Failed to render header icons:', e);
    }
  }

  /**
   * Render favorites page
   */
  async renderFavoritesPage(listsData) {
    this.logger.log('=== renderFavoritesPage called ===');
    this.logger.log('Lists data:', listsData);
    
    const main = this.getMainContainer();
    if (!main) {
      this.logger.error('No main container found');
      return;
    }
    
    this.logger.log('Main container found, clearing...');
    // Clear main container
    main.innerHTML = '';
    
    // Render each list
    if (listsData && listsData.lists) {
      listsData.lists.forEach(list => {
        const section = this.uiRenderer.renderSection(list);
        main.appendChild(section);
        
        // Initialize pagination state after section is added to DOM
        if (list.items && list.items.length > CONFIG.itemsPerPage) {
          const totalPages = Math.ceil(list.items.length / CONFIG.itemsPerPage);
          this.uiRenderer.paginationRenderer.updatePaginationState(list.id, 1, totalPages);
        }
      });
    }
    
    this.logger.log('=== renderFavoritesPage completed ===');
    this.logger.log('Favorites page rendered');
  }

  /**
   * Initialize item states on category/product pages
   */
  async initializeItemStates(listsData) {
    this.logger.log('Initializing item states...');
    
    // First, create favorites triggers for elements that have data-ui-favorites-trigger
    await this.updateFavoritesTriggers(listsData.lists || []);
    
    const hosts = document.querySelectorAll('[data-ui-favorites-trigger-twc]');
    this.logger.log(`Found ${hosts.length} hosts with data-ui-favorites-trigger-twc`);
    
    for (const host of hosts) {
      const productId = host.getAttribute('data-ui-favorites-trigger-twc');
      const items = host.querySelectorAll('.twc-list-item');
      
      for (const item of items) {
        const listId = item.getAttribute('data-list-id');
        const iconStyle = item.getAttribute('data-icon-style');
        const iconColor = item.getAttribute('data-icon-color');
        
        const listData = listsData.lists.find(l => String(l.id) === String(listId));
        
        if (listData && listData.items) {
          const isPresent = listData.items.some(it =>
            String(it.external_item_id) === String(productId)
          );
          
          item.setAttribute('data-added', isPresent ? 'true' : 'false');
          item.innerHTML = this.uiRenderer.renderIcon(iconStyle, iconColor, isPresent);
        }
      }
    }
    
    this.logger.log('Item states initialized');
  }

  /**
   * Update favorites triggers - create favorites containers for elements with data-ui-favorites-trigger
   */
  async updateFavoritesTriggers(lists) {
    this.logger.log('Updating favorites triggers...');
    
    const nodes = document.querySelectorAll('[data-ui-favorites-trigger]');
    this.logger.log(`Found ${nodes.length} elements with data-ui-favorites-trigger`);
    
    if (!nodes || !nodes.length) {
      this.logger.log('No elements to update');
      return [];
    }
    
    const results = [];
    for (const node of nodes) {
      const productId = node.getAttribute('data-ui-favorites-trigger');
      this.logger.log(`Processing element with product ID: ${productId}`);
      
      // Create lists container
      const container = this.uiRenderer.createListsContainer(lists, { attach: false });
      node.innerHTML = '';
      node.appendChild(container);
      
      // Update attribute: move data-ui-favorites-trigger to data-ui-favorites-trigger-twc
      if (productId) {
        node.removeAttribute('data-ui-favorites-trigger');
        node.setAttribute('data-ui-favorites-trigger-twc', productId);
        this.logger.log(`Updated attribute for product ${productId}`);
      }
      
      results.push(node);
    }
    
    this.logger.log(`Updated ${results.length} favorites triggers`);
    return results;
  }

  /**
   * Debug method to check section contents
   */
  debugSectionContents() {
    const sections = document.querySelectorAll('[data-list-id]');
    this.logger.log(`=== Debug: Found ${sections.length} sections ===`);
    sections.forEach(section => {
      const listId = section.getAttribute('data-list-id');
      const children = Array.from(section.children).map(child => ({
        tagName: child.tagName,
        className: child.className,
        id: child.id
      }));
      this.logger.log(`Section ${listId} children:`, children);
    });
  }

  /**
   * Update header with list counts
   */
  async updateHeader(listsData) {
    this.logger.log('Updating header...');
    
    const headerContainer = document.querySelector('.header__favorite');
    if (!headerContainer) {
      this.logger.log('Header container not found');
      return;
    }
    
    // Clear existing content
    headerContainer.innerHTML = '';
    
    if (listsData && listsData.lists) {
      this.logger.log(`Updating header with ${listsData.lists.length} lists`);
      // Reuse shared renderer for consistency
      this.renderHeaderFromLists(listsData.lists);
    } else {
      this.logger.log('No lists data available for header update');
    }
    
    this.logger.log('Header updated');
  }

  /**
   * Create list icon element for header
   */
  createListIconElement(list) {
    const itemCount = (list.items || []).length;
    this.logger.log(`Creating header icon for list ${list.id} (${list.name}) with ${itemCount} items`);
    
    const listIcon = document.createElement('span');
    listIcon.className = 'twc-header-list-item';
    listIcon.setAttribute('data-list-id', String(list.id));
    listIcon.setAttribute('data-list-name', list.name || '');
    listIcon.setAttribute('data-icon-style', list.icon_style || 'icon_one');
    listIcon.setAttribute('data-icon-color', list.icon_color || '#999999');
    
    const iconHtml = this.uiRenderer.renderIcon(list.icon_style || 'icon_one', list.icon_color || '#999999', true);
    listIcon.innerHTML = iconHtml;
    
    // Add badge with count
    const badge = document.createElement('span');
    badge.className = 'header__control-bage twc-list-badge';
    badge.textContent = String(itemCount);
    listIcon.appendChild(badge);
    
    this.logger.log(`Header icon created with badge showing ${itemCount}`);
    return listIcon;
  }
}

// Initialize when DOM is ready
(function() {
  // Global debug flag
  let globalDebug = false;
  
  // Check debug parameter from script URL
  const scripts = document.getElementsByTagName('script');
  for (let i = 0; i < scripts.length; i++) {
    const src = scripts[i].getAttribute('src') || '';
    if (src.includes('list.js')) {
      try {
        const url = new URL(src, window.location.origin);
        const dbg = url.searchParams.get('debug');
        globalDebug = dbg === '1' || dbg === 'true';
        break;
      } catch (e) {
        // Ignore URL parsing errors
      }
    }
  }
  
  if (globalDebug) {
    console.log(`[ListsManager] Class-based implementation loaded (${CONFIG.version})`);
    console.log(`[ListsManager] Debug mode enabled`);
  }
  
  
  function runInitialization() {
    const accountId = ListsManager.getAccountIdFromScript();
    if (!accountId) {
      if (globalDebug) {
        console.log('[ListsManager] No account ID found');
      }
      return;
    }
    
    const manager = new ListsManager(accountId, { debug: globalDebug });
    manager.initialize();
  }
  
  // Always initialize on DOMContentLoaded
  document.addEventListener('DOMContentLoaded', runInitialization);
})();
