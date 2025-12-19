import { Controller } from "@hotwired/stimulus"
import Coloris from "@melloware/coloris"

export default class extends Controller {
  static targets = ["input"]
  static values = { 
    alpha: { type: Boolean, default: true },
    theme: { type: String, default: "default" },
    themeMode: { type: String, default: "light" }
  }

  connect() {

    // Инициализируем Coloris глобально один раз
    if (!Coloris._initialized) {
      Coloris.init()
      Coloris._initialized = true
    }

    // Используем requestAnimationFrame для гарантии, что DOM готов
    requestAnimationFrame(() => {
      this.initColoris()
    })
  }

  initColoris() {
    this.inputTargets.forEach((input) => {
      // Проверяем, что элемент существует и в DOM
      if (!input || !input.isConnected || !document.contains(input)) {
        return
      }

      const options = {
        alpha: this.alphaValue,
        theme: this.themeValue,
        themeMode: this.themeModeValue,
        format: 'mixed',
        formatToggle: true,
        swatches: [
          '#A0AEC0',
          '#F56565',
          '#ED8936',
          '#ECC94B',
          '#48BB78',
          '#38B2AC',
          '#4299E1',
          '#667EEA',
          '#9F7AEA',
          '#ED64A6',
        ]
      }

      try {
        // Передаем элемент напрямую, а не селектор
        Coloris({
          el: input,
          ...options
        })

        // Обработчик изменения цвета
        input.addEventListener('change', (e) => {
          e.target.dispatchEvent(new Event('input', { bubbles: true }))
        })
      } catch (error) {
        console.error('Failed to initialize Coloris for input:', input, error)
      }
    })
  }

  disconnect() {
    // Coloris автоматически очищается при удалении элемента
  }
}

