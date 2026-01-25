import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="message-form"
export default class extends Controller {
  static targets = ["emailSubject"]

  connect() {
    this.updateFields()
  }

  channelChanged() {
    this.updateFields()
  }

  updateFields() {
    const channelSelect = this.element.querySelector('select[name="channel"]')
    if (!channelSelect) return
    
    const channel = channelSelect.value

    // Показываем/скрываем поле темы для email
    if (this.hasEmailSubjectTarget) {
      if (channel === 'email') {
        this.emailSubjectTarget.style.display = 'block'
        const input = this.emailSubjectTarget.querySelector('input')
        if (input) input.required = true
      } else {
        this.emailSubjectTarget.style.display = 'none'
        const input = this.emailSubjectTarget.querySelector('input')
        if (input) input.required = false
      }
    }
  }
}
