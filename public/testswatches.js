/**
 * Swatch.js - Виджет выбора цвета (Swatch)
 * Версия: 1.8.0
 * Описание: Виджет swatches для выбора цвета (swatches) и управления цветовыми вариантами на сайте.
 */

// Execute immediately if DOM is ready, or wait for DOMContentLoaded
(function () {
  function init() {
    class Swatches {
      constructor() {
        this.version = "1.8.0";
        this.status = false;
        this.S3_BASE =
          "https://s3.twcstorage.ru/ae4cd7ee-b62e0601-19d6-483e-bbf1-416b386e5c23";
        this.clientId = "";
        this.data = "";
      }

      debugLog() {
        if (!this.status) return;
        try {
          console.log("[swatch v" + this.version + "]", ...arguments);
        } catch (e) {
          /* noop */
        }
      }

      getVersion() {
        return this.version;
      }

      getClientId() {
        const scripts = document.querySelectorAll("script");

        for (let i = 0; i < scripts.length; i++) {
          const src = scripts[i].getAttribute("src") || "";

          if (src.includes("swatch.js")) {
            const url = new URL(src, window.location.origin);
            const id = url.searchParams.get("id");
            const dbg = url.searchParams.get("debug");

            if (dbg === "1" || dbg === "true") {
              this.status = true;
            }

            if (id) {
              this.clientId = id;
            }
          }
        }
        return null;
      }

      async getSwatches(url) {
        try {
          const response = await fetch(url);
          const data = await response.json();
          return data;
        } catch (error) {
          throw error;
        }
      }

      checkProduct(theId) {
        let productsStatus = false;

        if (document.querySelector(`.product[data-product-id="${theId}"]`)) {
          productsStatus = true;
        }

        return productsStatus;
      }

      checkPreviewStatus(theId) {
        let productsStatus = false;

        if (
          document.querySelector(`.product-preview[data-product-id="${theId}"]`)
        ) {
          productsStatus = true;
        }

        return productsStatus;
      }

      createSwatches(items, classMb, classMd, imageSource, currentProductId) {
        let list = "";

        if (classMd.includes("dropdown")) {
          let options = "";

          items.swatches.forEach((opt) => {
            // Р  РЎСџР РЋР вЂљР  РЎвЂўР  Р вЂ Р  Р’ВµР РЋР вЂљР РЋР РЏР  Р’ВµР  РЎВ, Р РЋР С“Р  РЎвЂўР  РЎвЂўР РЋРІР‚С™Р  Р вЂ Р  Р’ВµР РЋРІР‚С™Р РЋР С“Р РЋРІР‚С™Р  Р вЂ Р РЋРЎвЂњР  Р’ВµР РЋРІР‚С™ Р  Р’В»Р  РЎвЂ Р РЋР РЉР РЋРІР‚С™Р  РЎвЂў Р РЋРІР‚С™Р  Р’ВµР  РЎвЂќР РЋРЎвЂњР РЋРІР‚В°Р  Р’ВµР  РЎВР РЋРЎвЂњ Р РЋРІР‚С™Р  РЎвЂўР  Р вЂ Р  Р’В°Р РЋР вЂљР РЋРЎвЂњ
            const isSelected = opt.similar_id === currentProductId;
            const selectedAttr = isSelected ? "selected" : "";
            this.debugLog(
              `Creating option: ${opt.label}, isSelected: ${isSelected}`
            );
            options += `<option value="${opt.link}" ${selectedAttr}>${opt.label}</option>`;
          });

          list = `
                  <select name="select" class='twc-swatch__select ${classMb} ${classMd}'>
                      ${options}
                  </select>
              `;
        } else {
          items.swatches.forEach((item) => {
            let image = "";

            if (imageSource != "" && imageSource != "custom_color_image") {
              if (imageSource == "last_product_image") {
                image = item.images[-1];
                this.debugLog(item.images[-1], "image");
              } else if (
                imageSource == "second_product_image" &&
                item.images.length > 1
              ) {
                this.debugLog(item.images[1], "image");
                image = item.images[1];
              } else if (
                imageSource == "second_product_image" &&
                item.images.length == 1
              ) {
                this.debugLog(item.images[0], "image");
                image = item.images[0];
              } else if (imageSource == "first_product_image") {
                this.debugLog(item.images[0], "image");
                image = item.images[0];
              }
            }

            if (imageSource == "custom_color_image" && item.picture) {
              image = item.picture;
            }

            this.debugLog(image, "image");

            if (image) {
              image = `
                          <img src='${image}' title="${item.label}">
                      `;
            } else {
              if (item.color) {
                image = `<span style="background: ${item.color};"></span>`;
              } else {
                image = `<span>${item.label}</span>`;
              }
            }

            // if(classMd.includes('square')) {
            //     image = `<span >${item.label}</span>`;

            // } else if (classMd.includes('circular')) {
            //     if (item.picture) {
            //         image = `<img src='${item.picture}' title="${item.label}">`;
            //     } else {
            //         image = `<span style="background: ${item.color};"></span>`;
            //     }
            // }

            list += `
                      <a href="${item.link}" class='twc-swatch__item ${classMb} ${classMd}' title="${item.label}"> 
                          ${image}
                      </a>
                  `;
          });
        }

        return list;
      }

      createItemsList(data, itemCls) {
        const itemMdClass = data.product_page_style;
        const itemMbClass = data.product_page_style_mob;
        const imageSource = data.product_page_image_source;
        const rowClass = "is-row";

        // Р  РЎСџР РЋР вЂљР  РЎвЂўР  Р вЂ Р  Р’ВµР РЋР вЂљР РЋР РЏР  Р’ВµР  РЎВ, Р  Р вЂ¦Р РЋРЎвЂњР  Р’В¶Р  Р вЂ¦Р  РЎвЂў Р  Р’В»Р  РЎвЂ Р РЋР С“Р  РЎвЂќР РЋР вЂљР РЋРІР‚в„–Р  Р вЂ Р  Р’В°Р РЋРІР‚С™Р РЋР Р‰ Р  Р’В±Р  Р’В»Р  РЎвЂўР  РЎвЂќ
        // Р  Р Р‹Р  РЎвЂќР РЋР вЂљР РЋРІР‚в„–Р  Р вЂ Р  Р’В°Р  Р’ВµР  РЎВ Р РЋРІР‚С™Р  РЎвЂўР  Р’В»Р РЋР Р‰Р  РЎвЂќР  РЎвЂў Р  Р’ВµР РЋР С“Р  Р’В»Р  РЎвЂ desktop_hide Р РЋРЎвЂњР РЋР С“Р РЋРІР‚С™Р  Р’В°Р  Р вЂ¦Р  РЎвЂўР  Р вЂ Р  Р’В»Р  Р’ВµР  Р вЂ¦ (mobile_hide Р  РЎвЂўР  Р’В±Р РЋР вЂљР  Р’В°Р  Р’В±Р  Р’В°Р РЋРІР‚С™Р РЋРІР‚в„–Р  Р вЂ Р  Р’В°Р  Р’ВµР РЋРІР‚С™Р РЋР С“Р РЋР РЏ Р РЋРІР‚РЋР  Р’ВµР РЋР вЂљР  Р’ВµР  Р’В· CSS)
        const isDesktopHide =
          itemMdClass && itemMdClass.includes("desktop_hide");

        this.debugLog(`[createItemsList] Desktop hide: ${isDesktopHide}`);

        if (isDesktopHide) {
          // Р  РІР‚СћР РЋР С“Р  Р’В»Р  РЎвЂ desktop_hide, Р  РЎвЂ”Р  РЎвЂўР  Р’В»Р  Р вЂ¦Р  РЎвЂўР РЋР С“Р РЋРІР‚С™Р РЋР Р‰Р РЋР вЂ№ Р РЋР С“Р  РЎвЂќР РЋР вЂљР РЋРІР‚в„–Р  Р вЂ Р  Р’В°Р  Р’ВµР  РЎВ Р  Р’В±Р  Р’В»Р  РЎвЂўР  РЎвЂќ
          this.debugLog(
            "[createItemsList] Block hidden (desktop_hide), returning empty string"
          );
          return "";
        }

        let propsList = "";
        let items = "";

        if (data.swatches.length) {
          items = this.createSwatches(
            data,
            itemMbClass,
            itemMdClass,
            imageSource,
            data.product_id
          );
        }

        propsList = `
              <div class='twc-swatch__list is-list-${itemMdClass}'>
                  ${items}
              </div>
          `;

        return propsList;
      }

      createItemsListForCollection(data, currentProductId) {
        const itemMdClass = data.collection_page_style;
        const itemMbClass = data.collection_page_style_mob;
        const imageSource = data.collection_page_image_source;

        this.debugLog(
          `[createItemsListForCollection] Desktop style: ${itemMdClass}, Mobile style: ${itemMbClass}, Image source: ${imageSource}, Current product: ${currentProductId}`
        );

        // Р  РЎСџР РЋР вЂљР  РЎвЂўР  Р вЂ Р  Р’ВµР РЋР вЂљР РЋР РЏР  Р’ВµР  РЎВ, Р  Р вЂ¦Р РЋРЎвЂњР  Р’В¶Р  Р вЂ¦Р  РЎвЂў Р  Р’В»Р  РЎвЂ Р РЋР С“Р  РЎвЂќР РЋР вЂљР РЋРІР‚в„–Р  Р вЂ Р  Р’В°Р РЋРІР‚С™Р РЋР Р‰ Р  Р’В±Р  Р’В»Р  РЎвЂўР  РЎвЂќ
        // Р  Р Р‹Р  РЎвЂќР РЋР вЂљР РЋРІР‚в„–Р  Р вЂ Р  Р’В°Р  Р’ВµР  РЎВ Р РЋРІР‚С™Р  РЎвЂўР  Р’В»Р РЋР Р‰Р  РЎвЂќР  РЎвЂў Р  Р’ВµР РЋР С“Р  Р’В»Р  РЎвЂ desktop_hide Р РЋРЎвЂњР РЋР С“Р РЋРІР‚С™Р  Р’В°Р  Р вЂ¦Р  РЎвЂўР  Р вЂ Р  Р’В»Р  Р’ВµР  Р вЂ¦ (mobile_hide Р  РЎвЂўР  Р’В±Р РЋР вЂљР  Р’В°Р  Р’В±Р  Р’В°Р РЋРІР‚С™Р РЋРІР‚в„–Р  Р вЂ Р  Р’В°Р  Р’ВµР РЋРІР‚С™Р РЋР С“Р РЋР РЏ Р РЋРІР‚РЋР  Р’ВµР РЋР вЂљР  Р’ВµР  Р’В· CSS)
        const isDesktopHide =
          itemMdClass && itemMdClass.includes("desktop_hide");

        this.debugLog(
          `[createItemsListForCollection] Desktop hide: ${isDesktopHide}`
        );

        if (isDesktopHide) {
          // Р  РІР‚СћР РЋР С“Р  Р’В»Р  РЎвЂ desktop_hide, Р  РЎвЂ”Р  РЎвЂўР  Р’В»Р  Р вЂ¦Р  РЎвЂўР РЋР С“Р РЋРІР‚С™Р РЋР Р‰Р РЋР вЂ№ Р РЋР С“Р  РЎвЂќР РЋР вЂљР РЋРІР‚в„–Р  Р вЂ Р  Р’В°Р  Р’ВµР  РЎВ Р  Р’В±Р  Р’В»Р  РЎвЂўР  РЎвЂќ
          this.debugLog(
            "[createItemsListForCollection] Block hidden (desktop_hide), returning empty string"
          );
          return "";
        }

        let propsList = "";
        let items = "";

        if (data.swatches.length) {
          items = this.createSwatches(
            data,
            itemMbClass,
            itemMdClass,
            imageSource,
            currentProductId
          );
        }

        propsList = `
              <div class='twc-swatch__list is-list-${itemMdClass}'>
                  ${items}
              </div>
          `;

        return propsList;
      }

      addBlockToProductItem(blockData, productItem, addClassItem) {
        this.debugLog(
          "[addBlockToProductItem] Attempting to add swatch block to product page"
        );

        if (addClassItem && productItem.querySelector(`.${addClassItem}`)) {
          const parentBlock = productItem.querySelector(`.${addClassItem}`);

          this.debugLog(
            "[addBlockToProductItem] Found .product__variants, inserting before it"
          );
          parentBlock.append(blockData);
        } else if (productItem.querySelector(".product__variants")) {
          const beforeBlock = productItem.querySelector(".product__variants");
          const parentBlock = beforeBlock.parentNode;

          this.debugLog(
            "[addBlockToProductItem] Found .product__variants, inserting before it"
          );
          parentBlock.insertBefore(blockData, beforeBlock);
        } else if (productItem.querySelector(".product__title")) {
          const beforeBlock = productItem.querySelector(".product__title");
          const parentBlock = beforeBlock.parentNode;

          this.debugLog(
            "[addBlockToProductItem] Found .product__title, appending to parent"
          );
          parentBlock.append(blockData);
        } else {
          // Fallback: Р  РЎвЂ”Р РЋР вЂљР  РЎвЂўР РЋР С“Р РЋРІР‚С™Р  РЎвЂў Р  РўвЂР  РЎвЂўР  Р’В±Р  Р’В°Р  Р вЂ Р  РЎвЂР РЋРІР‚С™Р РЋР Р‰ Р  РЎвЂќ Р  РЎвЂ”Р  Р’ВµР РЋР вЂљР  Р вЂ Р  РЎвЂўР  РЎВР РЋРЎвЂњ .product Р РЋР РЉР  Р’В»Р  Р’ВµР  РЎВР  Р’ВµР  Р вЂ¦Р РЋРІР‚С™Р РЋРЎвЂњ
          const productElement = productItem;
          if (productElement) {
            this.debugLog(
              "[addBlockToProductItem] Fallback: adding to .product element"
            );
            productElement.insertBefore(blockData, productElement.firstChild);
          } else {
            this.debugLog(
              "[addBlockToProductItem] ERROR: No suitable element found to insert swatch block"
            );
          }
        }
      }

      addBlockToPreview(previewElement, blockData, dataPreviewClass) {
        this.debugLog(
          "[addBlockToPreview] Attempting to add swatch block to preview"
        );

        // Р  Р’ВР РЋРІР‚В°Р  Р’ВµР  РЎВ Р РЋР РЉР  Р’В»Р  Р’ВµР  РЎВР  Р’ВµР  Р вЂ¦Р РЋРІР‚С™ product-preview__area-title
        let titleElement = previewElement.querySelector(
          ".product-preview__area-title"
        );

        if (
          dataPreviewClass &&
          previewElement.querySelector(`.${dataPreviewClass}`)
        ) {
          previewElement
            .querySelector(`.${dataPreviewClass}`)
            .appendChild(blockData);
        } else if (titleElement) {
          // Р  РЎСљР  Р’В°Р  РІвЂћвЂ“Р  РўвЂР  Р’ВµР  Р вЂ¦ Р  Р’В·Р  Р’В°Р  РЎвЂ“Р  РЎвЂўР  Р’В»Р  РЎвЂўР  Р вЂ Р  РЎвЂўР  РЎвЂќ - Р  Р вЂ Р РЋР С“Р РЋРІР‚С™Р  Р’В°Р  Р вЂ Р  Р’В»Р РЋР РЏР  Р’ВµР  РЎВ Р  РЎвЂ”Р  РЎвЂўР РЋР С“Р  Р’В»Р  Р’Вµ Р  Р вЂ¦Р  Р’ВµР  РЎвЂ“Р  РЎвЂў
          this.debugLog(
            "[addBlockToPreview] Found .product-preview__area-title, inserting after it"
          );
          titleElement.insertAdjacentElement("afterend", blockData);
        } else {
          // Fallback: Р  РўвЂР  РЎвЂўР  Р’В±Р  Р’В°Р  Р вЂ Р  РЎвЂР РЋРІР‚С™Р РЋР Р‰ Р  Р вЂ  Р  РЎвЂќР  РЎвЂўР  Р вЂ¦Р  Р’ВµР РЋРІР‚  preview Р РЋР РЉР  Р’В»Р  Р’ВµР  РЎВР  Р’ВµР  Р вЂ¦Р РЋРІР‚С™Р  Р’В°
          this.debugLog(
            "[addBlockToPreview] Title not found, appending to preview element"
          );
          previewElement.appendChild(blockData);
        }
      }

      selectListener(parentBlock) {
        this.debugLog(parentBlock, "propsWrapper");
        if (parentBlock.querySelector(".twc-swatch__select")) {
          const selects = parentBlock.querySelectorAll(".twc-swatch__select");

          selects.forEach((item) => {
            item.addEventListener("change", (e) => {
              window.location = item.value;
            });
          });
        }
      }

      fillProduct(data) {
        const productItem = document.querySelector(
          `.product[data-product-id="${data.product_id}"]`
        );
        const propsItemsList = this.createItemsList(data);
        const addClassItem = data.css_class_product;

        // Р  РІР‚СћР РЋР С“Р  Р’В»Р  РЎвЂ Р РЋР С“Р  РЎвЂ”Р  РЎвЂР РЋР С“Р  РЎвЂўР  РЎвЂќ Р  РЎвЂ”Р РЋРЎвЂњР РЋР С“Р РЋРІР‚С™Р  РЎвЂўР  РІвЂћвЂ“ (desktop_hide/mobile_hide), Р  Р вЂ¦Р  Р’Вµ Р РЋР С“Р  РЎвЂўР  Р’В·Р  РўвЂР  Р’В°Р РЋРІР‚ВР  РЎВ Р  Р’В±Р  Р’В»Р  РЎвЂўР  РЎвЂќ
        if (!propsItemsList || propsItemsList.trim() === "") {
          this.debugLog("[fillProduct] Block is hidden, skipping creation");
          return;
        }

        const propsWrapper = document.createElement("div");
        propsWrapper.classList.add("twc-swatch__block");

        propsWrapper.innerHTML = `
              <span class='twc-swatch__title option-label'>${data.option_name}</span>
              ${propsItemsList}
          `;

        this.addBlockToProductItem(propsWrapper, productItem, addClassItem);

        this.selectListener(propsWrapper);
      }

      fillPreviews(data) {
        const previewItems = document.querySelectorAll(
          `.product-preview[data-product-id="${data.product_id}"]`
        );
        const dataPreviewClass = data.css_class_preview;

        this.debugLog(
          `[fillPreviews] Found ${previewItems.length} preview items for product_id: ${data.product_id}`
        );

        if (!previewItems.length) return;

        this.debugLog(
          `[fillPreviews] Creating swatch blocks with style: ${data.collection_page_style}`
        );

        previewItems.forEach((preview, index) => {
          // Р  РЎСџР  РЎвЂўР  Р’В»Р РЋРЎвЂњР РЋРІР‚РЋР  Р’В°Р  Р’ВµР  РЎВ product_id Р  РЎвЂР  Р’В· Р РЋР С“Р  Р’В°Р  РЎВР  РЎвЂўР  РЎвЂ“Р  РЎвЂў preview Р РЋР РЉР  Р’В»Р  Р’ВµР  РЎВР  Р’ВµР  Р вЂ¦Р РЋРІР‚С™Р  Р’В°
          const currentProductId = preview.getAttribute("data-product-id");
          this.debugLog(
            `[fillPreviews] Processing preview ${
              index + 1
            }, product_id: ${currentProductId}`
          );

          const propsItemsList = this.createItemsListForCollection(
            data,
            currentProductId
          );

          // Р  РІР‚СћР РЋР С“Р  Р’В»Р  РЎвЂ Р РЋР С“Р  РЎвЂ”Р  РЎвЂР РЋР С“Р  РЎвЂўР  РЎвЂќ Р  РЎвЂ”Р РЋРЎвЂњР РЋР С“Р РЋРІР‚С™Р  РЎвЂўР  РІвЂћвЂ“ (desktop_hide/mobile_hide), Р  Р вЂ¦Р  Р’Вµ Р РЋР С“Р  РЎвЂўР  Р’В·Р  РўвЂР  Р’В°Р РЋРІР‚ВР  РЎВ Р  Р’В±Р  Р’В»Р  РЎвЂўР  РЎвЂќ
          if (!propsItemsList || propsItemsList.trim() === "") {
            this.debugLog(
              `[fillPreviews] Block is hidden for preview ${
                index + 1
              }, skipping`
            );
            return;
          }

          const propsWrapper = document.createElement("div");
          propsWrapper.classList.add("twc-swatch__block");

          propsWrapper.innerHTML = `
                  <span class='twc-swatch__title option-label'>${data.option_name}</span>
                  ${propsItemsList}
              `;

          this.debugLog(
            `[fillPreviews] Adding swatch block to preview item ${index + 1}`
          );
          this.addBlockToPreview(preview, propsWrapper, dataPreviewClass);
          this.selectListener(propsWrapper);
        });
      }

      changeSelectListeer() {
        if (document.querySelector(".twc-swatch__select")) {
          const linkSelects = document.querySelectorAll(".twc-swatch__select");

          linkSelects.forEach((selectItem) => {
            selectItem.addEventListener("change", (e) => {
              this.debugLog(selectItem.value);
            });
          });
        }
      }

      createStyles() {
        const styleTag = document.createElement("style");

        styleTag.innerHTML = `
              .twc-swatch__list {
                  display: -webkit-box;
                  display: -ms-flexbox;
                  display: flex;
                  -webkit-box-orient: horizontal;
                  -webkit-box-direction: normal;
                  -ms-flex-direction: row;
                  flex-direction: row;
                  gap: 12px;
                  -webkit-box-align: center;
                  -ms-flex-align: center;
                  align-items: center;
                  -ms-flex-wrap: wrap;
                  flex-wrap: wrap;
              }
  
              .twc-swatch__item {
                  cursor: pointer;
                  text-decoration: none;
                  display: -webkit-box;
                  display: -ms-flexbox;
                  display: flex;
              }
  
              .twc-swatch__title {
                  display: block;
                  line-height: 1.2;
                  margin-bottom: 10px;
                  color: var(--color-text-major-shade);
              }
  
              .twc-swatch__item.circular_small_desktop,
              .twc-swatch__item.circular_medium_desktop,
              .twc-swatch__item.circular_large_desktop,
              .twc-swatch__item.circular_small_mobile,
              .twc-swatch__item.circular_medium_mobile,
              .twc-swatch__item.circular_large_desktop {
                  border-radius: 50%;
                  overflow: hidden;
              }
  
              .twc-swatch__item.circular_small_desktop {
                  width: 20px;
                  height: 20px;
              }
  
              .twc-swatch__item.circular_medium_desktop {
                  width: 32px;
                  height: 32px;
              }
  
              .twc-swatch__item.circular_large_desktop {
                  width: 48px;
                  height: 48px;
              }
  
              .twc-swatch__item.square_desktop_small,
              .twc-swatch__item.square_desktop_medium,
              .twc-swatch__item.square_desktop_small,
              .twc-swatch__item.square_mobile_medium,
              .twc-swatch__item.square_mobile_large,
              .twc-swatch__item.square_desktop_large {
                  padding: 0;
                  border-radius: var(--controls-btn-border-radius);
                  display: -webkit-box;
                  display: -ms-flexbox;
                  display: flex;
                  -webkit-box-align: center;
                  -ms-flex-align: center;
                  align-items: center;
                  -webkit-box-pack: center;
                  -ms-flex-pack: center;
                  justify-content: center;
                  font-weight: normal;
                  cursor: pointer;
                  cursor: pointer;
                  border: 1px solid var(--color-btn-bg);
                  color: var(--color-text);
                  min-width: 20px;
                  overflow: hidden;
              }
  
              .twc-swatch__item.square_desktop_small {
                  height: 20px;
                  font-size: 14px;
                  line-height: 18px;
                  min-width: 20px;
              }
  
              .twc-swatch__item.square_desktop_medium {
                  height: 32px;
                  font-size: 16px;
                  line-height: 30px;
                  min-width: 32px;
              }
  
              .twc-swatch__item.square_desktop_large {
                  height: 48px;
                  font-size: 18px;
                  line-height: 46px;
                  min-width: 48px;
              }
  
              .twc-swatch__item span,
              .twc-swatch__item img {
                  width: 100%;
                  height: 100%;
                  display: -webkit-box;
                  display: -ms-flexbox;
                  display: flex;
                  -webkit-box-pack: center;
                  -ms-flex-pack: center;
                  justify-content: center;
                  -webkit-box-align: center;
                  -ms-flex-align: center;
                  align-items: center;
              }
  
              .twc-swatch__item img {
                  object-fit: cover;
              }
  
              .twc-swatch__block {
                  margin: 0 0 1rem 0;
              }
  
              .twc-swatch__select {
                  padding: 0 24px;
                  display: inline-block;
                  width: fit-content;
                  border: 1px solid var(--color-btn-bg);
                  border-radius: var(--controls-form-border-radius);
                  box-shadow: var(--color-form-controls-shadow);
                  outline: 0;
                  vertical-align: middle;
                  transition: var(--input-transition);
                  background-color: transparent;
              }
  
              .twc-swatch__select.dropdown_label_small {
                  height: 20px;
                  font-size: 12px;
                  line-height: 14px;
              }
  
              .twc-swatch__select.dropdown_label_medium {
                  height: 32px;
                  font-size: 16px;
                  line-height: 18px;
              }
  
              .twc-swatch__select.dropdown_label_large {
                  height: 48px;
                  font-size: 18px;
                  line-height: 20px;
              }
  
              @media screen and (max-width: 767px) {
                  .twc-swatch__item.circular_small_mobile {
                      width: 14px;
                      height: 14px;
                  }
  
                  .twc-swatch__item.circular_medium_mobile {
                      width: 24px;
                      height: 24px;
                  }
  
                  .twc-swatch__item.circular_large_mobile {
                      width: 36px;
                      height: 36px;
                  }
  
                  .twc-swatch__item.square_desktop_small {
                      height: 16px;
                      font-size: 12px;
                      line-height: 16px;
                      min-width: 16px;
                  }
  
                  .twc-swatch__item.square_mobile_medium {
                      height: 24px;
                      font-size: 14px;
                      line-height: 22px;
                      min-width: 24px;
                  }
                  .twc-swatch__item.square_mobile_large {
                      height: 36px;
                      font-size: 18px;
                      line-height: 36px;
                      min-width: 36px;
                  }
                  .twc-swatch__select.dropdown_label_medium {
                      height: 24px;
                      font-size: 14px;
                      line-height: 16px;
                  }
                  .twc-swatch__select.dropdown_label_large {
                      height: 36px;
                      font-size: 18px;
                      line-height: 20px;
                  }

                  /* Р  Р Р‹Р  РЎвЂќР РЋР вЂљР РЋРІР‚в„–Р РЋРІР‚С™Р  РЎвЂР  Р’Вµ Р  Р вЂ¦Р  Р’В° Р  РЎВР  РЎвЂўР  Р’В±Р  РЎвЂР  Р’В»Р РЋР Р‰Р  Р вЂ¦Р РЋРІР‚в„–Р РЋРІР‚В¦ Р  Р’ВµР РЋР С“Р  Р’В»Р  РЎвЂ Р РЋРЎвЂњР  РЎвЂќР  Р’В°Р  Р’В·Р  Р’В°Р  Р вЂ¦ mobile_hide */
                  .twc-swatch__item.mobile_hide,
                  .twc-swatch__select.mobile_hide {
                      display: none !important;
                  }
              }
          `;

        document.body.append(styleTag);
      }

      fillSwatches() {
        this.debugLog(
          `[fillSwatches] Processing ${this.data.length} swatch items`
        );

        if (this.data.length) {
          this.data.forEach((item, index) => {
            this.debugLog(
              `[fillSwatches] Processing item ${index + 1}/${
                this.data.length
              } - Product ID: ${item.product_id}, Name: ${item.name}`
            );

            let productStatus = this.checkProduct(item.product_id);
            let previewStatus = this.checkPreviewStatus(item.product_id);

            this.debugLog(
              `[fillSwatches] Product status: ${productStatus}, Preview status: ${previewStatus}`
            );

            if (productStatus) {
              this.debugLog(
                `[fillSwatches] Calling fillProduct for product_id: ${item.product_id}`
              );
              this.fillProduct(item);
            }

            if (previewStatus) {
              this.debugLog(
                `[fillSwatches] Calling fillPreviews for product_id: ${item.product_id}`
              );

              if (!item.statusLoaded) {
                this.fillPreviews(item);
                item.statusLoaded = true;
              }
            }
          });

          this.changeSelectListeer();
        }
      }

      async createData() {
        const jsonUrl = `${this.S3_BASE}/swatches/swatch_${this.clientId}.json`;
        this.debugLog(`[createData] Fetching swatch data from: ${jsonUrl}`);

        try {
          this.data = await this.getSwatches(jsonUrl);
          this.debugLog(
            `[createData] Successfully loaded ${this.data.length} swatch items`
          );

          this.fillSwatches();
        } catch (error) {
          this.debugLog(`[createData] Error loading swatch data:`, error);
        }
      }

      start() {
        this.getClientId();
        this.debugLog(
          "Swatch.js Р  РЎвЂР  Р вЂ¦Р  РЎвЂР РЋРІР‚ Р  РЎвЂР  Р’В°Р  Р’В»Р  РЎвЂР  Р’В·Р  РЎвЂР РЋР вЂљР  РЎвЂўР  Р вЂ Р  Р’В°Р  Р вЂ¦, Р  Р вЂ Р  Р’ВµР РЋР вЂљР РЋР С“Р  РЎвЂР РЋР РЏ:",
          this.version
        );
        this.createData();
        this.createStyles();

        if (document.querySelector("[data-collection-infinity]")) {
            const targetNode = document.querySelector("[data-collection-infinity]");

            const observer = new MutationObserver((mutationsList) => {

                for (let mutation of mutationsList) {
                    if (mutation.type === "childList" && mutation.addedNodes.length > 0) {
                        mutation.addedNodes.forEach((item) => {
                            if (item.tagName === "FORM") {
                                this.fillSwatches();
                            }
                        });
                    }
                }
            });

            observer.observe(targetNode, {
                attributes: true,
                childList: true,
                subtree: false
            });
        }

      }
    }

    const accountSwatches = new Swatches();

    accountSwatches.start();
  }

  // Execute immediately if DOM is ready, otherwise wait
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    // DOM already loaded, run immediately
    init();
  }
})();

