import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  add(event) {
    event.preventDefault()
    const content = this.templateTarget.innerHTML
    const newIndex = Date.now()
    const newContent = content.replace(/NEW_RECORD/g, newIndex)
    this.containerTarget.insertAdjacentHTML('beforeend', newContent)
    // Обновляем видимость полей для нового элемента
    const newItem = this.containerTarget.lastElementChild
    if (newItem) {
      const kindSelect = newItem.querySelector('select[name*="[kind]"]')
      if (kindSelect) {
        this.updateActionKindForItem(newItem, kindSelect.value)
      }
    }
  }

  remove(event) {
    event.preventDefault()
    const item = event.currentTarget.closest('[data-nested-form-item]')
    const destroyInput = item.querySelector('input[name*="[_destroy]"]')
    if (destroyInput) {
      destroyInput.value = '1'
      item.style.display = 'none'
    } else {
      item.remove()
    }
  }

  updateActionKind(event) {
    const item = event.currentTarget.closest('[data-nested-form-item]')
    if (item) {
      const kind = event.currentTarget.value
      this.updateActionKindForItem(item, kind)
    }
  }

  updateActionKindForItem(item, kind) {
    item.querySelectorAll('[data-action-kind]').forEach(block => {
      const blockKind = block.dataset.actionKind
      block.style.display = blockKind === kind ? 'block' : 'none'
    })
  }
}

