import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "content"]

  connect() {
    // Show the first tab by default
    if (this.tabTargets.length > 0) {
      this.showTab(this.tabTargets[0])
    }
  }

  select(event) {
    event.preventDefault()
    this.showTab(event.currentTarget)
  }

  showTab(selectedTab) {
    // Update tab appearance
    this.tabTargets.forEach(tab => {
      const isActive = tab === selectedTab
      tab.classList.toggle("border-indigo-500", isActive)
      tab.classList.toggle("text-indigo-600", isActive)
      tab.classList.toggle("border-transparent", !isActive)
      tab.classList.toggle("text-gray-500", !isActive)
    })

    // Show/hide content
    this.contentTargets.forEach(content => {
      const isActive = content.dataset.tab === selectedTab.dataset.tab
      content.classList.toggle("hidden", !isActive)
    })
  }
}
