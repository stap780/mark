/**
 * Webform.js - Конструктор веб-форм
 * Версия: 1.3.7
 * Описание: Скрипт для работы с веб-формами на сайте клиента
 */

(function() {
  'use strict';

  class WebformManager {
    constructor() {
      this.version = "1.3.7";
      this.status = false;
      this.S3_BASE = "https://s3.twcstorage.ru/ae4cd7ee-b62e0601-19d6-483e-bbf1-416b386e5c23";
      this.API_BASE = "https://app.teletri.ru/api";
      this.accountId = null;
      this.webforms = [];
      this.abandonedCartData = {
        timestamp: new Date().getTime(),
        email: null,
        phone: null,
        name: null,
        sent: false
      };
      this.init();
    }

    debugLog() {
      if (!this.status) return;
      try { console.log('[webform v' + this.version + ']', ...arguments); } catch(e) { /* noop */ }
    }

    getVersion() {
      return this.version;
    }

    getCookie(name) {
      const value = `; ${document.cookie}`;
      const parts = value.split(`; ${name}=`);
      if (parts.length === 2) return parts.pop().split(';').shift();
      return null;
    }

    getYandexClientId() {
      return this.getCookie('_ym_uid') || null;
    }

    init() {
      this.getAccountId();
      if (this.accountId) {
        this.loadWebforms().then(() => {
          this.setupEventListeners();
        });
      }
    }

    getAccountId() {
      const scripts = document.querySelectorAll("script");
      for (let i = 0; i < scripts.length; i++) {
        const src = scripts[i].getAttribute("src") || "";
        if (src.includes("webform.js")) {
          try {
            const url = new URL(src, window.location.origin);
            const id = url.searchParams.get("id");
            const dbg = url.searchParams.get("debug");

            if (dbg === "1" || dbg === "true") {
              this.status = true;
            }

            if (id) {
              this.accountId = id;
              return;
            }
          } catch (e) {
            console.error("WebformManager: Error parsing script URL", e);
          }
        }
      }
    }

    async loadWebforms() {
      // Пробуем сначала production путь, затем dev
      const prodKey = `webforms/webform_${this.accountId}.json`;
      const devKey = `webforms/dev_webform_${this.accountId}.json`;
      
      const urls = [
        `${this.S3_BASE}/${prodKey}?t=${Date.now()}`,
        `${this.S3_BASE}/${devKey}?t=${Date.now()}`
      ];

      for (const url of urls) {
        try {
          this.debugLog(`[loadWebforms] Fetching from: ${url}`);
          const response = await fetch(url, { credentials: 'omit', cache: 'no-cache' });
          if (response.ok) {
            const data = await response.json();
            this.webforms = data.webforms || [];
            this.debugLog(`[loadWebforms] Successfully loaded ${this.webforms.length} webforms`);
            return;
          }
        } catch (error) {
          this.debugLog(`[loadWebforms] Error loading from ${url}:`, error);
          // Пробуем следующий URL
          continue;
        }
      }
      
      console.warn("WebformManager: Failed to load webforms data from both production and dev paths");
    }

    setupEventListeners() {
      this.debugLog(`[setupEventListeners] Setting up listeners for ${this.webforms.length} webforms`);
      this.webforms.forEach(webform => {
        this.debugLog(`[setupEventListeners] Setting up listener for webform: ${webform.kind} (id: ${webform.id})`);
        this.setupInlineContainers(webform);
        switch (webform.kind) {
          case 'notify':
            this.handleNotify(webform);
            break;
          case 'preorder':
            this.handlePreorder(webform);
            break;
          case 'custom':
            this.handleCustom(webform);
            break;
          case 'abandoned_cart':
            this.handleAbandonedCart(webform);
            break;
        }
      });
    }

    setupInlineContainers(webform) {
      const containers = document.querySelectorAll(`[data-twc-webform-id="${webform.id}"][data-twc-webform-inline]`);
      this.debugLog(`[setupInlineContainers] Found ${containers.length} inline container(s) for webform ${webform.id}`);
      containers.forEach(container => {
        const html = this.generateFormHTML(webform, {}, { inline: true });
        container.innerHTML = html;
        this.applyPhoneMasks(container);
        const form = container.querySelector('.twc-webform-preview-form');
        if (form) {
          form.addEventListener('submit', (e) => {
            e.preventDefault();
            e.stopPropagation();
            this.handleFormSubmit(e, webform, {}, container);
            return false;
          });
        }
      });
    }

    handleNotify(webform) {
      const trigger = webform.trigger || {};
      const triggerType = trigger.type || 'event';
      
      this.debugLog(`[handleNotify] Webform ${webform.id} trigger type: ${triggerType}`);
      
      // Существующий механизм через EventBus (для совместимости)
      if (triggerType === 'event' || triggerType === 'manual') {
        if (typeof EventBus !== 'undefined' && EventBus.subscribe) {
          this.debugLog(`[handleNotify] Subscribing to empty-product:insales:site for webform ${webform.id}`);
          EventBus.subscribe("empty-product:insales:site", (data) => {
            this.debugLog(`[handleNotify] Event received:`, data);
            const productId = data?.productId || document.querySelector("[data-feedback-product-id]")?.dataset?.feedbackProductId;
            const variantId = data?.variantId || document.querySelector("[data-variant-id]")?.dataset?.variantId;
            this.debugLog(`[handleNotify] ProductId: ${productId}, VariantId: ${variantId}`);
            this.showForm(webform, { productId, variantId });
          });
        } else {
          this.debugLog(`[handleNotify] EventBus not available`);
        }
        
        // Ручной показ через data-twc-webform-id (новый функционал)
        if (triggerType === 'manual') {
          this.setupManualTrigger(webform);
        }
      } else {
        // Автоматические триггеры (exit_intent, time_on_page, scroll_depth)
        this.handleWebformWithTrigger(webform, 'notify');
      }
    }

    handlePreorder(webform) {
      const trigger = webform.trigger || {};
      const triggerType = trigger.type || 'event';
      
      this.debugLog(`[handlePreorder] Webform ${webform.id} trigger type: ${triggerType}`);
      
      // Ручной показ через data-twc-webform-id
      if (triggerType === 'manual') {
        this.setupManualTrigger(webform);
      } else if (triggerType === 'event') {
        // Для event триггера также используем новый механизм
        this.setupManualTrigger(webform);
      } else {
        // Автоматические триггеры (exit_intent, time_on_page, scroll_depth)
        this.handleWebformWithTrigger(webform, 'preorder');
      }
    }

    handleCustom(webform) {
      this.handleWebformWithTrigger(webform, 'custom');
    }

    handleAbandonedCart(webform) {
      const trigger = webform.trigger || {};
      const triggerType = trigger.type || 'activity';
      
      this.debugLog(`[handleAbandonedCart] Webform ${webform.id} trigger type: ${triggerType}`);
      
      // Унифицированный exit-intent для сценария "Брошенная корзина"
      // Работает как на checkout-странице, так и на остальных.
      this.setupAbandonedCartExitIntent(webform, trigger);

      // Дополнительная логика только для страницы оформления заказа (new_order)
      if (!this.isCheckoutPage()) {
        return;
      }
      
      // Страница оформления заказа (new_order)
      // ТИХИЙ сценарий: отслеживаем активность и отправляем данные без попапа,
      // но теперь не требуем, чтобы поля были заполнены уже в момент инициализации.
      const intervalForSend = 4000;
      const userDataKey = "userData";

      // Отслеживание активности (один раз при инициализации)
      document.addEventListener("mousemove", () => this.setTimestamp());
      document.addEventListener("click", () => this.setTimestamp());
      document.addEventListener("keydown", () => this.setTimestamp());
      document.body.addEventListener("mouseleave", () => {
        if (this.isRegistered()) {
          this.getRegisteredData(webform, userDataKey);
        } else {
          this.getUnregisteredData(webform, userDataKey);
        }
      });

      // Сбор данных из полей формы оформления заказа
      const emailInput = document.querySelector("input[name='client[email]']");
      const phoneInput = document.querySelector("input[name='client[phone]']");
      const nameInput = document.querySelector("input[name='client[name]']");
      const shippingAddressPhone = document.querySelector("input[name='shipping_address[phone]']");

      if (emailInput) emailInput.addEventListener("input", (e) => this.abandonedCartData.email = e.target.value);
      if (phoneInput) phoneInput.addEventListener("input", (e) => this.abandonedCartData.phone = e.target.value);
      if (nameInput) nameInput.addEventListener("input", (e) => this.abandonedCartData.name = e.target.value);
      if (shippingAddressPhone) shippingAddressPhone.addEventListener("input", (e) => this.abandonedCartData.phone = e.target.value);

      // Периодическая проверка и отправка
      setInterval(() => {
        if (this.abandonedCartData.sent) return;
        
        const timeSinceLastActivity = new Date().getTime() - this.abandonedCartData.timestamp;
        if (timeSinceLastActivity >= intervalForSend) {
          if (this.isRegistered()) {
            this.getRegisteredData(webform, userDataKey);
          } else {
            this.getUnregisteredData(webform, userDataKey);
          }
        }
      }, 2000);

      // Дополнительно: если в момент инициализации поля ещё не заполнены,
      // сохраняем прежнее поведение с показом попапа при наличии товаров.
      if (!this.areCheckoutFieldsComplete()) {
        const items = this.getOrderLines();
        if (!items || items.length === 0) {
          this.debugLog('[handleAbandonedCart] Checkout page: no items in cart, popup will not be shown.');
          return;
        }

        if (!this.shouldShowForm(webform, trigger)) {
          this.debugLog('[handleAbandonedCart] Checkout page: shouldShowForm returned false, popup will not be shown.');
          return;
        }

        this.showFormWithDelay(webform, trigger);
      }
    }
    
    // Универсальный метод для обработки форм с триггерами
    handleWebformWithTrigger(webform, kind) {
      const trigger = webform.trigger || {};
      const triggerType = trigger.type || this.getDefaultTriggerType(kind);
      
      this.debugLog(`[handleWebformWithTrigger] Webform ${webform.id} (${kind}) trigger type: ${triggerType}`);
      
      // Ручной показ через data-атрибуты
      if (triggerType === 'manual') {
        this.setupManualTrigger(webform);
        return;
      }
      
      // Проверяем условия показа для автоматических триггеров
      if (!this.shouldShowForm(webform, trigger)) {
        this.debugLog(`[handleWebformWithTrigger] Form ${webform.id} should not be shown (conditions not met)`);
        return;
      }
      
      // Настраиваем триггер в зависимости от типа
      switch (triggerType) {
        case 'exit_intent':
          this.setupExitIntent(webform, trigger);
          break;
        case 'time_on_page':
          this.setupTimeOnPage(webform, trigger);
          break;
        case 'scroll_depth':
          this.setupScrollDepth(webform, trigger);
          break;
        case 'event':
        case 'activity':
          // Эти типы обрабатываются в специфичных методах handleNotify, handlePreorder, handleAbandonedCart
          break;
      }
    }
    
    // Exit-intent обработчик специально для сценария "Брошенная корзина".
    // Используется и на checkout-странице, и на остальных.
    setupAbandonedCartExitIntent(webform, trigger) {
      this.debugLog(`[setupAbandonedCartExitIntent] Setting up abandoned cart exit-intent for webform ${webform.id}`);
      
      document.addEventListener('mouseout', (e) => {
        // Классический exit-intent: мышь уходит к верхней границе окна
        if (!e.toElement && !e.relatedTarget && e.clientY < 10) {
          const items = this.getOrderLines();
          if (!items || items.length === 0) {
            this.debugLog('[handleAbandonedCart] Exit-intent: no items in cart, popup will not be shown.');
            return;
          }

          // Проверяем таргетинг устройств
          const deviceType = this.getDeviceType();
          if (trigger.target_devices && !trigger.target_devices.includes(deviceType)) {
            this.debugLog(`[handleAbandonedCart] Exit-intent: device ${deviceType} not in target devices, popup will not be shown.`);
            return;
          }

          // Проверяем таргетинг страниц, но игнорируем историю показов (isFormShown),
          // чтобы форма могла показываться при каждом уходе.
          if (!this.isPageTargeted(trigger)) {
            this.debugLog('[handleAbandonedCart] Exit-intent: current page not targeted, popup will not be shown.');
            return;
          }

          this.debugLog('[handleAbandonedCart] Exit-intent detected, showing popup.');
          const delay = trigger.show_delay || 0;
          setTimeout(() => {
            this.showForm(webform, {});
            // НЕ вызываем saveFormShown → нет куки/лимитов показа для abandoned_cart
          }, delay);
        }
      });
    }
    
    setupManualTrigger(webform) {
      const manualTriggers = document.querySelectorAll(`[data-twc-webform-id="${webform.id}"]:not([data-twc-webform-inline])`);
      this.debugLog(`[setupManualTrigger] Found ${manualTriggers.length} manual triggers for webform ${webform.id}`);
      manualTriggers.forEach(trigger => {
        trigger.addEventListener('click', (e) => {
          e.preventDefault();
          // Извлекаем данные: сначала с самого элемента, затем ищем вверх по DOM дереву
          let productId = trigger.getAttribute('data-product-id');
          let variantId = trigger.getAttribute('data-variant-id');
          
          // Если не найдено на элементе, ищем в родителях (closest ищет вверх до корня документа)
          if (!productId) {
            const productParent = trigger.closest('[data-product-id]');
            productId = productParent?.getAttribute('data-product-id') || null;
          }
          
          if (!variantId) {
            const variantParent = trigger.closest('[data-variant-id]');
            variantId = variantParent?.getAttribute('data-variant-id') || null;
          }
          
          this.debugLog(`[setupManualTrigger] Manual trigger clicked - ProductId: ${productId}, VariantId: ${variantId}`);
          this.showForm(webform, { productId, variantId });
        });
      });
    }
    
    getDefaultTriggerType(kind) {
      switch (kind) {
        case 'custom':
          return 'manual';
        case 'notify':
        case 'preorder':
          return 'event';
        case 'abandoned_cart':
          return 'activity';
        default:
          return null;
      }
    }
    
    setupExitIntent(webform, trigger) {
      this.debugLog(`[setupExitIntent] Setting up exit intent for webform ${webform.id}`);
      let exitIntentTriggered = false;
      
      document.addEventListener('mouseout', (e) => {
        // Проверяем, что мышь движется к верхней части окна
        if (!e.toElement && !e.relatedTarget && e.clientY < 10) {
          if (!exitIntentTriggered && this.shouldShowForm(webform, trigger)) {
            exitIntentTriggered = true;
            this.debugLog(`[setupExitIntent] Exit intent detected for webform ${webform.id}`);
            this.showFormWithDelay(webform, trigger);
          }
        }
      });
    }
    
    setupTimeOnPage(webform, trigger) {
      this.debugLog(`[setupTimeOnPage] Setting up time on page (${trigger.value}s) for webform ${webform.id}`);
      if (this.shouldShowForm(webform, trigger)) {
        setTimeout(() => {
          this.showFormWithDelay(webform, trigger);
        }, (trigger.value || 30) * 1000);
      }
    }
    
    setupScrollDepth(webform, trigger) {
      this.debugLog(`[setupScrollDepth] Setting up scroll depth (${trigger.value}%) for webform ${webform.id}`);
      if (!this.shouldShowForm(webform, trigger)) return;
      
      let scrollTriggered = false;
      
      window.addEventListener('scroll', () => {
        if (!scrollTriggered) {
          const scrollPercent = (window.scrollY / (document.documentElement.scrollHeight - window.innerHeight)) * 100;
          
          if (scrollPercent >= (trigger.value || 75)) {
            scrollTriggered = true;
            this.debugLog(`[setupScrollDepth] Scroll depth reached for webform ${webform.id}`);
            this.showFormWithDelay(webform, trigger);
          }
        }
      });
    }
    
    shouldShowForm(webform, trigger) {
      // Проверка cookie/sessionStorage
      if (this.isFormShown(webform, trigger)) {
        this.debugLog(`[shouldShowForm] Form ${webform.id} already shown`);
        return false;
      }
      
      // Проверка устройства
      const deviceType = this.getDeviceType();
      if (trigger.target_devices && !trigger.target_devices.includes(deviceType)) {
        this.debugLog(`[shouldShowForm] Device ${deviceType} not in target devices`);
        return false;
      }
      
      // Проверка таргетинга страниц
      if (!this.isPageTargeted(trigger)) {
        this.debugLog(`[shouldShowForm] Current page not targeted`);
        return false;
      }
      
      return true;
    }
    
    isCheckoutPage() {
      const path = window.location.pathname || "";
      return path.includes('new_order');
    }

    areCheckoutFieldsComplete() {
      const emailInput = document.querySelector("input[name='client[email]']");
      const phoneInput = document.querySelector("input[name='client[phone]']");
      const nameInput  = document.querySelector("input[name='client[name]']");

      const email = emailInput ? emailInput.value.trim() : "";
      const phone = phoneInput ? phoneInput.value.trim() : "";
      const name  = nameInput  ? nameInput.value.trim()  : "";

      // Минимальное требование: есть имя И (email ИЛИ телефон)
      return !!name && (!!email || !!phone);
    }
    
    getDeviceType() {
      const width = window.innerWidth;
      if (width < 768) return 'mobile';
      if (width < 1024) return 'tablet';
      return 'desktop';
    }
    
    isPageTargeted(trigger) {
      const currentPath = window.location.pathname;
      const currentUrl = window.location.href;
      
      // Проверка exclude_pages
      if (trigger.exclude_pages && trigger.exclude_pages.length > 0) {
        for (let i = 0; i < trigger.exclude_pages.length; i++) {
          if (currentPath.includes(trigger.exclude_pages[i]) || currentUrl.includes(trigger.exclude_pages[i])) {
            return false;
          }
        }
      }
      
      // Проверка target_pages
      if (trigger.target_pages && trigger.target_pages.length > 0) {
        let matched = false;
        for (let i = 0; i < trigger.target_pages.length; i++) {
          if (currentPath.includes(trigger.target_pages[i]) || currentUrl.includes(trigger.target_pages[i])) {
            matched = true;
            break;
          }
        }
        if (!matched) {
          return false;
        }
      }
      
      return true;
    }
    
    getShowCount(cookieValue) {
      if (!cookieValue) return 0;
      if (cookieValue.startsWith('count:')) {
        const num = parseInt(cookieValue.replace('count:', ''), 10);
        return isNaN(num) ? 1 : num;
      }
      // Старый формат cookie (просто "1")
      return 1;
    }
    
    isFormShown(webform, trigger) {
      const cookieName = trigger.cookie_name || `webform_${webform.id}_shown`;
      
      // Проверка sessionStorage (для show_once_per_session)
      if (trigger.show_once_per_session && sessionStorage.getItem(cookieName)) {
        return true;
      }
      
      // Проверка cookie (для show_frequency_days)
      const cookieValue = this.getCookie(cookieName);
      if (cookieValue) {
        // Если настроен лимит показов (max_shows) и мы его не достигли,
        // НЕ блокируем показ по одной только cookie.
        if (trigger.max_shows) {
          const count = this.getShowCount(cookieValue);
          if (count >= trigger.max_shows) {
            this.debugLog(`[shouldShowForm] Max shows reached (${count}/${trigger.max_shows}) for form ${webform.id}`);
            return true;
          } else {
            // Можно показывать ещё раз
            return false;
          }
        }
        return true;
      }
      
      return false;
    }
    
    showFormWithDelay(webform, trigger) {
      const delay = trigger.show_delay || 0;
      this.debugLog(`[showFormWithDelay] Showing form ${webform.id} with delay ${delay}ms`);
      
      setTimeout(() => {
        this.showForm(webform, {});
        this.saveFormShown(webform, trigger);
      }, delay);
    }
    
    saveFormShown(webform, trigger) {
      const cookieName = trigger.cookie_name || `webform_${webform.id}_shown`;
      
      // Сохранение в sessionStorage (для show_once_per_session)
      if (trigger.show_once_per_session) {
        sessionStorage.setItem(cookieName, '1');
      }
      
      // Сохранение в cookie с учётом count и show_frequency_days / max_shows
      let currentCookie = this.getCookie(cookieName);
      let count = this.getShowCount(currentCookie);
      count += 1;
      const value = `count:${count}`;
      
      if (trigger.show_frequency_days) {
        const expires = new Date(Date.now() + trigger.show_frequency_days * 24 * 60 * 60 * 1000);
        document.cookie = `${cookieName}=${value}; expires=${expires.toUTCString()}; path=/`;
      } else if (!trigger.show_once_per_session || trigger.max_shows) {
        // Если нет ограничений по дням, но есть show_times или выключен show_once_per_session,
        // сохраняем cookie без срока.
        document.cookie = `${cookieName}=${value}; path=/`;
      }
    }
    
    getCookie(name) {
      const cookies = document.cookie.split(';');
      for (let i = 0; i < cookies.length; i++) {
        const cookie = cookies[i].trim();
        if (cookie.startsWith(name + '=')) {
          return cookie.substring(name.length + 1);
        }
      }
      return null;
    }

    setTimestamp() {
      this.abandonedCartData.timestamp = new Date().getTime();
      this.abandonedCartData.sent = false;
    }

    isRegistered() {
      const blocks = Array.from(document.querySelectorAll(".co-client-info .co-client-field"));
      return blocks.length > 0;
    }

    getRegisteredData(webform, userDataKey) {
      const blocks = Array.from(document.querySelectorAll(".co-client-info .co-client-field"));
      blocks.forEach(el => {
        const text = el.innerText;
        if (text.match(/[a-zа-я0-9\.\-_]+@[a-zа-я0-9\.\-_]+\.[a-z0-9]+/im)) {
          this.abandonedCartData.email = text;
        } else {
          this.abandonedCartData.phone = text;
        }
      });

      if (this.abandonedCartData.phone || this.abandonedCartData.email) {
        if (this.localStorageHas(userDataKey)) {
          this.parseUpdateAndSendData(webform, userDataKey);
        } else {
          this.createSaveAndSendData(webform, userDataKey);
        }
      }
    }

    getUnregisteredData(webform, userDataKey) {
      const phoneInput = document.querySelector("input[name='client[phone]']");
      const emailInput = document.querySelector("input[name='client[email]']");
      const nameInput = document.querySelector("input[name='client[name]']");

      if (phoneInput) this.abandonedCartData.phone = phoneInput.value;
      if (emailInput) this.abandonedCartData.email = emailInput.value;
      if (nameInput) this.abandonedCartData.name = nameInput.value;

      if (this.abandonedCartData.phone || this.abandonedCartData.email || this.abandonedCartData.name) {
        if (this.localStorageHas(userDataKey)) {
          this.parseUpdateAndSendData(webform, userDataKey);
        } else {
          this.createSaveAndSendData(webform, userDataKey);
        }
      }
    }

    localStorageHas(key) {
      return localStorage.getItem(key) !== null;
    }

    createUniqueId(idLength = 16) {
      const symbols = (this.accountId + "aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ0123456789!@#$%^*()_+-=").split("");
      let first = [this.accountId];

      for (let i = 0; i < idLength; i++) {
        first.push(symbols[Math.floor(Math.random() * symbols.length)]);
      }

      return first.sort(() => 0.5 - Math.random()).join("");
    }

    async createSaveAndSendData(webform, userDataKey) {
      const id = this.createUniqueId();
      const userDataObject = {
        id: id,
        contacts: {
          phone: this.abandonedCartData.phone,
          email: this.abandonedCartData.email,
          name: this.abandonedCartData.name
        }
      };

      localStorage.setItem(userDataKey, JSON.stringify(userDataObject));
      await this.sendAbandonedCartToAPI(webform, userDataObject);
    }

    async parseUpdateAndSendData(webform, userDataKey) {
      const data = JSON.parse(localStorage.getItem(userDataKey));

      if (data.contacts.email !== this.abandonedCartData.email || 
          data.contacts.phone !== this.abandonedCartData.phone || 
          data.contacts.name !== this.abandonedCartData.name || 
          !this.abandonedCartData.sent) {
        data.contacts.email = this.abandonedCartData.email;
        data.contacts.phone = this.abandonedCartData.phone;
        data.contacts.name = this.abandonedCartData.name;

        localStorage.setItem(userDataKey, JSON.stringify(data));
        await this.sendAbandonedCartToAPI(webform, data);
        this.abandonedCartData.sent = true;
      }
    }

    getOrderLines() {
      const lines = [];
      if (typeof Cart !== 'undefined' && Cart.order && Cart.order.order_lines) {
        const orderLines = Cart.order.order_lines;
        if (orderLines && orderLines.length > 0) {
          orderLines.forEach(orderLine => {
            lines.push({
              type: "Variant",
              id: orderLine.variant_id || orderLine.variantId,
              product_id: orderLine.product_id || orderLine.productId || null,
              quantity: orderLine.quantity || 1,
              price: orderLine.full_total_price || orderLine.fullTotalPrice || null
            });
          });
        }
      }
      return lines;
    }

    async sendAbandonedCartToAPI(webform, data) {
      const items = this.getOrderLines();

      // Дополнительный лог, чтобы понимать, почему заявка может не отправляться
      this.debugLog('[sendAbandonedCartToAPI] items.length:', items.length, 'contacts:', {
        hasEmail: !!(data && data.contacts && data.contacts.email),
        hasPhone: !!(data && data.contacts && data.contacts.phone)
      });

      // Раньше отправка требовала обязательно email.
      // Раз на checkout у вас заполняются все данные, но заявка не уходит,
      // допускаем отправку, если есть ИЛИ email, ИЛИ телефон.
      if (items.length > 0 && data && data.contacts && (data.contacts.email || data.contacts.phone)) {
        const clientData = { ...data.contacts };
        const yaClientId = this.getYandexClientId();
        if (yaClientId) {
          clientData.ya_client_id = yaClientId;
        }
        // В потоке брошенной корзины формы на сайте нет, поэтому honeypot не используется.
        // Явно передаём пустое значение, чтобы серверная проверка honeypot не срабатывала.
        clientData.website = '';

        this.debugLog('[sendAbandonedCartToAPI] Sending abandoned cart with contacts:', {
          email: clientData.email ? '[FILTERED]' : '',
          phone: clientData.phone
        });

        await this.sendToAPI(webform.id, clientData, items, data.id);
      } else {
        this.debugLog('[sendAbandonedCartToAPI] Conditions not met, request will NOT be sent:', {
          hasItems: items.length > 0,
          hasContacts: !!(data && data.contacts && (data.contacts.email || data.contacts.phone))
        });
      }
    }

    showForm(webform, eventData = {}) {
      this.debugLog(`[showForm] Showing form for webform ${webform.id} (${webform.kind})`, eventData);
      const html = this.generateFormHTML(webform, eventData);
      const overlay = document.createElement('div');
      overlay.className = 'webform-overlay';
      overlay.innerHTML = html;
      document.body.appendChild(overlay);

      // Обработка закрытия формы
      const closeBtn = overlay.querySelector('.webform-close');
      if (closeBtn) {
        closeBtn.addEventListener('click', () => overlay.remove());
      }
      const wrapper = overlay.querySelector('.webform-wrapper');
      overlay.addEventListener('click', (e) => {
        // Закрываем модальное окно, если клик был вне webform-wrapper
        if (e.target === overlay || (wrapper && !wrapper.contains(e.target))) {
          overlay.remove();
        }
      });

      // Применяем маску для полей телефона
      this.applyPhoneMasks(overlay);

      // Обработка submit формы
      const form = overlay.querySelector('.twc-webform-preview-form');
      if (form) {
        form.addEventListener('submit', (e) => {
          e.preventDefault();
          e.stopPropagation();
          this.handleFormSubmit(e, webform, eventData, overlay);
          return false;
        });
      }
    }

    /**
     * Применяет маску ввода для полей телефона в формате +7 (___) ___-__-__
     */
    applyPhoneMasks(container) {
      const phoneInputs = container.querySelectorAll('input[data-phone-mask]');
      phoneInputs.forEach(input => {
        // Устанавливаем начальное значение, если поле пустое
        if (!input.value) {
          input.value = '+7 (';
        }

        // Обработчик ввода
        input.addEventListener('input', (e) => {
          let value = e.target.value.replace(/\D/g, ''); // Удаляем все нецифровые символы
          
          // Если начинается не с 7 или 8, добавляем 7
          if (value.length > 0 && value[0] !== '7' && value[0] !== '8') {
            value = '7' + value;
          }
          
          // Ограничиваем до 11 цифр (7 + 10 цифр номера)
          if (value.length > 11) {
            value = value.substring(0, 11);
          }
          
          // Форматируем в маску +7 (___) ___-__-__
          let formatted = '+7';
          if (value.length > 1) {
            formatted += ' (' + value.substring(1, 4);
            if (value.length > 4) {
              formatted += ') ' + value.substring(4, 7);
              if (value.length > 7) {
                formatted += '-' + value.substring(7, 9);
                if (value.length > 9) {
                  formatted += '-' + value.substring(9, 11);
                }
              }
            } else if (value.length > 1) {
              formatted += ')';
            }
          }
          
          e.target.value = formatted;
        });

        // Обработчик удаления (backspace)
        input.addEventListener('keydown', (e) => {
          if (e.key === 'Backspace' && e.target.value.length <= 4) {
            e.preventDefault();
            e.target.value = '+7 (';
          }
        });

        // Обработчик фокуса
        input.addEventListener('focus', (e) => {
          if (e.target.value === '' || e.target.value === '+7 (') {
            e.target.value = '+7 (';
            // Устанавливаем курсор в конец
            setTimeout(() => {
              e.target.setSelectionRange(e.target.value.length, e.target.value.length);
            }, 0);
          }
        });

        // Обработчик потери фокуса - валидация
        input.addEventListener('blur', (e) => {
          const value = e.target.value.replace(/\D/g, '');
          // Если поле не заполнено полностью и не обязательное, очищаем
          if (value.length < 11 && !e.target.hasAttribute('required')) {
            e.target.value = '';
          } else if (value.length < 11 && e.target.hasAttribute('required')) {
            // Если обязательное поле не заполнено, оставляем маску
            if (e.target.value.length < 4) {
              e.target.value = '+7 (';
            }
          }
        });
      });
    }

    handleFormSubmit(e, webform, eventData, overlay) {
      const form = e.target;
      const formData = new FormData(form);

      // Honeypot-поле для защиты от ботов:
      // - имя поля: website (нейтральное, не привлекает внимание)
      // - если заполнено, считаем, что это бот и тихо отклоняем отправку без отображения ошибок
      const honeypotValue = formData.get('website');
      if (honeypotValue && honeypotValue.trim() !== '') {
        this.debugLog('[handleFormSubmit] Honeypot field \"website\" filled, likely a bot. Submission blocked.');
        return false;
      }

      const yaClientId = this.getYandexClientId();
      
      // Обрабатываем телефон: ищем все поля типа tel и используем первое заполненное
      let phoneValue = '';
      const phoneInputs = form.querySelectorAll('input[type="tel"]');
      
      // Сначала проверяем стандартное поле phone через DOM
      const standardPhoneInput = form.querySelector('input[name="phone"][type="tel"]');
      if (standardPhoneInput && standardPhoneInput.value.trim()) {
        phoneValue = standardPhoneInput.value.trim();
      } else {
        // Если phone пустое, ищем другие поля типа tel
        // Ищем напрямую по DOM элементам, чтобы получить актуальное значение (после применения маски)
        for (const phoneInput of phoneInputs) {
          const value = phoneInput.value.trim();
          if (value) {
            phoneValue = value;
            this.debugLog(`[handleFormSubmit] Found phone in field "${phoneInput.name}": ${value}`);
            break; // Используем первое найденное заполненное поле
          }
        }
        
        // Если не нашли через DOM, пробуем через formData (fallback)
        if (!phoneValue) {
          for (const [key, value] of formData.entries()) {
            const input = form.querySelector(`input[name="${key}"]`);
            if (input && input.type === 'tel' && value && value.trim()) {
              phoneValue = value.trim();
              this.debugLog(`[handleFormSubmit] Found phone via FormData in field "${key}": ${value}`);
              break;
            }
          }
        }
      }
      
      if (!phoneValue) {
        this.debugLog('[handleFormSubmit] No phone value found. Phone inputs count:', phoneInputs.length);
      }
      
      // Очищаем телефон от маски и форматируем
      if (phoneValue) {
        const originalPhoneValue = phoneValue;
        const digitsOnly = phoneValue.replace(/\D/g, '');
        if (digitsOnly.length === 11 && digitsOnly[0] === '7') {
          phoneValue = '+7' + digitsOnly.substring(1);
        } else if (digitsOnly.length === 11 && digitsOnly[0] === '8') {
          // Если номер начинается с 8, заменяем на +7
          phoneValue = '+7' + digitsOnly.substring(1);
        } else if (digitsOnly.length === 10) {
          phoneValue = '+7' + digitsOnly;
        } else if (digitsOnly.length > 0) {
          // Для других случаев оставляем как есть, но добавляем + если его нет
          phoneValue = phoneValue.trim();
          if (!phoneValue.startsWith('+')) {
            phoneValue = '+' + digitsOnly;
          }
        } else {
          phoneValue = '';
        }
        this.debugLog(`[handleFormSubmit] Phone formatted: "${originalPhoneValue}" -> "${phoneValue}"`);
      }
      
      // Обрабатываем email: ищем все поля типа email и используем первое заполненное
      let emailValue = '';
      // Сначала проверяем стандартное поле email
      let emailField = formData.get('email');
      if (emailField && emailField.trim()) {
        emailValue = emailField.trim();
      } else {
        // Если email пустое, ищем другие поля типа email
        const emailInputs = form.querySelectorAll('input[type="email"]');
        for (const input of emailInputs) {
          const value = formData.get(input.name);
          if (value && value.trim()) {
            emailValue = value.trim();
            break; // Используем первое найденное заполненное поле
          }
        }
      }
      
      const clientData = {
        name: formData.get('name') || '',
        email: emailValue,
        phone: phoneValue
      };
      
      this.debugLog('[handleFormSubmit] clientData prepared:', {
        name: clientData.name,
        email: clientData.email ? '[FILTERED]' : '',
        phone: clientData.phone
      });

      // Передаём honeypot-поле на сервер (для дополнительной серверной проверки).
      // Для нормальных пользователей поле всегда пустое.
      clientData.website = honeypotValue || '';

      if (yaClientId) {
        clientData.ya_client_id = yaClientId;
      }

      // Собираем все пользовательские поля (кроме служебных)
      const customFields = {};
      const excludedFields = ['name', 'email', 'phone', 'website']; // служебные поля
      
      // Исключаем поле email из customFields, если оно было использовано для clientData.email
      if (emailValue && emailValue.trim()) {
        // Находим, какое поле было использовано для email
        for (const [key, value] of formData.entries()) {
          const input = form.querySelector(`input[name="${key}"]`);
          if (input && input.type === 'email' && value && value.trim() === emailValue) {
            excludedFields.push(key); // Исключаем это поле из customFields
            break;
          }
        }
      }
      
      // Исключаем поле телефона из customFields, если оно было использовано для clientData.phone
      if (phoneValue && phoneValue.trim()) {
        // Находим, какое поле было использовано для phone
        const phoneDigitsOnly = phoneValue.replace(/\D/g, '');
        for (const [key, value] of formData.entries()) {
          const input = form.querySelector(`input[name="${key}"]`);
          if (input && input.type === 'tel' && value && value.trim()) {
            const digitsOnly = value.replace(/\D/g, '');
            // Сравниваем номера: учитываем, что номер может начинаться с 7 или 8
            const normalizedDigits = digitsOnly.length === 11 && digitsOnly[0] === '8' 
              ? '7' + digitsOnly.substring(1) 
              : digitsOnly;
            const normalizedPhoneDigits = phoneDigitsOnly.length === 11 && phoneDigitsOnly[0] === '8'
              ? '7' + phoneDigitsOnly.substring(1)
              : phoneDigitsOnly;
            
            // Сравниваем последние 10 цифр (без кода страны)
            const last10Digits = normalizedDigits.length >= 10 ? normalizedDigits.slice(-10) : normalizedDigits;
            const last10PhoneDigits = normalizedPhoneDigits.length >= 10 ? normalizedPhoneDigits.slice(-10) : normalizedPhoneDigits;
            
            if (normalizedDigits === normalizedPhoneDigits || last10Digits === last10PhoneDigits) {
              excludedFields.push(key); // Исключаем это поле из customFields
              break;
            }
          }
        }
      }

      for (const [key, value] of formData.entries()) {
        if (!excludedFields.includes(key) && value && value.trim() !== '') {
          // Если это поле телефона (type="tel"), очищаем от маски перед сохранением
          const input = form.querySelector(`input[name="${key}"]`);
          if (input && input.type === 'tel') {
            // Оставляем только цифры и добавляем +7 если нужно
            let cleanValue = value.replace(/\D/g, '');
            if (cleanValue.length === 11 && cleanValue[0] === '7') {
              customFields[key] = '+7' + cleanValue.substring(1);
            } else if (cleanValue.length === 10) {
              customFields[key] = '+7' + cleanValue;
            } else if (cleanValue.length === 11 && cleanValue[0] === '8') {
              // Если номер начинается с 8, заменяем на +7
              customFields[key] = '+7' + cleanValue.substring(1);
            } else {
              customFields[key] = cleanValue ? '+' + cleanValue : value.trim();
            }
          } else {
            customFields[key] = value.trim();
          }
        }
      }

      // Валидация
      const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      // Паттерн для телефона: +7 (___) ___-__-__ или +7 (XXX) XXX-XX-XX где X - цифра
      const phonePattern = /^\+7\s?\(\d{3}\)\s?\d{3}-\d{2}-\d{2}$/;
      // Альтернативный паттерн для телефонов без маски (старые формы)
      const phonePatternSimple = /^\+?[1-9]\d{10,11}$/;

      // Находим общее поле для ошибок
      const errorMessage = overlay.querySelector('.webform-error-message');

      // Находим поля email и phone по их name атрибутам и типу
      const emailInput = form.querySelector('input[name="email"]') || form.querySelector('input[type="email"]');
      const phoneInput = form.querySelector('input[name="phone"]');
      // Также находим все поля типа email (phoneInputs уже объявлен выше)
      const emailInputs = form.querySelectorAll('input[type="email"]');

      // Очищаем предыдущие ошибки
      if (errorMessage) {
        errorMessage.textContent = "";
        errorMessage.style.display = 'none';
      }

      // Валидация email (проверяем все поля типа email)
      let emailValidationError = false;
      emailInputs.forEach(emailInput => {
        const isRequired = emailInput.hasAttribute('required');
        const emailFieldValue = emailInput.value.trim();
        
        // Проверка обязательности
        if (isRequired && !emailFieldValue) {
          if (errorMessage && !emailValidationError) {
            errorMessage.textContent = `Поле "${emailInput.placeholder || emailInput.name}" обязательно для заполнения`;
            errorMessage.style.display = 'block';
          }
          emailInput.style.borderColor = 'red';
          emailValidationError = true;
          return;
        }
        
        // Проверка формата (только если поле заполнено)
        if (emailFieldValue && !emailPattern.test(emailFieldValue)) {
          if (errorMessage && !emailValidationError) {
            errorMessage.textContent = `Некорректный формат адреса электронной почты`;
            errorMessage.style.display = 'block';
          }
          emailInput.style.borderColor = 'red';
          emailValidationError = true;
          return;
        } else {
          // Убираем красную рамку, если валидация прошла
          emailInput.style.borderColor = '';
        }
      });
      
      if (emailValidationError) {
        return false;
      }

      // Валидация phone (проверяем все поля типа tel)
      let phoneValidationError = false;
      phoneInputs.forEach(phoneInput => {
        const isRequired = phoneInput.hasAttribute('required');
        const phoneValue = phoneInput.value.trim();
        const phoneName = phoneInput.name;
        
        // Проверка обязательности
        if (isRequired && !phoneValue) {
          if (errorMessage && !phoneValidationError) {
            errorMessage.textContent = `Поле "${phoneInput.placeholder || phoneName}" обязательно для заполнения`;
            errorMessage.style.display = 'block';
          }
          phoneInput.style.borderColor = 'red';
          phoneValidationError = true;
          return;
        }
        
        // Проверка формата (только если поле заполнено)
        if (phoneValue) {
          // Проверяем формат с маской +7 (___) ___-__-__
          const digitsOnly = phoneValue.replace(/\D/g, '');
          const isValidFormat = phonePattern.test(phoneValue) || phonePatternSimple.test(digitsOnly);
          const isValidLength = digitsOnly.length === 11 && digitsOnly[0] === '7';
          
          if (!isValidFormat && !isValidLength) {
            if (errorMessage && !phoneValidationError) {
              errorMessage.textContent = `Некорректный формат телефона. Ожидается формат: +7 (___) ___-__-__`;
              errorMessage.style.display = 'block';
            }
            phoneInput.style.borderColor = 'red';
            phoneValidationError = true;
            return;
          } else {
            // Убираем красную рамку, если валидация прошла
            phoneInput.style.borderColor = '';
          }
        }
      });
      
      if (phoneValidationError) {
        return false;
      }

      // Формирование items
      let items = [];

      if (webform.kind === 'abandoned_cart') {
        // Для сценария "Брошенная корзина" всегда берём состав корзины из getOrderLines(),
        // как в тихом сценарии на new_order.
        items = this.getOrderLines();
      } else if (eventData.variantId) {
        // Для остальных сценариев используем variantId из eventData (например, preorder / купить в 1 клик).
        items.push({
          type: "Variant",
          id: eventData.variantId,
          product_id: eventData.productId || null,
          quantity: eventData.quantity || 1,
          price: eventData.price || null
        });
      }

      // Генерируем number для всех типов форм
      const number = this.createUniqueId();

      // Отправка на API
      this.sendToAPI(webform.id, clientData, items, number, customFields).then(() => {
        const successMessage = overlay.querySelector('.webform-success-message');
        if (successMessage) {
          successMessage.style.display = 'block';
          form.reset();
          if (overlay.classList.contains('webform-overlay')) {
            setTimeout(() => overlay.remove(), 2000);
          } else {
            setTimeout(() => { successMessage.style.display = 'none'; }, 5000);
          }
        }
      }).catch(error => {
        console.error("WebformManager: Error sending form data", error);
      });
    }

    generateFormHTML(webform, eventData = {}, options = {}) {
      const inline = options.inline === true;
      const settings = webform.settings || {};
      const fields = webform.fields || [];

      // Стили формы (значения уже содержат 'px' из schema)
      const formStyles = {
        width: '100%',
        maxWidth: settings.width || '530px',
        fontSize: settings.font_size || '14px',
        padding: `${settings.padding_y || '12px'} ${settings.padding_x || '12px'}`,
        color: settings.font_color || '#000000',
        borderColor: settings.border_color || '#000000',
        borderWidth: settings.border_width || '0px',
        borderRadius: settings.border_radius || '8px',
        backgroundColor: settings.background_color || '#ffffff',
        boxShadow: settings.box_shadow_offset_x || settings.box_shadow_offset_y || settings.box_shadow_blur
          ? `${settings.box_shadow_offset_x || '0px'} ${settings.box_shadow_offset_y || '2px'} ${settings.box_shadow_blur || '4px'} ${settings.box_shadow_spread || '0px'} ${settings.box_shadow_color || 'rgba(0, 0, 0, 0.12)'}`
          : 'none'
      };

      // Разделяем поля по позициям изображений
      const imageFields = fields.filter(f => f.type === 'image');
      const behindImages = imageFields.filter(f => (f.settings || {}).image_position === 'behind');
      const topImages = imageFields.filter(f => (f.settings || {}).image_position === 'top');
      const leftImages = imageFields.filter(f => (f.settings || {}).image_position === 'left');
      const rightImages = imageFields.filter(f => (f.settings || {}).image_position === 'right');
      const bottomImages = imageFields.filter(f => (f.settings || {}).image_position === 'bottom');
      const inlineImages = imageFields.filter(f => !f.settings || !f.settings.image_position || f.settings.image_position === 'none');
      
      // Обычные поля (не image или image с позицией none)
      const regularFields = fields.filter(f => f.type !== 'image' || !f.settings || !f.settings.image_position || f.settings.image_position === 'none');

      // Генерируем HTML для изображений сверху
      let topImagesHTML = '';
      topImages.forEach(field => {
        const fieldSettings = field.settings || {};
        const imageWidth = fieldSettings.image_width_percent || 100;
        const imageUrl = field.image_url || '#';
        const objectFit = fieldSettings.image_object_fit || 'cover';
        topImagesHTML += `
          <div class="twc-webform-preview-image" style="width: ${imageWidth}%; display: block; margin: 0 auto; width: 100%; height: 100%;">
            <img src="${imageUrl}" alt="${field.label || ''}" style="width: 100%; height: 100%; object-fit: ${objectFit}; object-position: 50% 50%; display: block;" />
          </div>
        `;
      });

      // Генерируем HTML для изображений слева
      let leftImagesHTML = '';
      leftImages.forEach(field => {
        const fieldSettings = field.settings || {};
        const imageUrl = field.image_url || '#';
        const objectFit = fieldSettings.image_object_fit || 'cover';
        leftImagesHTML += `
          <img src="${imageUrl}" alt="${field.label || ''}" style="width: 100%; height: 100%; object-fit: ${objectFit}; object-position: 50% 50%; display: block;" />
        `;
      });

      // Генерируем HTML для изображений справа
      let rightImagesHTML = '';
      rightImages.forEach(field => {
        const fieldSettings = field.settings || {};
        const imageUrl = field.image_url || '#';
        const objectFit = fieldSettings.image_object_fit || 'cover';
        rightImagesHTML += `
          <img src="${imageUrl}" alt="${field.label || ''}" style="width: 100%; height: 100%; object-fit: ${objectFit}; object-position: 50% 50%; display: block;" />
        `;
      });

      // Генерируем HTML для изображений снизу
      let bottomImagesHTML = '';
      bottomImages.forEach(field => {
        const fieldSettings = field.settings || {};
        const imageWidth = fieldSettings.image_width_percent || 100;
        const imageUrl = field.image_url || '#';
        const objectFit = fieldSettings.image_object_fit || 'cover';
        bottomImagesHTML += `
          <div class="twc-webform-preview-image" style="width: ${imageWidth}%; display: block; margin: 0 auto; width: 100%; height: 100%;">
            <img src="${imageUrl}" alt="${field.label || ''}" style="width: 100%; height: 100%; object-fit: ${objectFit}; object-position: 50% 50%; display: block;" />
          </div>
        `;
      });

      // Генерируем HTML для фоновых изображений
      let behindImagesHTML = '';
      behindImages.forEach(field => {
        const fieldSettings = field.settings || {};
        const imageUrl = field.image_url || '#';
        const objectFit = fieldSettings.image_object_fit || 'cover';
        behindImagesHTML += `
          <img src="${imageUrl}" alt="${field.label || ''}" style="
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            object-fit: ${objectFit};
            object-position: 50% 50%;
            z-index: 0;
          " />
        `;
      });

      // Генерируем HTML для обычных полей (включая inline изображения)
      let fieldsHTML = '';
      regularFields.forEach(field => {
        const fieldSettings = field.settings || {};
        
        // Стили полей (значения уже содержат 'px' из schema)
        const fieldStyles = {
          width: '100%',
          maxWidth: fieldSettings.width || '100%',
          margin: `${fieldSettings.margin_y || '0px'} ${fieldSettings.margin_x || '0px'}`,
          fontSize: fieldSettings.font_size || '14px',
          padding: `${fieldSettings.padding_y || '12px'} ${fieldSettings.padding_x || '12px'}`,
          color: fieldSettings.font_color || '#000000',
          backgroundColor: fieldSettings.background_color || '#ffffff',
          borderColor: fieldSettings.border_color || '#000000',
          borderWidth: fieldSettings.border_width || '0px',
          borderRadius: fieldSettings.border_radius || '8px',
          boxShadow: fieldSettings.box_shadow_offset_x || fieldSettings.box_shadow_offset_y || fieldSettings.box_shadow_blur
            ? `${fieldSettings.box_shadow_offset_x || '0px'} ${fieldSettings.box_shadow_offset_y || '0px'} ${fieldSettings.box_shadow_blur || '0px'} ${fieldSettings.box_shadow_spread || '0px'} ${fieldSettings.box_shadow_color || 'rgba(0, 0, 0, 0.12)'}`
            : 'none'
        };

        const styleString = Object.entries(fieldStyles).map(([key, value]) => {
          const cssKey = key.replace(/([A-Z])/g, '-$1').toLowerCase();
          return `${cssKey}: ${value}`;
        }).join('; ');

        // Обработка разных типов полей
        if (field.type === 'button') {
          const buttonStyle = `${styleString}; background: ${fieldSettings.background_color || '#ffffff'}`;
          fieldsHTML += `
            <button type="submit" name="${field.name}" style="${buttonStyle}">
              ${field.label}
            </button>
          `;
        } else if (field.type === 'text') {
          // Для типа 'text' используем input type="text"
          const placeholder = fieldSettings.placeholder || field.label;
          const requiredAttr = field.required ? 'required' : '';
          fieldsHTML += `
            <input type="text" name="${field.name}" placeholder="${placeholder}" ${requiredAttr} style="${styleString}" />
          `;
        } else if (field.type === 'number') {
          // Для типа 'number' используем input type="number"
          const placeholder = fieldSettings.placeholder || field.label;
          const requiredAttr = field.required ? 'required' : '';
          fieldsHTML += `
            <input type="number" name="${field.name}" placeholder="${placeholder}" ${requiredAttr} style="${styleString}" />
          `;
        } else if (field.type === 'phone') {
          // Для типа 'phone' используем input type="tel" с маской ввода
          const placeholder = fieldSettings.placeholder || field.label || '+7 (___) ___-__-__';
          const requiredAttr = field.required ? 'required' : '';
          const fieldId = `phone_${field.name}_${Date.now()}`;
          fieldsHTML += `
            <input type="tel" id="${fieldId}" name="${field.name}" placeholder="${placeholder}" ${requiredAttr} style="${styleString}" data-phone-mask />
          `;
        } else if (field.type === 'paragraph') {
          // Для типа 'paragraph' используем div, а не input
          fieldsHTML += `
            <div class="paragraph-field" style="${styleString}">${field.label}</div>
          `;
        } else if (field.type === 'checkbox') {
          // Для типа 'checkbox' используем input checkbox с label
          const requiredAttr = field.required ? 'required' : '';
          fieldsHTML += `
            <label style="${styleString}; display: flex; align-items: center; gap: 8px; cursor: pointer;">
              <input type="checkbox" name="${field.name}" value="1" ${requiredAttr} style="margin: 0;">
              <span>${field.label}</span>
            </label>
          `;
        } else if (field.type === 'select') {
          // Для типа 'select' используем select с опциями
          const requiredAttr = field.required ? 'required' : '';
          // Для required полей не используем disabled, чтобы форма могла быть отправлена
          const placeholderOption = field.required 
            ? `<option value="" selected>${field.label}</option>`
            : `<option value="" disabled selected>${field.label}</option>`;
          let optionsHTML = placeholderOption;
          if (field.options && Array.isArray(field.options)) {
            field.options.forEach(option => {
              optionsHTML += `<option value="${option}">${option}</option>`;
            });
          }
          fieldsHTML += `
            <select name="${field.name}" ${requiredAttr} style="${styleString}">
              ${optionsHTML}
            </select>
          `;
        } else if (field.type === 'textarea') {
          const placeholder = fieldSettings.placeholder || field.label;
          const requiredAttr = field.required ? 'required' : '';
          fieldsHTML += `
            <textarea name="${field.name}" placeholder="${placeholder}" ${requiredAttr} rows="4" style="${styleString}"></textarea>
          `;
        } else if (field.type === 'email') {
          const placeholder = fieldSettings.placeholder || field.label;
          const requiredAttr = field.required ? 'required' : '';
          fieldsHTML += `
            <input type="email" name="${field.name}" placeholder="${placeholder}" ${requiredAttr} style="${styleString}" />
          `;
        } else if (field.type === 'image') {
          // Inline изображения (позиция none или не указана)
          const imageWidth = fieldSettings.image_width_percent || 100;
          const imageUrl = field.image_url || '#';
          const objectFit = fieldSettings.image_object_fit || 'cover';
          fieldsHTML += `
            <div class="twc-webform-preview-image" style="width: ${imageWidth}%; max-width: 100%; display: block; margin: ${fieldSettings.margin_y || '0px'} ${fieldSettings.margin_x || '0px'}; width: 100%; height: 100%;">
              <img src="${imageUrl}" alt="${field.label || ''}" style="width: 100%; height: 100%; object-fit: ${objectFit}; object-position: 50% 50%; display: block;" />
            </div>
          `;
        } else {
          // Fallback для неизвестных типов
          const placeholder = fieldSettings.placeholder || field.label;
          const requiredAttr = field.required ? 'required' : '';
          fieldsHTML += `
            <input type="text" name="${field.name}" placeholder="${placeholder}" ${requiredAttr} style="${styleString}" />
          `;
        }
      });

      // Определяем grid стили для webform-container
      const hasLeft = leftImages.length > 0;
      const hasRight = rightImages.length > 0;
      let gridStyle = '';
      
      if (hasLeft || hasRight) {
        const leftWidth = hasLeft ? (leftImages[0].settings || {}).image_width_percent || 50 : 0;
        const rightWidth = hasRight ? (rightImages[0].settings || {}).image_width_percent || 50 : 0;
        const formWidth = 100 - leftWidth - rightWidth;
        
        let gridTemplate = '';
        if (hasLeft && hasRight) {
          gridTemplate = `${leftWidth}% ${formWidth}% ${rightWidth}%`;
        } else if (hasLeft) {
          gridTemplate = `${leftWidth}% ${formWidth}%`;
        } else {
          gridTemplate = `${formWidth}% ${rightWidth}%`;
        }
        
        gridStyle = `display: grid; grid-template-columns: ${gridTemplate}; gap: 16px; align-items: start;`;
      }

      // Honeypot-поле:
      // - скрыто с помощью position: absolute; left: -9999px (не display: none, чтобы боты его видели)
      // - имеет tabindex="-1", autocomplete="off", aria-hidden="true", чтобы не мешать пользователю
      const honeypotField = `
        <input
          type="text"
          name="website"
          tabindex="-1"
          autocomplete="off"
          aria-hidden="true"
          style="
            position: absolute;
            left: -9999px;
            width: 1px;
            height: 1px;
            opacity: 0;
            pointer-events: none;
          "
        />
      `;

      const closeButtonHTML = inline ? '' : `
              <button class="webform-close" style="
                position: absolute;
                top: 10px;
                right: 10px;
                background: none;
                border: none;
                font-size: 24px;
                cursor: pointer;
                z-index: 2;
              ">&times;</button>
              `;

      const previewDiv = `
            <div class="twc-webform-preview" style="
              position: relative;
              overflow: hidden;
              ${gridStyle}
              background-color: ${settings.background_color || '#ffffff'};
              ${Object.entries(formStyles).map(([key, value]) => {
                const cssKey = key.replace(/([A-Z])/g, '-$1').toLowerCase();
                if (key === 'backgroundColor') return '';
                return `${cssKey}: ${value}`;
              }).filter(s => s).join('; ')}
            ">
              ${behindImagesHTML}
              ${closeButtonHTML}
              ${hasLeft ? `<div class="twc-webform-preview-image" style="position: relative; z-index: 1; width: 100%; height: 100%;">${leftImagesHTML}</div>` : ''}
              <form class="twc-webform-preview-form" style="position: relative;" onsubmit="return false;">
                ${fieldsHTML}
                ${honeypotField}
                <div class="webform-error-message" style="display: none; color: red; font-size: 14px; margin-top: 10px;"></div>
                <div class="webform-success-message" style="display: none; color: green; margin-top: 10px;">
                  Форма успешно отправлена!
                </div>
              </form>
              ${hasRight ? `<div class="twc-webform-preview-image" style="position: relative; z-index: 1; width: 100%; height: 100%;">${rightImagesHTML}</div>` : ''}
            </div>`;

      const wrapperHTML = `
          <div class="webform-wrapper${inline ? ' twc-webform-inline' : ''}">
            ${!hasLeft && !hasRight ? topImagesHTML : ''}
            ${previewDiv}
            ${!hasLeft && !hasRight ? bottomImagesHTML : ''}
          </div>`;

      if (inline) {
        return wrapperHTML;
      }

      return `
        <div class="webform-overlay-content" style="
          position: fixed;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          background: rgba(0, 0, 0, 0.5);
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          z-index: 10000;
        ">
          ${wrapperHTML}
        </div>
      `;
    }

    async sendToAPI(webformId, clientData, items, number = null, customFields = null) {
      const url = `${this.API_BASE}/accounts/${this.accountId}/incases`;
      const payload = {
        webform_id: webformId,
        client: clientData,
        items: items
      };
      if (number) {
        payload.number = number;
      }
      if (customFields && Object.keys(customFields).length > 0) {
        payload.custom_fields = customFields;
      }

      this.debugLog(`[sendToAPI] Sending request to: ${url}`, payload);

      try {
        const response = await fetch(url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(payload)
        });

        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }

        const data = await response.json();
        this.debugLog(`[sendToAPI] Success:`, data);
        return data;
      } catch (error) {
        this.debugLog(`[sendToAPI] Error:`, error);
        console.error("WebformManager: API request failed", error);
        throw error;
      }
    }
  }

  // Инициализация при загрузке DOM
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      new WebformManager();
    });
  } else {
    new WebformManager();
  }
})();

