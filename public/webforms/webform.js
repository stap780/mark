/**
 * Webform.js - Конструктор веб-форм
 * Версия: 1.0.0
 * Описание: Скрипт для работы с веб-формами на сайте клиента
 */

(function() {
  'use strict';

  class WebformManager {
    constructor() {
      this.version = "1.0.0";
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
      if (typeof EventBus !== 'undefined' && EventBus.subscribe) {
        this.debugLog(`[handleNotify] Subscribing to empty-product:insales:site for webform ${webform.id}`);
        EventBus.subscribe("empty-product:insales:site", (data) => {
          this.debugLog(`[handleNotify] Event received:`, data);
          // Получаем productId и variantId из события или data-атрибутов
          const productId = data?.productId || document.querySelector("[data-feedback-product-id]")?.dataset?.feedbackProductId;
          const variantId = data?.variantId || document.querySelector("[data-variant-id]")?.dataset?.variantId;
          this.debugLog(`[handleNotify] ProductId: ${productId}, VariantId: ${variantId}`);
          this.showForm(webform, { productId, variantId });
        });
      } else {
        this.debugLog(`[handleNotify] EventBus not available`);
      }
    }

    handlePreorder(webform) {
      // Ищем элементы с стандартным data-атрибутом InSales для предзаказа
      const preorderTriggers = document.querySelectorAll('[data-product-card-preorder]');
      this.debugLog(`[handlePreorder] Found ${preorderTriggers.length} preorder triggers for webform ${webform.id}`);
      
      preorderTriggers.forEach(trigger => {
        trigger.addEventListener('click', (e) => {
          e.preventDefault();
          // Получаем productId и variantId из data-атрибутов элемента
          const productId = trigger.getAttribute('data-product-id') || trigger.closest('[data-product-id]')?.getAttribute('data-product-id');
          const variantId = trigger.getAttribute('data-variant-id') || trigger.closest('[data-variant-id]')?.getAttribute('data-variant-id');
          this.debugLog(`[handlePreorder] Trigger clicked - ProductId: ${productId}, VariantId: ${variantId}`);
          this.showForm(webform, { productId, variantId });
        });
      });
    }

    handleCustom(webform) {
      // Ищем элементы с data-атрибутом для кастомных форм
      const customTriggers = document.querySelectorAll(`[data-webform-id="${webform.id}"]`);
      this.debugLog(`[handleCustom] Found ${customTriggers.length} custom triggers for webform ${webform.id}`);
      customTriggers.forEach(trigger => {
        trigger.addEventListener('click', (e) => {
          e.preventDefault();
          const productId = trigger.getAttribute('data-product-id');
          const variantId = trigger.getAttribute('data-variant-id');
          this.debugLog(`[handleCustom] Trigger clicked - ProductId: ${productId}, VariantId: ${variantId}`);
          this.showForm(webform, { productId, variantId });
        });
      });
    }

    handleAbandonedCart(webform) {
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
        const send = (this.abandonedCartData.timestamp + intervalForSend) < new Date().getTime();
        if (send) {
          if (this.isRegistered()) {
            this.getRegisteredData(webform, userDataKey);
          } else {
            this.getUnregisteredData(webform, userDataKey);
          }
        }
      }, 2000);
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
        await this.sendToAPI(webform.id, data.contacts, items);
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
      const clientData = {
        name: formData.get('name') || '',
        email: formData.get('email') || '',
        phone: formData.get('phone') || ''
      };

      // Валидация
      const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      const phonePattern = /^\+?[1-9]\d{1,11}$/;

      const emailError = overlay.querySelector('.mail-error');
      const phoneError = overlay.querySelector('.phone-error');

      if (clientData.email && !emailPattern.test(clientData.email)) {
        if (emailError) emailError.textContent = "Некорректный формат адреса электронной почты";
        return false;
      } else if (emailError) {
        emailError.textContent = "";
      }

      if (clientData.phone && !phonePattern.test(clientData.phone)) {
        if (phoneError) phoneError.textContent = "Некорректный формат телефона";
        return false;
      } else if (phoneError) {
        phoneError.textContent = "";
      }

      // Формирование items
      const items = [];
      if (eventData.variantId) {
        items.push({
          type: "Variant",
          id: eventData.variantId,
          quantity: eventData.quantity || 1,
          price: eventData.price || null
        });
      }

      // Отправка на API
      this.sendToAPI(webform.id, clientData, items).then(() => {
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

      // Стили формы
      const formStyles = {
        width: settings.width || '530px',
        fontSize: settings.font_size || '16px',
        padding: `${settings.padding_y || '12px'} ${settings.padding_x || '12px'}`,
        color: settings.font_color || '#000000',
        borderColor: settings.border_color || '#000000',
        borderWidth: settings.border_width || '0px',
        borderRadius: settings.border_radius || '8px',
        backgroundColor: settings.background_color || '#ffffff',
        boxShadow: settings.box_shadow_offset_x || settings.box_shadow_offset_y || settings.box_shadow_blur
          ? `${settings.box_shadow_offset_x || '0px'} ${settings.box_shadow_offset_y || '2px'} ${settings.box_shadow_blur || '8px'} ${settings.box_shadow_spread || '0px'} ${settings.box_shadow_color || '#000000'}`
          : 'none'
      };

      let fieldsHTML = '';
      fields.forEach(field => {
        const fieldSettings = field.settings || {};
        const fieldStyles = {
          width: fieldSettings.width || '100%',
          margin: `${fieldSettings.margin_y || '0px'} ${fieldSettings.margin_x || '0px'}`,
          fontSize: fieldSettings.font_size || '16px',
          padding: `${fieldSettings.padding_y || '12px'} ${fieldSettings.padding_x || '12px'}`,
          color: fieldSettings.font_color || '#000000',
          borderColor: fieldSettings.border_color || '#000000',
          borderWidth: fieldSettings.border_width || '0px',
          borderRadius: fieldSettings.border_radius || '8px',
          backgroundColor: fieldSettings.background_color || '#ffffff',
          boxShadow: fieldSettings.box_shadow_offset_x || fieldSettings.box_shadow_offset_y || fieldSettings.box_shadow_blur
            ? `${fieldSettings.box_shadow_offset_x || '0px'} ${fieldSettings.box_shadow_offset_y || '0px'} ${fieldSettings.box_shadow_blur || '0px'} ${fieldSettings.box_shadow_spread || '0px'} ${fieldSettings.box_shadow_color || '#000000'}`
            : 'none'
        };

        const styleString = Object.entries(fieldStyles).map(([key, value]) => {
          const cssKey = key.replace(/([A-Z])/g, '-$1').toLowerCase();
          return `${cssKey}: ${value}`;
        }).join('; ');

        if (field.type === 'button') {
          fieldsHTML += `
            <button type="submit" name="${field.name}" style="${styleString}">
              ${field.label}
            </button>
          `;
        } else {
          const inputType = field.type === 'email' ? 'email' : field.type === 'phone' ? 'tel' : 'text';
          const requiredAttr = field.required ? 'required' : '';
          fieldsHTML += `
            <div class="webform-field">
              <label>${field.label}</label>
              <input type="${inputType}" name="${field.name}" ${requiredAttr} style="${styleString}" />
              <div class="${field.name}-error" style="color: red; font-size: 12px;"></div>
            </div>
          `;
        }
      });

      return `
        <div class="webform-overlay-content" style="
          position: fixed;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          background: rgba(0, 0, 0, 0.5);
          display: flex;
          align-items: center;
          justify-content: center;
          z-index: 10000;
        ">
          <div class="webform-container" style="
            position: relative;
            ${Object.entries(formStyles).map(([key, value]) => {
              const cssKey = key.replace(/([A-Z])/g, '-$1').toLowerCase();
              return `${cssKey}: ${value}`;
            }).join('; ')}
          ">
            <button class="webform-close" style="
              position: absolute;
              top: 10px;
              right: 10px;
              background: none;
              border: none;
              font-size: 24px;
              cursor: pointer;
            ">&times;</button>
            <form class="webform-form">
              ${fieldsHTML}
              <div class="webform-success-message" style="display: none; color: green; margin-top: 10px;">
                Форма успешно отправлена!
              </div>
            </form>
          </div>
        </div>
      `;
    }

    async sendToAPI(webformId, clientData, items) {
      const url = `${this.API_BASE}/accounts/${this.accountId}/incases`;
      const payload = {
        webform_id: webformId,
        client: clientData,
        items: items
      };

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

