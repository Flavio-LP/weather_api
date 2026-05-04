Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      get "climatempo/15dias/forquilhinha", to: "forecast#climatempo_15d"
    end
  end
end