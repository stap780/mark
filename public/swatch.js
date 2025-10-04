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

  // Shared handler for any swatch dropdown select
  function handleSwatchDropdownChange(event) {
    const select = event && event.target;
    const opt = select && select.options ? select.options[select.selectedIndex] : null;
    const rawHref = opt ? (opt.value || opt.getAttribute('data-link')) : (select ? select.value : null);
    const href = (rawHref || '').trim();
    const similarId = opt ? opt.getAttribute('data-tws-similar-id') : null;
    debugLog('handleSwatchDropdownChange fired', { href, similarId, target: select, path: window.location.pathname });
    if (href && href !== '#' && href !== 'null') {
      try {
        window.location.assign(href);
      } catch (e) {
        // eslint-disable-next-line no-console
        console.warn('swatch dropdown navigation error:', e);
      }
    } else {
      // Fallback: try to find a link on the page for this product id and click it
      if (similarId) {
        const node = document.querySelector(`[data-product-id="${String(similarId)}"] a`);
        if (node && node.href) {
          debugLog('dropdown fallback navigate via DOM anchor', node.href);
          window.location.assign(node.href);
          return;
        }
      }
      debugLog('dropdown ignored href', href);
    }
  }

  // Global delegated listener in case dropdowns are inserted dynamically
  document.addEventListener('change', function(e) {
    const t = e.target;
    if (t && t.matches && t.matches('.twc-swatch-select')) {
      handleSwatchDropdownChange(e);
    }
  });

  // Ensure all dropdowns reflect the correct selected option
  function applySelectedToAllSwatchSelects() {
    const selects = document.querySelectorAll('.twc-swatch-select');
    selects.forEach(function(select) {
      const productId = select.getAttribute('data-twc-select-product-id');
      if (!productId) { return; }
      const match = Array.from(select.options).find(
        o => String(o.getAttribute('data-tws-similar-id')) === String(productId)
      );
      if (match) {
        select.value = match.value;
        debugLog('applySelectedToAllSwatchSelects matched', { productId, value: match.value });
      } else if (select.options.length > 0) {
        select.selectedIndex = 0;
        debugLog('applySelectedToAllSwatchSelects defaulted first', { productId });
      }
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
    if (!styleToken) return isMobile ? 28 : 34;
    if (styleToken.includes('square_small')) return isMobile ? 24 : 34;
    if (styleToken.includes('square_medium')) return isMobile ? 28 : 40;
    if (styleToken.includes('square_large')) return isMobile ? 32 : 48;
    return isMobile ? 28 : 34;
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

    // Dropdown with label and select that navigates on change
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
      select.classList.add('twc-swatch-select');
      if (entry.product_id) select.setAttribute('data-twc-select-product-id', entry.product_id);
      select.style.border = '1px solid rgba(0,0,0,0.12)';
      select.style.borderRadius = '6px';
      select.style.padding = '6px 8px';
      select.style.fontSize = '14px';

      (entry.swatches || []).forEach(function(s) {
        const opt = document.createElement('option');
        opt.value = s.link || '#';
        opt.textContent = s.label || s.title || '';
        if (s.link) opt.setAttribute('data-link', s.link);
        if (s.similar_id) opt.setAttribute('data-tws-similar-id', s.similar_id);
        select.appendChild(opt);
      });
      // Selection will be applied after all renders

      // Also attach per-element listener for robustness
      select.addEventListener('change', handleSwatchDropdownChange);

      container.appendChild(label);
      container.appendChild(select);
      return container;
    }

    // Circular or Square buttons
    const isCircular = (kind === 'circular');
    // Square should show the same style as circular (same sizing)
    const size = sizeForStyleCircular(styleToken, isMobile);
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
      a.style.borderRadius = isCircular ? '9999px' : '0px';
      a.style.padding = isCircular ? '0px' : '3px';
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
    // after rendering all, apply selection to dropdowns
    applySelectedToAllSwatchSelects();
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
          card.querySelector('.product__variants').style.display = 'none';
          variantsArea.appendChild(container.cloneNode(true));
          debugLog('renderForProduct .product__area-variants for product_id=', entry.product_id);
        } else {
          var anchor = card.querySelector('.product-preview__area-photo') || card;
          anchor.insertAdjacentElement('afterend', container.cloneNode(true));
          debugLog('renderForProduct inserted after photo for product_id=', entry.product_id);
        }
      });
    });
    // after rendering all, apply selection to dropdowns
    applySelectedToAllSwatchSelects();
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


