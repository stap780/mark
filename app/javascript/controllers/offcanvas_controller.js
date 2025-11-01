import { Controller } from "@hotwired/stimulus"

// Slide-over controller that searches inside the :offcanvas frame for
// elements marked with data-offcanvas-backdrop and data-offcanvas-panel.
// This lets each view provide its own backdrop/panel markup.
export default class extends Controller {
	connect() {
		this._closing = false
		this._frame = this.element // <turbo-frame id="offcanvas">

		this._observer = new MutationObserver(() => this._sync())
		this._observer.observe(this._frame, { childList: true, subtree: true })

		this._beforeRender = (e) => {
			if (e.target === this._frame) this._deferOpen()
		}
		this._afterLoad = (e) => {
			if (e.target === this._frame) this._deferOpen()
		}
		addEventListener("turbo:before-frame-render", this._beforeRender)
		addEventListener("turbo:frame-load", this._afterLoad)

		this._sync()
	}

	disconnect() {
		this._observer?.disconnect()
		removeEventListener("turbo:before-frame-render", this._beforeRender)
		removeEventListener("turbo:frame-load", this._afterLoad)
	}

	_query() {
		this._backdrop = this._frame.querySelector("[data-offcanvas-backdrop]")
		this._panel = this._frame.querySelector("[data-offcanvas-panel]")
	}

	_deferOpen() {
		requestAnimationFrame(() => this.open())
	}

	open() {
		this._query()
		if (!this._panel || !this._backdrop) return

		this._backdrop.classList.remove("hidden")
		requestAnimationFrame(() => this._backdrop.classList.remove("opacity-0"))
		// Remove both translate classes to support left and right panels
		this._panel.classList.remove("translate-x-full")
		this._panel.classList.remove("-translate-x-full")
	}

	close() {
		if (this._closing) return
		this._closing = true
		this._query()
		if (!this._panel || !this._backdrop) {
			this._closing = false
			return
		}

		// Check if panel is on left or right side
		if (this._panel.classList.contains("left-0")) {
			this._panel.classList.add("-translate-x-full")
		} else {
			this._panel.classList.add("translate-x-full")
		}
		this._backdrop.classList.add("opacity-0")

		setTimeout(() => {
			this._backdrop.classList.add("hidden")
			// Clear frame content; server can also clear via turbo_stream.update(:offcanvas, "")
			if (this._frame.innerHTML.trim().length > 0) this._frame.innerHTML = ""
			this._closing = false
		}, 250)
	}

	_sync() {
		const hasContent = this._frame.innerHTML.trim().length > 0
		if (hasContent) this.open()
	}
}
