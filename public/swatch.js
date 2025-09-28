/* swatch.js
 * Loads swatch JSON for a given account id from S3 and renders swatches
 * Usage: include this script with ?id=<account_id>
 *   <script src="https://.../scripts/swatch.js?id=3" defer></script>
 */

(function() {
  const S3_BASE = 'https://s3.twcstorage.ru/ae4cd7ee-b62e0601-19d6-483e-bbf1-416b386e5c23';

  function getAccountIdFromScript() {
    const scripts = document.getElementsByTagName('script');
    for (let i = 0; i < scripts.length; i++) {
      const src = scripts[i].getAttribute('src') || '';
      if (src.includes('swatch.js')) {
        try {
          const url = new URL(src, window.location.origin);
          const id = url.searchParams.get('id');
          if (id) return id;
        } catch (e) {
          // ignore
        }
      }
    }
    return null;
  }

  function fetchSwatchJson(accountId) {
    const jsonUrl = `${S3_BASE}/swatches/swatch_${accountId}.json`;
    return fetch(jsonUrl, { credentials: 'omit' }).then(function(res) {
      if (!res.ok) throw new Error('Failed to load swatch json');
      return res.json();
    });
  }

  function pickImage(images, source) {
    if (!Array.isArray(images) || images.length === 0) return null;
    switch (source) {
      case 'first_product_image':
        return images[0];
      case 'second_product_image':
        return images[1] || images[0];
      case 'last_product_image':
        return images[images.length - 1];
      case 'custom_image':
      default:
        return images[0];
    }
  }

  function sizeForStyle(styleToken, isMobile) {
    // Minimal mapping; extend as needed
    if (!styleToken) return isMobile ? 20 : 30;
    if (styleToken.includes('circular_small')) return isMobile ? 20 : 30;
    if (styleToken.includes('circular_medium')) return isMobile ? 24 : 36;
    if (styleToken.includes('circular_large')) return isMobile ? 28 : 44;
    // Fallback
    return isMobile ? 20 : 30;
  }

  function buildSwatchContainer(entry, useStyle, swatchImageSource) {
    const isMobile = window.matchMedia('(max-width: 640px)').matches;
    const size = sizeForStyle(useStyle, isMobile);

    const wrapper = document.createElement('div');
    wrapper.className = 'twc-swatch-container';
    wrapper.style.display = 'flex';
    wrapper.style.flexWrap = 'wrap';
    wrapper.style.gap = '6px';
    wrapper.style.alignItems = 'center';

    (entry.swatches || []).forEach(function(s) {
      const imgSrc = pickImage(s.images || [], swatchImageSource);
      if (!imgSrc) return;
      const a = document.createElement('a');
      a.href = s.link || '#';
      a.style.display = 'inline-flex';
      a.style.width = size + 'px';
      a.style.height = size + 'px';
      a.style.borderRadius = '9999px';
      a.style.overflow = 'hidden';
      a.style.border = '1px solid rgba(0,0,0,0.08)';
      a.style.alignItems = 'center';
      a.style.justifyContent = 'center';
      a.title = s.title || '';

      const img = document.createElement('img');
      img.src = imgSrc;
      img.alt = s.title || '';
      img.style.maxWidth = '100%';
      img.style.maxHeight = '100%';

      a.appendChild(img);
      wrapper.appendChild(a);
    });

    return wrapper;
  }

  function renderForCollection(data) {
    // For each entry, find product card with matching data-product-id and insert after .product-preview__area-photo
    data.forEach(function(entry) {
      var selector = `[data-product-id="${entry.product_id}"]`;
      var cards = document.querySelectorAll(selector);
      if (!cards || cards.length === 0) return;
      var useStyle = entry.collection_page_style || entry.product_page_style;
      var container = buildSwatchContainer(entry, useStyle, entry.swatch_image_source);
      cards.forEach(function(card) {
        var anchor = card.querySelector('.product-preview__area-photo');
        if (anchor) {
          // Insert a fresh clone per card
          anchor.insertAdjacentElement('afterend', container.cloneNode(true));
        }
      });
    });
  }

  function renderForProduct(data) {
    // Try to infer product id from page if present
    var pidNode = document.querySelector('[data-product-id]');
    var pid = pidNode && pidNode.getAttribute('data-product-id');
    data.forEach(function(entry) {
      if (pid && entry.product_id !== pid) return;
      var useStyle = entry.product_page_style || entry.collection_page_style;
      var container = buildSwatchContainer(entry, useStyle, entry.swatch_image_source);
      var anchor = document.querySelector('.product-preview__area-photo') || document.body;
      anchor.insertAdjacentElement('afterend', container);
    });
  }

  function init() {
    var accountId = getAccountIdFromScript();
    if (!accountId) return;
    fetchSwatchJson(accountId).then(function(data) {
      if (!Array.isArray(data)) return;
      if (window.location.pathname.includes('collection')) {
        renderForCollection(data);
      } else {
        renderForProduct(data);
      }
    }).catch(function(err) {
      // eslint-disable-next-line no-console
      console.warn('swatch.js:', err);
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();


