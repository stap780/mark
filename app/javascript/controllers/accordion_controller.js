import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "arrow"]
  static values = { open: Boolean }

  toggle() {
    const isHidden = this.contentTarget.classList.contains("hidden")
    
    if (isHidden) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.contentTarget.classList.remove("hidden")
    this.arrowTarget.style.transform = "rotate(180deg)"
    this.openValue = true
  }

  close() {
    this.contentTarget.classList.add("hidden")
    this.arrowTarget.style.transform = "rotate(0deg)"
    this.openValue = false
  }

  connect() {
    // Если есть значение open, открываем аккордеон
    if (this.openValue) {
      this.open()
    } else {
      this.close()
    }
  }
}
