import { Controller } from "@hotwired/stimulus"

// Updates a hidden input in the parent form and closes the offcanvas
export default class extends Controller {
  static values = { field: String }

  choose(event) {
    const value = event.params.value
    const field = this.fieldValue || 'product_page_style'

    // Find the form on the page (the swatch group form is visible underneath the offcanvas)
    const form = document.querySelector("form[action*='/swatch_groups']")
    if (!form) return

    // Ensure a hidden input exists for the field and set the value
    let input = form.querySelector(`[name='swatch_group[${field}]']`)
    if (!input) {
      input = document.createElement('input')
      input.type = 'hidden'
      input.name = `swatch_group[${field}]`
      form.appendChild(input)
    }
    input.value = value

    // Update the summary text if present
    const summary = form.querySelector(`#summary_${field}`)
    if (summary) summary.textContent = value

    // Close the offcanvas by clearing the frame
    const frame = document.getElementById('offcanvas')
    if (frame) frame.innerHTML = ''
  }

  close() {
    const frame = document.getElementById('offcanvas')
    if (frame) frame.innerHTML = ''
  }
}


