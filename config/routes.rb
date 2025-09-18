Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "/recipes" => "recipes#index"
  get "/recipes/:id" => "recipes#show"
  patch "/recipes/:id" => "recipes#update"
  post "/recipes" => "recipes#create"
  delete "/recipes/:id" => "recipes#destroy"


    post "/users" => "users#create"



  # Defines the root path route ("/")
  # root "posts#index"

  root to: proc { [200, {}, ["Rails backend is running!"]] }
end
