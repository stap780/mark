/**
 * Swatch.js - Объединение товаров
 * Версия: 1.0.1
 * Дата: 2024-01-15
 * Автор: Teletri Team
 * Описание: Скрипт для отображения объединенных товаров (swatches) на страницах интернет-магазинов
 */

document.addEventListener("DOMContentLoaded", () => {
    class Swatches {
      constructor() {
        this.version = "1.0.1";
        this.status = false;
        this.S3_BASE =
          "https://s3.twcstorage.ru/ae4cd7ee-b62e0601-19d6-483e-bbf1-416b386e5c23";
        this.clientId = "";
        this.data = '';
  
      }
  
  
      debugLog() {
          if (!this.status) return;
          try { console.log('[swatch v' + this.version + ']', ...arguments); } catch(e) { /* noop */ }
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
  
              if (id)  {
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
  
          if (document.querySelector(`.product-preview[data-product-id="${theId}"]`)) {
              productsStatus = true;
          }
  
          return productsStatus;
      }
  
      createSwatches(items, classMb, classMd) {
          let list = '';
        
          if (classMd.includes('dropdown')) {
              let options = '';
  
              items.swatches.forEach( opt => {
                  options += `<option value="${opt.link}" selected>${opt.label}</option>`;
              })
  
              list = `
                  <select name="select" class='product__props__select ${classMb} ${classMd}'>
                      ${options}
                  </select>
              `;
          } else {
              items.swatches.forEach( item => {
                  let image = '';
                  
                  if (items.product_page_image_source != '' && items.product_page_image_source != 'custom_color_image') {
                      if (items.product_page_image_source == "last_product_image") {
                          image = item.images[-1];
                          this.debugLog(item.images[-1], 'image')
                      } else if (items.product_page_image_source == "second_product_image" && item.images.length > 1) {
                          this.debugLog(item.images[1], 'image')
                          image = item.images[1];
                      } else if (items.product_page_image_source == "second_product_image" && item.images.length == 1) {
                          this.debugLog(item.images[0], 'image')
                          image = item.images[0];
                      } else if (items.product_page_image_source == "first_product_image" ) {
                           this.debugLog(item.images[0], 'image')
                          image = item.images[0];
                      } 
                  }
  
                  if (items.product_page_image_source == 'custom_color_image' && item.picture) {
                      image = item.picture;
                  }
  
                  this.debugLog(image, 'image')
  
                  if (image) {
                      image = `
                          <img src='${image}' title="${item.label}">
                      `;
                  } else {
                      if(item.color ) {
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
                      <a href="${item.link}" class='product__props__item ${classMb} ${classMd}' title="${item.label}"> 
                          ${image}
                      </a>
                  `;
              })
           }
  
          return list;
      }
  
      createItemsList(data, itemCls) {
          const itemMdClass = data.product_page_style;
          const itemMbClass = data.product_page_style_mob;
          const rowClass = 'is-row'
  
          let propsList = '';
          let items = '';
  
          if (data.swatches.length) {
              items = this.createSwatches(data, itemMbClass, itemMdClass);
          }
  
          propsList = `
              <div class='product__props__list is-list-${itemMdClass}'>
                  ${items}
              </div>
          `;
  
          return propsList;
      }
  
      addBlockToProductItem(blockData) {
  
          if (document.querySelector('.product__variants')) {
              const beforeBlock =  document.querySelector('.product__variants');
              const parentBlock = beforeBlock.parentNode;
  
              parentBlock.insertBefore(blockData, beforeBlock);
              
  
          } else if (document.querySelector('.product__title')) {
              const beforeBlock = document.querySelector('.product__title');
              const parentBlock = beforeBlock.parentNode;
  
              parentBlock.append(blockData)
          }
  
  
      }
  
      selectListener(parentBlock) {
          this.debugLog(parentBlock, 'propsWrapper')
          if(parentBlock.querySelector('.product__props__select')) {
              const selects = parentBlock.querySelectorAll('.product__props__select');
  
              selects.forEach( item => {
                  item.addEventListener('change', (e) => {
                      
                      window.location = item.value;
                  })
              })
          }
      }
  
      fillProduct(data) {
          const productItem = document.querySelector(`.product[data-product-id="${data.product_id}"]`);
          const propsWrapper = document.createElement('div');
          const propsItemsList = this.createItemsList(data);
          propsWrapper.classList.add('product__props__block');
  
          propsWrapper.innerHTML = `
              <span class='product__props__title option-label'>${data.option_name}</span>
              ${propsItemsList}
          `;
  
          this.addBlockToProductItem(propsWrapper);
  
          this.selectListener(propsWrapper);
      }
  
      fillPreviews(data) {
          const previewItems = document.querySelectorAll(`.product-preview[data-product-id="${data.product_id}"]`);
      }
  
      changeSelectListeer() {
          if (document.querySelector('.product__props__select')) {
              const linkSelects = document.querySelectorAll('.product__props__select');
  
              linkSelects.forEach( selectItem => {
                  selectItem.addEventListener('change', (e) => {
                      this.debugLog(selectItem.value)
                  })
              })
          }
      }
  
      createStyles() {
          const styleTag = document.createElement('style');
  
          styleTag.innerHTML = `
              .product__props__list {
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
  
              .product__props__item {
                  cursor: pointer;
                  text-decoration: none;
                  display: -webkit-box;
                  display: -ms-flexbox;
                  display: flex;
              }
  
              .product__props__title {
                  display: block;
                  line-height: 1.2;
                  margin-bottom: 10px;
                  color: var(--color-text-major-shade);
              }
  
              .product__props__item.circular_small_desktop,
              .product__props__item.circular_medium_desktop,
              .product__props__item.circular_large_desktop,
              .product__props__item.circular_small_mobile,
              .product__props__item.circular_medium_mobile,
              .product__props__item.circular_large_desktop {
                  border-radius: 50%;
                  overflow: hidden;
              }
  
              .product__props__item.circular_small_desktop {
                  width: 20px;
                  height: 20px;
              }
  
              .product__props__item.circular_medium_desktop {
                  width: 32px;
                  height: 32px;
              }
  
              .product__props__item.circular_large_desktop {
                  width: 48px;
                  height: 48px;
              }
  
              .product__props__item.square_desktop_small,
              .product__props__item.square_desktop_medium,
              .product__props__item.square_desktop_small,
              .product__props__item.square_mobile_medium,
              .product__props__item.square_mobile_large,
              .product__props__item.square_desktop_large {
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
  
              .product__props__item.square_desktop_small {
                  height: 20px;
                  font-size: 14px;
                  line-height: 18px;
                  min-width: 20px;
              }
  
              .product__props__item.square_desktop_medium {
                  height: 32px;
                  font-size: 16px;
                  line-height: 30px;
                  min-width: 32px;
              }
  
              .product__props__item.square_desktop_large {
                  height: 48px;
                  font-size: 18px;
                  line-height: 46px;
                  min-width: 48px;
              }
  
              .product__props__item span,
              .product__props__item img {
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
  
              .product__props__item img {
                  object-fit: cover;
              }
  
              .product__props__block {
                  margin: 0 0 1rem 0;
              }
  
              .product__props__select {
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
  
              .product__props__select.dropdown_label_small {
                  height: 20px;
                  font-size: 12px;
                  line-height: 14px;
              }
  
              .product__props__select.dropdown_label_medium {
                  height: 32px;
                  font-size: 16px;
                  line-height: 18px;
              }
  
              .product__props__select.dropdown_label_large {
                  height: 48px;
                  font-size: 18px;
                  line-height: 20px;
              }
  
              @media screen and (max-width: 767px) {
                  .product__props__item.circular_small_mobile {
                      width: 14px;
                      height: 14px;
                  }
  
                  .product__props__item.circular_medium_mobile {
                      width: 24px;
                      height: 24px;
                  }
  
                  .product__props__item.circular_large_mobile {
                      width: 36px;
                      height: 36px;
                  }
  
                  .product__props__item.square_desktop_small {
                      height: 16px;
                      font-size: 12px;
                      line-height: 16px;
                      min-width: 16px;
                  }
  
                  .product__props__item.square_mobile_medium {
                      height: 24px;
                      font-size: 14px;
                      line-height: 22px;
                      min-width: 24px;
                  }
                  .product__props__item.square_mobile_large {
                      height: 36px;
                      font-size: 18px;
                      line-height: 36px;
                      min-width: 36px;
                  }
                  .product__props__select.dropdown_label_medium {
                      height: 24px;
                      font-size: 14px;
                      line-height: 16px;
                  }
                  .product__props__select.dropdown_label_large {
                      height: 36px;
                      font-size: 18px;
                      line-height: 20px;
                  }
              }
          `;
  
          document.body.append(styleTag)
      }
  
      fillSwatches() {
          if (this.data.length) {
  
              this.data.forEach( item => {
                   let productStatus = this.checkProduct(item.product_id)
                   let previewStatus = this.checkPreviewStatus(item.product_id);
  
                  if(productStatus) {
                      this.fillProduct(item)
                  }
  
                  if (previewStatus ) {
                      this.fillPreviews(item)
                  }
              })
  
              this.changeSelectListeer();
          }
      }
  
      async createData() {
          const jsonUrl = `${this.S3_BASE}/swatches/swatch_${this.clientId}.json`;
          this.data  = await this.getSwatches(jsonUrl);
  
          this.fillSwatches()
      }
  
  
      start() {
          this.getClientId();
          this.debugLog('Swatch.js инициализирован, версия:', this.version);
          this.createData();
          this.createStyles();
      }
    }
  
    const accountSwatches = new Swatches();
  
    accountSwatches.start();
  });
  
  