import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "arrow"]

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
  }

  close() {
    this.contentTarget.classList.add("hidden")
    this.arrowTarget.style.transform = "rotate(0deg)"
  }

  connect() {
    // По умолчанию закрыт
    this.close()
  }
}
