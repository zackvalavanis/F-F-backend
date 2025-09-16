Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Frontend origin
    origins 'http://localhost:5173'  # <-- React dev server

    # Resources you allow to be accessed
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false
  end
end