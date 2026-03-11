import { Controller } from "@hotwired/stimulus"

// Canvas flowchart: SVG lines between blocks, zoom/pan
export default class extends Controller {
  static targets = ["svg", "canvas", "scroll", "viewport", "zoomLabel", "stepsContainer"]
  static values = {
    connections: Array,
  }

  connect() {
    this.scale = 0.8
    this.translateX = 0
    this.translateY = 0
    this.applyTransform()
    this.updateZoomLabel()
    this.drawLines()
    document.addEventListener("turbo:frame-render", this.boundRedraw)
    this.element.addEventListener("flowchart:redraw", this.boundRedraw)
  }

  disconnect() {
    document.removeEventListener("turbo:frame-render", this.boundRedraw)
    this.element.removeEventListener("flowchart:redraw", this.boundRedraw)
  }

  get boundRedraw() {
    if (!this._boundRedraw) {
      this._boundRedraw = () => this.drawLines()
    }
    return this._boundRedraw
  }

  zoomIn() {
    this.scale = Math.min(2, this.scale + 0.2)
    this.applyTransform()
    this.updateZoomLabel()
    this.drawLines()
  }

  zoomOut() {
    this.scale = Math.max(0.5, this.scale - 0.2)
    this.applyTransform()
    this.updateZoomLabel()
    this.drawLines()
  }

  applyTransform() {
    // Масштабируем canvas (контент), а не scroll — при zoom out видно больше блоков
    if (this.hasCanvasTarget) {
      this.canvasTarget.style.transform = `scale(${this.scale})`
      this.canvasTarget.style.transformOrigin = "0 0"
    }
  }

  updateZoomLabel() {
    if (this.hasZoomLabelTarget) {
      this.zoomLabelTarget.textContent = `${Math.round(this.scale * 100)}%`
    }
  }

  drawLines() {
    if (!this.hasSvgTarget || !this.connectionsValue?.length) return

    const container = this.hasStepsContainerTarget ? this.stepsContainerTarget : (this.hasCanvasTarget ? this.canvasTarget : this.element)
    const containerRect = container.getBoundingClientRect()
    // getBoundingClientRect возвращает масштабированные координаты; SVG использует логические пиксели
    const scale = this.scale || 1

    const getElement = (stepId) => {
      return document.querySelector(`[data-step-id="${stepId}"]`)
    }

    const lines = []
    for (const conn of this.connectionsValue) {
      const fromEl = getElement(conn.from)
      const toEl = getElement(conn.to)
      if (!fromEl || !toEl) continue

      const fromRect = fromEl.getBoundingClientRect()
      const toRect = toEl.getBoundingClientRect()

      // Координаты относительно контейнера, переведённые в логическое пространство SVG
      const rel = (v, base) => (v - base) / scale
      // Для условия: "false" (Нет) — слева, "true" (Да) — справа; иначе — по центру
      let fromX
      if (conn.branch === "false") {
        fromX = rel(fromRect.left, containerRect.left) + 24 / scale  // центр левой кнопки + (Нет)
      } else if (conn.branch === "true") {
        fromX = rel(fromRect.right, containerRect.left) - 24 / scale  // центр правой кнопки + (Да)
      } else {
        fromX = rel(fromRect.left, containerRect.left) + fromRect.width / 2 / scale
      }
      const fromY = rel(fromRect.bottom, containerRect.top)
      const toX = rel(toRect.left, containerRect.left) + toRect.width / 2 / scale
      const toY = rel(toRect.top, containerRect.top)

      const path = this.orthogonalPath(fromX, fromY, toX, toY)
      lines.push(`<path d="${path}" fill="none" stroke="#94a3b8" stroke-width="2" marker-end="url(#arrowhead)" />`)
    }

    this.svgTarget.innerHTML = `
      <defs>
        <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
          <polygon points="0 0, 10 3.5, 0 7" fill="#94a3b8" />
        </marker>
      </defs>
      ${lines.join("")}
    `
  }

  // Orthogonal path: vertical down from from, then horizontal, then vertical to to
  orthogonalPath(fromX, fromY, toX, toY) {
    const midY = (fromY + toY) / 2
    return `M ${fromX} ${fromY} L ${fromX} ${midY} L ${toX} ${midY} L ${toX} ${toY}`
  }
}
