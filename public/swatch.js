/* swatch.js
 * Loads swatch JSON for a given account id from S3 and renders swatches
 * Usage: include this script with ?id=<account_id>
 *   <script src="https://.../scripts/swatch.js?id=3" defer></script>
 * Added debug logging (toggle via ?debug=1 in the script URL)
 */

(function() {
  const S3_BASE = 'https://s3.twcstorage.ru/ae4cd7ee-b62e0601-19d6-483e-bbf1-416b386e5c23';
  let DEBUG = false;

  function debugLog(){
    if (!DEBUG) return;
    try { console.log('[swatch]', ...arguments); } catch(e) { /* noop */ }
  }

  function getAccountIdFromScript() {
    const scripts = document.getElementsByTagName('script');
    for (let i = 0; i < scripts.length; i++) {
      const src = scripts[i].getAttribute('src') || '';
      if (src.includes('swatch.js')) {
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

  function fetchSwatchJson(accountId) {
    const jsonUrl = `${S3_BASE}/swatches/swatch_${accountId}.json`;
    debugLog('fetchSwatchJson url=', jsonUrl);
    return fetch(jsonUrl, { credentials: 'omit' }).then(function(res) {
      if (!res.ok) throw new Error('Failed to load swatch json');
      return res.json();
    });
  }

  function pickImage(images, source) {
    if (!Array.isArray(images) || images.length === 0) { debugLog('pickImage no images'); return null; }
    var chosen = null;
    switch (source) {
      case 'first_product_image':
        chosen = images[0];
        break;
      case 'second_product_image':
        chosen = images[1] || images[0];
        break;
      case 'last_product_image':
        chosen = images[images.length - 1];
        break;
      case 'custom_image':
      default:
        chosen = images[0];
        break;
    }
    debugLog('pickImage source=', source, 'count=', images.length, 'chosen=', chosen);
    return chosen;
  }

  function sizeForStyleCircular(styleToken, isMobile) {
    // Minimal mapping; extend as needed
    if (!styleToken) return isMobile ? 20 : 30;
    if (styleToken.includes('circular_small')) return isMobile ? 20 : 30;
    if (styleToken.includes('circular_medium')) return isMobile ? 24 : 36;
    if (styleToken.includes('circular_large')) return isMobile ? 28 : 44;
    // Fallback
    return isMobile ? 20 : 30;
  }

  function sizeForStyleSquare(styleToken, isMobile) {
    if (!styleToken) return isMobile ? 20 : 30;
    if (styleToken.includes('square_small')) return isMobile ? 20 : 30;
    if (styleToken.includes('square_medium')) return isMobile ? 24 : 36;
    if (styleToken.includes('square_large')) return isMobile ? 28 : 44;
    return isMobile ? 20 : 30;
  }

  function buildSwatchContainer(entry, useStyle, swatchImageSource) {
    const isMobile = window.matchMedia('(max-width: 640px)').matches;
    const styleToken = String(useStyle || '').toLowerCase();
    const kind = styleToken.includes('dropdown') ? 'dropdown'
                : styleToken.includes('square') ? 'square'
                : styleToken.includes('none') || styleToken.includes('not_show') || styleToken.includes('hidden') ? 'none'
                : 'circular';
    debugLog('buildSwatchContainer kind=', kind, 'styleToken=', styleToken);

    // Not show → return an empty hidden container to keep caller logic safe
    if (kind === 'none') {
      const empty = document.createElement('div');
      empty.style.display = 'none';
      return empty;
    }

    // Dropdown with label
    if (kind === 'dropdown') {
      const container = document.createElement('div');
      container.className = 'twc-swatch-dropdown';
      container.style.display = 'flex';
      container.style.flexDirection = 'column';
      container.style.gap = '4px';

      const label = document.createElement('label');
      label.textContent = entry.option_name || 'Options';
      label.style.fontSize = '12px';
      label.style.color = '#374151';

      const select = document.createElement('select');
      select.style.border = '1px solid rgba(0,0,0,0.12)';
      select.style.borderRadius = '6px';
      select.style.padding = '6px 8px';
      select.style.fontSize = '14px';

      (entry.swatches || []).forEach(function(s) {
        const opt = document.createElement('option');
        opt.value = s.link || '';
        opt.textContent = s.label || s.title || '';
        select.appendChild(opt);
      });

      select.addEventListener('change', function(e) {
        const href = e.target.value;
        if (href) window.location.href = href;
      });

      container.appendChild(label);
      container.appendChild(select);
      return container;
    }

    // Circular or Square buttons
    const isCircular = (kind === 'circular');
    const size = isCircular ? sizeForStyleCircular(styleToken, isMobile) : sizeForStyleSquare(styleToken, isMobile);
    const wrapper = document.createElement('div');
    wrapper.className = 'twc-swatch-container';
    wrapper.style.display = 'flex';
    wrapper.style.flexWrap = 'wrap';
    wrapper.style.gap = '6px';
    wrapper.style.alignItems = 'center';

    function computeVisual(s) {
      // Determine how to render the swatch depending on swatchImageSource and data
      if (swatchImageSource === 'custom_color_image') {
        if (s.color) {
          return { bgColor: s.color };
        }
        const customImg = s.image || s.custom_image;
        if (customImg) {
          return { bgImage: customImg };
        }
        // Fallback to product images if neither color nor custom image present
        const src = pickImage(s.images || [], 'first_product_image');
        return { imgSrc: src };
      }
      // Default paths use product images per source selection
      return { imgSrc: pickImage(s.images || [], swatchImageSource) };
    }

    (entry.swatches || []).forEach(function(s) {
      const visual = computeVisual(s);
      const a = document.createElement('a');
      a.href = s.link || '#';
      a.style.display = 'inline-flex';
      a.style.width = size + 'px';
      a.style.height = size + 'px';
      a.style.borderRadius = isCircular ? '9999px' : '6px';
      a.style.overflow = 'hidden';
      a.style.border = '1px solid rgba(0,0,0,0.08)';
      a.style.alignItems = 'center';
      a.style.justifyContent = 'center';
      a.title = s.label || s.title || '';

      if (visual.bgColor) {
        a.style.backgroundColor = visual.bgColor;
      } else if (visual.bgImage) {
        a.style.backgroundImage = `url(${visual.bgImage})`;
        a.style.backgroundSize = 'cover';
        a.style.backgroundPosition = 'center';
      } else if (visual.imgSrc) {
        const img = document.createElement('img');
        img.src = visual.imgSrc;
        img.alt = s.label || s.title || '';
        img.style.maxWidth = '100%';
        img.style.maxHeight = '100%';
        a.appendChild(img);
      }
      wrapper.appendChild(a);
    });

    return wrapper;
  }

  function renderForCollection(data) {
    // For each entry, find product card with matching data-product-id and insert after .product-preview__area-photo
    data.forEach(function(entry) {
      var selector = `[data-product-id="${entry.product_id}"]`;
      var cards = document.querySelectorAll(selector);
      if (!cards || cards.length === 0) { debugLog('renderForCollection no cards for product_id=', entry.product_id); return; }
      var useStyle = entry.collection_page_style;
      var container = buildSwatchContainer(entry, useStyle, entry.swatch_image_source);
      cards.forEach(function(card) {
        var anchor = card.querySelector('.product-preview__area-photo');
        if (anchor) {
          // Insert a fresh clone per card
          anchor.insertAdjacentElement('afterend', container.cloneNode(true));
        } else {
          debugLog('renderForCollection no anchor in card for product_id=', entry.product_id);
        }
      });
    });
  }

  function renderForProduct(data) {
    // Mirror collection logic: for each entry, find matching nodes by data-product-id
    data.forEach(function(entry) {
      var selector = `[data-product-id="${String(entry.product_id)}"]`;
      var cards = document.querySelectorAll(selector);
      if (!cards || cards.length === 0) { debugLog('renderForProduct no cards for product_id=', entry.product_id); return; }
      var useStyle = entry.product_page_style || entry.collection_page_style;
      var container = buildSwatchContainer(entry, useStyle, entry.swatch_image_source);
      cards.forEach(function(card) {
        var variantsArea = card.querySelector('.product__area-variants');
        if (variantsArea) {
          variantsArea.innerHTML = '';
          variantsArea.style.display = 'none';
          variantsArea.appendChild(container.cloneNode(true));
          debugLog('renderForProduct replaced .product__area-variants for product_id=', entry.product_id);
        } else {
          var anchor = card.querySelector('.product-preview__area-photo') || card;
          anchor.insertAdjacentElement('afterend', container.cloneNode(true));
          debugLog('renderForProduct inserted after photo for product_id=', entry.product_id);
        }
      });
    });
  }

  function init() {
    var accountId = getAccountIdFromScript();
    if (!accountId) { debugLog('init no account id'); return; }
    debugLog('init accountId=', accountId);
    fetchSwatchJson(accountId).then(function(data) {
      if (!Array.isArray(data)) { debugLog('json not array'); return; }
      var path = window.location.pathname;
      if (path.includes('collection')) {
        debugLog('page=collection entries=', data.length);
        renderForCollection(data);
      } else if (path.includes('product')) {
        debugLog('page=product entries=', data.length);
        renderForProduct(data);
      } else {
        // Only operate on collection or product pages
        debugLog('page ignored path=', path);
        return;
      }
    }).catch(function(err) {
      // eslint-disable-next-line no-console
      console.warn('swatch.js error:', err);
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();


