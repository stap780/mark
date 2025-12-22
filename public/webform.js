/**
 * Webform.js - Конструктор веб-форм
 * Версия: 1.1.9
 * Описание: Скрипт для работы с веб-формами на сайте клиента
 */

(function() {
  'use strict';

  class WebformManager {
    constructor() {
      this.version = "1.1.9";
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
      
      // Существующий механизм через клики (для совместимости)
      if (triggerType === 'event' || triggerType === 'manual') {
        const preorderTriggers = document.querySelectorAll('[data-product-card-preorder]');
        this.debugLog(`[handlePreorder] Found ${preorderTriggers.length} preorder triggers for webform ${webform.id}`);
        
        preorderTriggers.forEach(trigger => {
          trigger.addEventListener('click', (e) => {
            e.preventDefault();
            const productId = trigger.getAttribute('data-product-id') || trigger.closest('[data-product-id]')?.getAttribute('data-product-id');
            const variantId = trigger.getAttribute('data-variant-id') || trigger.closest('[data-variant-id]')?.getAttribute('data-variant-id');
            this.debugLog(`[handlePreorder] Trigger clicked - ProductId: ${productId}, VariantId: ${variantId}`);
            this.showForm(webform, { productId, variantId });
          });
        });
        
        // Ручной показ через data-twc-webform-id (новый функционал)
        if (triggerType === 'manual') {
          this.setupManualTrigger(webform);
        }
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
      
      // Существующий механизм через отслеживание активности (для совместимости)
      if (triggerType === 'activity') {
        const intervalForSend = 4000;
        const userDataKey = "userData";

        // Отслеживание активности
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

        // Сбор данных из полей формы
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
      } else {
        // Автоматические триггеры (exit_intent, time_on_page, scroll_depth) или manual
        this.handleWebformWithTrigger(webform, 'abandoned_cart');
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
    
    setupManualTrigger(webform) {
      const manualTriggers = document.querySelectorAll(`[data-twc-webform-id="${webform.id}"]`);
      this.debugLog(`[setupManualTrigger] Found ${manualTriggers.length} manual triggers for webform ${webform.id}`);
      manualTriggers.forEach(trigger => {
        trigger.addEventListener('click', (e) => {
          e.preventDefault();
          const productId = trigger.getAttribute('data-product-id');
          const variantId = trigger.getAttribute('data-variant-id');
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
    
    isFormShown(webform, trigger) {
      const cookieName = trigger.cookie_name || `webform_${webform.id}_shown`;
      
      // Проверка sessionStorage (для show_once_per_session)
      if (trigger.show_once_per_session && sessionStorage.getItem(cookieName)) {
        return true;
      }
      
      // Проверка cookie (для show_frequency_days)
      const cookieValue = this.getCookie(cookieName);
      if (cookieValue) {
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
      
      // Сохранение в cookie (для show_frequency_days)
      if (trigger.show_frequency_days) {
        const expires = new Date(Date.now() + trigger.show_frequency_days * 24 * 60 * 60 * 1000);
        document.cookie = `${cookieName}=1; expires=${expires.toUTCString()}; path=/`;
      } else if (!trigger.show_once_per_session) {
        // Если нет ограничений, сохраняем в cookie без срока
        document.cookie = `${cookieName}=1; path=/`;
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
      if (items.length > 0 && data.contacts.email && data.contacts.email.length > 0) {
        const clientData = { ...data.contacts };
        const yaClientId = this.getYandexClientId();
        if (yaClientId) {
          clientData.ya_client_id = yaClientId;
        }
        // В потоке брошенной корзины формы на сайте нет, поэтому honeypot не используется.
        // Явно передаём пустое значение, чтобы серверная проверка honeypot не срабатывала.
        clientData.website = '';
        await this.sendToAPI(webform.id, clientData, items, data.id);
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
      overlay.addEventListener('click', (e) => {
        if (e.target === overlay) {
          overlay.remove();
        }
      });

      // Обработка submit формы
      const form = overlay.querySelector('.webform-form');
      if (form) {
        form.addEventListener('submit', (e) => {
          e.preventDefault();
          this.handleFormSubmit(e, webform, eventData, overlay);
        });
      }
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
      const clientData = {
        name: formData.get('name') || '',
        email: formData.get('email') || '',
        phone: formData.get('phone') || ''
      };

      // Передаём honeypot-поле на сервер (для дополнительной серверной проверки).
      // Для нормальных пользователей поле всегда пустое.
      clientData.website = honeypotValue || '';

      if (yaClientId) {
        clientData.ya_client_id = yaClientId;
      }

      // Валидация
      const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      const phonePattern = /^\+?[1-9]\d{1,11}$/;

      // Находим общее поле для ошибок
      const errorMessage = overlay.querySelector('.webform-error-message');

      // Находим поля email и phone по их name атрибутам
      const emailInput = form.querySelector('input[name="email"]');
      const phoneInput = form.querySelector('input[name="phone"]');

      // Очищаем предыдущие ошибки
      if (errorMessage) {
        errorMessage.textContent = "";
        errorMessage.style.display = 'none';
      }

      // Валидация email
      if (emailInput) {
        const isRequired = emailInput.hasAttribute('required');
        const emailValue = clientData.email.trim();
        
        // Проверка обязательности
        if (isRequired && !emailValue) {
          if (errorMessage) {
            errorMessage.textContent = "Поле email обязательно для заполнения";
            errorMessage.style.display = 'block';
          }
          return false;
        }
        
        // Проверка формата (только если поле заполнено)
        if (emailValue && !emailPattern.test(emailValue)) {
          if (errorMessage) {
            errorMessage.textContent = "Некорректный формат адреса электронной почты";
            errorMessage.style.display = 'block';
          }
          return false;
        }
      }

      // Валидация phone
      if (phoneInput) {
        const isRequired = phoneInput.hasAttribute('required');
        const phoneValue = clientData.phone.trim();
        
        // Проверка обязательности
        if (isRequired && !phoneValue) {
          if (errorMessage) {
            errorMessage.textContent = "Поле телефона обязательно для заполнения";
            errorMessage.style.display = 'block';
          }
          return false;
        }
        
        // Проверка формата (только если поле заполнено)
        if (phoneValue && !phonePattern.test(phoneValue)) {
          if (errorMessage) {
            errorMessage.textContent = "Некорректный формат телефона";
            errorMessage.style.display = 'block';
          }
          return false;
        }
      }

      // Формирование items
      const items = [];
      if (eventData.variantId) {
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
      this.sendToAPI(webform.id, clientData, items, number).then(() => {
        const successMessage = overlay.querySelector('.webform-success-message');
        if (successMessage) {
          successMessage.style.display = 'block';
          form.reset();
          setTimeout(() => overlay.remove(), 2000);
        }
      }).catch(error => {
        console.error("WebformManager: Error sending form data", error);
      });
    }

    generateFormHTML(webform, eventData = {}) {
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
          // Для типа 'phone' используем input type="tel"
          const placeholder = fieldSettings.placeholder || field.label;
          const requiredAttr = field.required ? 'required' : '';
          fieldsHTML += `
            <input type="tel" name="${field.name}" placeholder="${placeholder}" ${requiredAttr} style="${styleString}" />
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
          <div class="webform-wrapper">
            ${!hasLeft && !hasRight ? topImagesHTML : ''}
            
            <div class="twc-webform-preview" style="
              position: relative;
              overflow: hidden;
              ${gridStyle}
              background-color: ${settings.background_color || '#ffffff'};
              ${Object.entries(formStyles).map(([key, value]) => {
                const cssKey = key.replace(/([A-Z])/g, '-$1').toLowerCase();
                // Пропускаем backgroundColor, так как он уже добавлен выше
                if (key === 'backgroundColor') return '';
                return `${cssKey}: ${value}`;
              }).filter(s => s).join('; ')}
            ">
              ${behindImagesHTML}
              
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
              
              ${hasLeft ? `<div class="twc-webform-preview-image" style="position: relative; z-index: 1; width: 100%; height: 100%;">${leftImagesHTML}</div>` : ''}
              
              <form class="twc-webform-preview-form" style="position: relative;">
                ${fieldsHTML}
                ${honeypotField}
                <div class="webform-error-message" style="display: none; color: red; font-size: 14px; margin-top: 10px;"></div>
                <div class="webform-success-message" style="display: none; color: green; margin-top: 10px;">
                  Форма успешно отправлена!
                </div>
              </form>
              
              ${hasRight ? `<div class="twc-webform-preview-image" style="position: relative; z-index: 1; width: 100%; height: 100%;">${rightImagesHTML}</div>` : ''}
            </div>
            
            ${!hasLeft && !hasRight ? bottomImagesHTML : ''}
          </div>
        </div>
      `;
    }

    async sendToAPI(webformId, clientData, items, number = null) {
      const url = `${this.API_BASE}/accounts/${this.accountId}/incases`;
      const payload = {
        webform_id: webformId,
        client: clientData,
        items: items
      };
      if (number) {
        payload.number = number;
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

