import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = [ 'position', 'hposition' ]

  connect() {
    // console.log('Sortable controller connected', this.element)
    // console.log('Looking for handles:', this.element.querySelectorAll('.js-sort-handle'))
    
    this.sortable = new Sortable(this.element, {
      handle: '.js-sort-handle',
      animation: 150,
      onEnd: async (e) => {
        console.log('Sort ended', e)
        try {
          this.disable()
          const url = e.item.dataset.sortUrl;
          
          const response = await fetch(url, {
            method: 'PATCH',
            headers: {
              'Content-Type': 'application/json',
              'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
            },
            body: JSON.stringify({
              position: e.newIndex + 1
            })
          })
          
          if(!response.ok) {
            this.updatePositions();
            throw new Error(`Cannot sort on server: ${response.status}`)
          }
          
          this.updatePositions()
          this.dispatch('move', { detail: { content: 'Item sorted' } })
        } catch(error) {
          console.error('Sort error:', error)
        } finally {
          this.enable()
        }
      }
    })
  }

  disable() {
    this.sortable.option('disabled', true)
    this.element.classList.add('opacity-50')
  }

  enable() {
    this.sortable.option('disabled', false)
    this.element.classList.remove('opacity-50')
  }

  updatePositions() {
    this.positionTargets.forEach((position, index) => {
      position.innerText = index + 1
    })
    
    if (this.hasHpositionTarget) {
      this.hpositionTargets.forEach((position, index) => {
        position.value = index + 1
      })
    }
  }
}

