import { Controller } from "@hotwired/stimulus"

// Прокручивает контейнер вниз при появлении и при добавлении новых сообщений (Turbo Stream).
// Вешать на элемент с overflow-y-auto.
export default class extends Controller {
  connect() {
    this.scrollToBottom()
    this.observeNewContent()
  }

  disconnect() {
    this.observer?.disconnect()
  }

  scrollToBottom() {
    requestAnimationFrame(() => {
      this.element.scrollTop = this.element.scrollHeight
    })
  }

  observeNewContent() {
    this.observer = new MutationObserver(() => {
      this.scrollToBottom()
    })
    this.observer.observe(this.element, { childList: true, subtree: true })
  }
}
