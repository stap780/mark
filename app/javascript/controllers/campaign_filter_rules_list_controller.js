import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  removeRow(event) {
    event.preventDefault()
    const frame = event.currentTarget.closest("turbo-frame")
    frame?.remove()
  }
}
