Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # GET /api/v1/forecast?lat=-28.79&lon=-49.49
      get "forecast", to: "forecast#index"
      get 'weather_google', to: 'weather_google#fetch_weather'
    end
  end
end

