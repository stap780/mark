import { Controller } from "@hotwired/stimulus"

// Перетаскивание блоков на canvas
export default class extends Controller {
  static values = {
    stepId: Number,
    updateUrl: String,
  }

  connect() {
    this.container = this.element.closest("[data-flowchart-target='stepsContainer']") || this.element.parentElement?.closest(".absolute") || document.body
    this.isDragging = false
    this.startX = 0
    this.startY = 0
    this.initialLeft = 0
    this.initialTop = 0

    this.boundMouseDown = this.onMouseDown.bind(this)
    this.boundMouseMove = this.onMouseMove.bind(this)
    this.boundMouseUp = this.onMouseUp.bind(this)

    this.element.addEventListener("mousedown", this.boundMouseDown)
    this.element.style.cursor = "grab"
  }

  disconnect() {
    this.element.removeEventListener("mousedown", this.boundMouseDown)
    document.removeEventListener("mousemove", this.boundMouseMove)
    document.removeEventListener("mouseup", this.boundMouseUp)
  }

  onMouseDown(e) {
    if (!e.target.closest("a, button")) {
      e.preventDefault()
      this.isDragging = true
      this.startX = e.clientX
      this.startY = e.clientY
      this.initialLeft = parseFloat(this.element.style.left) || 0
      this.initialTop = parseFloat(this.element.style.top) || 0
      this.element.style.cursor = "grabbing"
      this.element.style.zIndex = "10"
      document.addEventListener("mousemove", this.boundMouseMove)
      document.addEventListener("mouseup", this.boundMouseUp)
    }
  }

  onMouseMove(e) {
    if (!this.isDragging) return
    const dx = e.clientX - this.startX
    const dy = e.clientY - this.startY
    this.element.style.left = `${this.initialLeft + dx}px`
    this.element.style.top = `${this.initialTop + dy}px`
    this.element.dispatchEvent(new CustomEvent("flowchart:redraw", { bubbles: true }))
  }

  onMouseUp() {
    if (!this.isDragging) return
    this.isDragging = false
    this.element.style.cursor = "grab"
    this.element.style.zIndex = ""
    document.removeEventListener("mousemove", this.boundMouseMove)
    document.removeEventListener("mouseup", this.boundMouseUp)

    const left = Math.round(parseInt(this.element.style.left) || 0)
    const top = Math.round(parseInt(this.element.style.top) || 0)
    this.savePosition(left, top)
  }

  async savePosition(canvasX, canvasY) {
    const url = this.updateUrlValue
    if (!url) return

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const response = await fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": csrfToken || "",
      },
      body: JSON.stringify({ canvas_x: canvasX, canvas_y: canvasY }),
    })

    if (response.ok) {
      const contentType = response.headers.get("content-type")
      if (contentType?.includes("text/vnd.turbo-stream.html")) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }
    }
  }
}
