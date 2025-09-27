import { Controller } from "@hotwired/stimulus"

// Generic nested fields controller
// data-nested-targets: template, wrapper, addButton
// data-nested-wrapper-class-value: classes to apply to wrapper
export default class extends Controller {
  static targets = ["template", "wrapper", "addButton"]
  static values = { wrapperClass: String }

  connect() {
    if (this.hasWrapperTarget && this.wrapperClassValue) {
      this.wrapperTarget.classList.add(...this.wrapperClassValue.split(" "))
    }
  }

  add(event) {
    event.preventDefault()
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, Date.now().toString())
    this.wrapperTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    event.preventDefault()
    const container = event.currentTarget.closest('[data-new-record], .p-2.border.rounded') || event.currentTarget.closest('[data-nested-item]')
    if (container) {
      const destroyInput = container.querySelector("input[type='checkbox'][name*='[_destroy]']")
      if (destroyInput) {
        // Mark for destruction and hide
        destroyInput.checked = true
        container.style.display = 'none'
      } else {
        container.remove()
      }
    }
  }
}


