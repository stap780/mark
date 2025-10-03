import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileInput"];
  connect() {}

  trigger() {
    this.element.querySelector("input[type=file]").click();
  }
}

