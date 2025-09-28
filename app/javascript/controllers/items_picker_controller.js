import { Controller } from "@hotwired/stimulus"

// Search items from Insales products XML and dispatch add events to the main form bucket
export default class extends Controller {
  static targets = ["input", "results"]

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
      <div class="flex items-center justify-between p-2 border rounded">
        <div class="flex items-center space-x-2">
          <img src="${i.image_link || ''}" class="h-8 w-8 object-cover rounded" onerror="this.style.display='none'">
          <span class="text-sm">${i.title}${i.price ? ` · ${i.price}` : ''}</span>
        </div>
        <button type="button" class="px-2 py-1 text-sm rounded-md border hover:bg-gray-50"
                data-offer-id="${i.offer_id}" data-group-id="${i.group_id}" data-title="${i.title}" data-image="${i.image_link}" data-price="${i.price || ''}"
                data-action="click->items-picker#add">Add item</button>
      </div>
    `).join('')
  }

  add(event) {
    const { offerId, groupId, title, image, price } = event.currentTarget.dataset
    const detail = { offer_id: offerId, group_id: groupId, title: title, image_link: image, price: price }
    const ev = new CustomEvent('items-bucket:add', { detail, bubbles: true })
    document.dispatchEvent(ev)
  }
}


