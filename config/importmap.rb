# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@rails/activestorage", to: "activestorage.esm.js"
pin "@rails/request.js", to: "@rails--request.js.js" # @0.0.13
pin "sortablejs" # @1.15.7

# Coloris color picker
pin "@melloware/coloris", to: "@melloware--coloris.js" # @0.25.0
pin "chart.js", to: "https://esm.sh/chart.js@4.5.1", preload: true
pin "@kurkle/color", to: "@kurkle--color.js" # @0.3.4
pin "@stimulus-components/chartjs", to: "@stimulus-components--chartjs.js" # @6.0.1

pin_all_from "app/javascript/controllers", under: "controllers"
