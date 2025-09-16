import { Controller } from "@hotwired/stimulus"

// Handles flash messages: auto-dismiss after a timeout and close on click.
// Usage in HTML:
// <div data-controller="flash"
//      data-flash-timeout-value="5000"
//      data-flash-auto-hide-value="true"
//      data-action="mouseenter->flash#pause mouseleave->flash#resume">
//   ...
//   <button data-action="flash#close">Close</button>
// </div>
export default class extends Controller {
  static values = {
    timeout: { type: Number, default: 5000 },
    autoHide: { type: Boolean, default: true }
  }

  connect() {
    // Animate in
    this._enter()

    // Start auto-hide timer if enabled
    if (this.autoHideValue && this.timeoutValue > 0) {
      this._startTimer()
    }
  }

  disconnect() {
    this._clearTimer()
  }

  close(event) {
    if (event) event.preventDefault()
    this._clearTimer()
    this._leave()
  }

  pause() {
    this._clearTimer()
  }

  resume() {
    if (!this._timeoutId && this.autoHideValue && this.timeoutValue > 0) {
      this._startTimer()
    }
  }

  // Private helpers
  _startTimer() {
    this._timeoutId = setTimeout(() => this._leave(), this.timeoutValue)
  }

  _clearTimer() {
    if (this._timeoutId) {
      clearTimeout(this._timeoutId)
      this._timeoutId = null
    }
  }

  _enter() {
    // Ensure enter transition starts from hidden state
    this.element.classList.add("transition", "ease-out", "duration-200")
    this.element.classList.add("opacity-0", "translate-y-2", "scale-95")
    // Next frame, set to visible state
    requestAnimationFrame(() => {
      this.element.classList.remove("opacity-0", "translate-y-2", "scale-95")
      this.element.classList.add("opacity-100", "translate-y-0", "scale-100")
    })
  }

  _leave() {
    // Animate out then remove element
    this.element.classList.add("transition", "ease-in", "duration-150")
    this.element.classList.remove("opacity-100", "translate-y-0", "scale-100")
    this.element.classList.add("opacity-0", "translate-y-2", "scale-95")

    const removeAfterTransition = () => {
      this.element.removeEventListener("transitionend", removeAfterTransition)
      this.element.remove()
    }
    this.element.addEventListener("transitionend", removeAfterTransition, { once: true })
  }
}
