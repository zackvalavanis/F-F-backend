# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:5173', 
            'https://f-f-frontend-kjo44jv6e-zackvalavanis-projects.vercel.app',
            'https://f-f-frontend.vercel.app'   # add this one too

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false
  end
end
