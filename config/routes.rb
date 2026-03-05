Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get "climatempo/15dias/forquilhinha", to: "forecast#climatempo_15d"
      post "forecast/send_whatsapp", to: "forecast#send_whatsapp"
    end
  end
end