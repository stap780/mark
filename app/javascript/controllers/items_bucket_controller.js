import { Controller } from "@hotwired/stimulus"

// Holds selected items in hidden fields inside the swatch_group form
export default class extends Controller {
  static targets = ["list"]

  connect() {
    this._onAdd = (e) => this._addItem(e.detail)
    document.addEventListener('items-bucket:add', this._onAdd)
  }

  disconnect() {
    document.removeEventListener('items-bucket:add', this._onAdd)
  }

  _addItem({ offer_id, title, image_link, price }) {
    const index = this._nextIndex()
    const container = document.createElement('div')
    container.className = 'flex items-center justify-between p-2 border rounded'
    container.innerHTML = `
      <div class="flex items-center space-x-2">
        <img src="${image_link || ''}" class="h-8 w-8 object-cover rounded" onerror="this.style.display='none'">
        <span class="text-sm">${title}${price ? ` · ${price}` : ''}</span>
      </div>
      <button type="button" class="text-red-600 text-sm" data-action="click->items-bucket#remove">Remove</button>
      <input type="hidden" name="swatch_group[selected_items][${index}][offer_id]" value="${offer_id}">
      <input type="hidden" name="swatch_group[selected_items][${index}][title]" value="${title}">
      <input type="hidden" name="swatch_group[selected_items][${index}][image_link]" value="${image_link || ''}">
      <input type="hidden" name="swatch_group[selected_items][${index}][price]" value="${price || ''}">
    `
    this.listTarget.appendChild(container)
  }

  remove(event) {
    event.currentTarget.parentElement.remove()
  }

  _nextIndex() {
    return this.listTarget.children.length
  }
}


