import { Controller } from "@hotwired/stimulus"

// Fetches products from Insales products_search and writes selection into form fields
export default class extends Controller {
  static targets = ["input", "results", "selected"]

  connect() {
    this._debounceTimer = null
  }

  search() {
    clearTimeout(this._debounceTimer)
    this._debounceTimer = setTimeout(() => this._perform(), 250)
  }

  _perform() {
    const q = this.inputTarget.value
    const url = this.element.dataset.searchUrl
    fetch(`${url}?q=${encodeURIComponent(q)}`, { headers: { 'Accept': 'application/json' }})
      .then(r => r.json())
      .then(items => this._render(items))
  }

  _render(items) {
    this.resultsTarget.innerHTML = items.map(i => `
      <button type="button" data-offer-id="${i.offer_id}" data-title="${i.title}" data-image="${i.image_link}" data-price="${i.price || ''}"
              class="w-full flex items-center space-x-2 p-2 border rounded hover:bg-gray-50"
              data-action="click->product-picker#choose">
        <img src="${i.image_link || ''}" class="h-8 w-8 object-cover rounded" onerror="this.style.display='none'">
        <span class="text-sm">${i.title}${i.price ? ` · ${i.price}` : ''}</span>
      </button>
    `).join('')
  }

  choose(event) {
    const { offerId, title, image, price } = event.currentTarget.dataset
    // Prefer the swatch_group_products form within the offcanvas
    let form = this.element.parentElement?.querySelector("form[action*='swatch_group_products']")
    if (!form) {
      // Fallback: any form targeting swatch_group_products
      form = document.querySelector("form[action*='swatch_group_products']")
    }
    if (!form) return
    this._setHidden(form, 'external_offer_id', offerId)
    this._setHidden(form, 'external_title', title)
    this._setHidden(form, 'external_image', image)
    this._setHidden(form, 'external_price', price)

    if (this.hasSelectedTarget) {
      this.selectedTarget.innerHTML = `
        <div class="mt-2 flex items-center space-x-2 text-sm">
          <img src="${image || ''}" class="h-8 w-8 object-cover rounded" onerror="this.style.display='none'">
          <span>Selected: ${title}${price ? ` · ${price}` : ''}</span>
        </div>
      `
    }
  }

  _setHidden(form, name, value) {
    let input = form.querySelector(`[name='${name}']`)
    if (!input) {
      input = document.createElement('input')
      input.type = 'hidden'
      input.name = name
      form.appendChild(input)
    }
    input.value = value || ''
  }
}


