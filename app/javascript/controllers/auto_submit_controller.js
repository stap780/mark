import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 350 } }

  connect() {
    this.isSubmitting = false
    this.timer = null
    this.onInputBound = this.onInput.bind(this)
    this.element.addEventListener("input", this.onInputBound)
    this.element.addEventListener("change", this.onInputBound)
  }

  disconnect() {
    this.element.removeEventListener("input", this.onInputBound)
    this.element.removeEventListener("change", this.onInputBound)
    if (this.timer) clearTimeout(this.timer)
  }

  onInput(event) {
    // Игнорируем автосабмит для полей с атрибутом data-auto-submit-ignore
    if (event.target.hasAttribute('data-auto-submit-ignore')) {
      return
    }
    
    if (this.timer) clearTimeout(this.timer)
    this.timer = setTimeout(() => this.submit(), this.delayValue)
  }

  submit() {
    if (this.isSubmitting) return
    this.isSubmitting = true
    this.element.requestSubmit()
    setTimeout(() => { this.isSubmitting = false }, 300)
  }
}


