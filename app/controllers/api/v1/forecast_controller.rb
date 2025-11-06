module Api
  module V1
    class ForecastController < ApplicationController
      # Ex.: GET /api/v1/forecast?lat=-28.792868&lon=-49.492354
      def index
        lat = params[:lat]&.to_f
        lon = params[:lon]&.to_f

        # Validação simples
        if lat.nil? || lon.nil?
          return render json: { error: "Parâmetros 'lat' e 'lon' são obrigatórios" }, status: :bad_request
        end

        begin
          # Buscar dados meteorológicos
          weather_data = fetch_open_meteo(lat, lon)
          
          # Buscar cidade/estado via reverse geocoding
          location_data = fetch_location(lat, lon)

          daily = weather_data.fetch("daily", {})
          times = daily.fetch("time", [])
          tmax  = daily.fetch("temperature_2m_max", [])
          tmin  = daily.fetch("temperature_2m_min", [])
          wcode = daily.fetch("weathercode", [])

          result = []
          times.first(7).each_with_index do |day, i|
            code = wcode[i]
            result << {
              date: day,
              temp_min_c: tmin[i],
              temp_max_c: tmax[i],
              weather_code: code,
              weather_description: wmo_map[code] || "Desconhecido"
            }
          end

          render json: {
            location: {
              city: location_data[:city],
              state: location_data[:state],
              country: location_data[:country],
              latitude: weather_data["latitude"],
              longitude: weather_data["longitude"]
            },
            timezone: weather_data["timezone"],
            daily_forecast: result
          }, status: :ok
        rescue => e
          Rails.logger.error("[ForecastController] #{e.class}: #{e.message}")
          render json: { error: "Falha ao consultar serviço meteorológico" }, status: :bad_gateway
        end
      end

      private

      def fetch_open_meteo(lat, lon)
        base = "https://api.open-meteo.com/v1/forecast"
        daily_vars = %w[temperature_2m_max temperature_2m_min weathercode].join(",")
        url = "#{base}?latitude=#{lat}&longitude=#{lon}&daily=#{daily_vars}&timezone=auto"

        response = HTTP.timeout(connect: 5, write: 5, read: 10).get(url)
        raise "Open-Meteo HTTP #{response.status}" unless response.status.success?

        response.parse
      end

      def fetch_location(lat, lon)
        # Cache por 24 horas (coordenadas não mudam de localização)
        cache_key = "location:#{lat.round(4)}:#{lon.round(4)}"
        
        Rails.cache.fetch(cache_key, expires_in: 24.hours) do
          url = "https://nominatim.openstreetmap.org/reverse?lat=#{lat}&lon=#{lon}&format=json&accept-language=pt-BR"
          
          response = HTTP.headers("User-Agent" => "WeatherAPI/1.0 (contact@example.com)")
                         .timeout(connect: 5, write: 5, read: 10)
                         .get(url)
          
          raise "Nominatim HTTP #{response.status}" unless response.status.success?

          data = response.parse
          address = data.fetch("address", {})
          
          {
            city: address["city"] || address["town"] || address["village"] || address["municipality"] || "Desconhecida",
            state: address["state"] || "Desconhecido",
            country: address["country"] || "Desconhecido"
          }
        end
      rescue => e
        Rails.logger.warn("[ForecastController] Geocoding falhou: #{e.message}")
        # Fallback caso geocoding falhe
        {
          city: "Desconhecida",
          state: "Desconhecido",
          country: "Desconhecido"
        }
      end

      def wmo_map
        {
          0 => "Céu limpo",
          1 => "Principalmente limpo",
          2 => "Parcialmente nublado",
          3 => "Nublado",
          45 => "Nevoeiro",
          48 => "Nevoeiro com deposição",
          51 => "Garoa fraca",
          53 => "Garoa moderada",
          55 => "Garoa intensa",
          56 => "Garoa congelante fraca",
          57 => "Garoa congelante intensa",
          61 => "Chuva fraca",
          63 => "Chuva moderada",
          65 => "Chuva forte",
          66 => "Chuva congelante fraca",
          67 => "Chuva congelante forte",
          71 => "Neve fraca",
          73 => "Neve moderada",
          75 => "Neve forte",
          77 => "Grãos de neve",
          80 => "Aversas fracas",
          81 => "Aversas moderadas",
          82 => "Aversas fortes",
          85 => "Aversas de neve fracas",
          86 => "Aversas de neve fortes",
          95 => "Trovoadas",
          96 => "Trovoadas com granizo leve",
          99 => "Trovoadas com granizo forte"
        }
      end
    end
  end
end