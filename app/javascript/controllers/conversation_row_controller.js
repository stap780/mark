import { Controller } from "@hotwired/stimulus"

// Снимает подсветку «новое сообщение» и бейдж «Новое» через несколько секунд после появления.
export default class extends Controller {
  static values = { highlight: Boolean }
  static targets = ["badge"]

  connect() {
    if (!this.highlightValue) return
    this.removeHighlightAt = window.setTimeout(() => {
      this.element.classList.remove("conversation-row-new-message")
      if (this.hasBadgeTarget) {
        this.badgeTarget.style.display = "none"
      }
    }, 4000)
  }

  disconnect() {
    if (this.removeHighlightAt) {
      window.clearTimeout(this.removeHighlightAt)
    }
  }
}
