import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "trigger"]

  connect() {
    if (this.hasContentTarget) {
      this.contentTarget.style.display = "none"
    }
  }

  toggle() {
    if (this.hasContentTarget) {
      const isHidden = this.contentTarget.style.display === "none"
      this.contentTarget.style.display = isHidden ? "block" : "none"
    }
  }
}

