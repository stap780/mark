import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output"]

  static values = {
    url: String
  }

  async fetchCount(event) {
    event.preventDefault()

    const form = this.element.closest("form")
    if (!form) return

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    this.outputTarget.textContent = "…"

    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": token
      },
      body: new FormData(form),
      credentials: "same-origin"
    })

    if (!response.ok) {
      this.outputTarget.textContent = "—"
      return
    }

    const data = await response.json()
    this.outputTarget.textContent = data.count ?? "—"
  }
}
