# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@rails/activestorage", to: "activestorage.esm.js"
pin "@rails/request.js", to: "https://cdn.jsdelivr.net/npm/@rails/request.js@0.0.9/src/index.js"
pin "sortablejs", to: "https://cdn.jsdelivr.net/npm/sortablejs@1.15.3/+esm" # @1.15.3

# Coloris color picker
pin "@melloware/coloris", to: "https://cdn.jsdelivr.net/npm/@melloware/coloris@0.24.0/+esm"

pin_all_from "app/javascript/controllers", under: "controllers"
