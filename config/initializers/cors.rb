Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*' # or set your storefront origins, e.g. 'yourstore.myinsales.ru'
    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :delete, :options],
      max_age: 600
  end
end