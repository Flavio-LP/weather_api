# frozen_string_literal: true
module Api
  module V1
    class ForecastController < ApplicationController
      # GET /api/v1/climatempo/15dias/forquilhinha
      # Opcional: aceita query params ?url=...&city=...&state=...
      def climatempo_15d
        url   = params[:url].presence   || "https://www.climatempo.com.br/previsao-do-tempo/15-dias/cidade/4598/forquilhinha-sc"
        city  = params[:city].presence  || "Forquilhinha"
        state = params[:state].presence || "SC"

        # Cache simples de 30 minutos para reduzir chamadas ao site
        cache_key = "climatempo:15d:#{Digest::SHA1.hexdigest([url, city, state].join('|'))}"
        data = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
          ClimatempoScraper.fetch_15_days(url:, city:, state:)
        end

        render json: data, status: :ok
      rescue => e
        Rails.logger.error("[ForecastController#climatempo_15d] #{e.class}: #{e.message}")
        render json: { error: "Falha ao obter dados da Climatempo", details: Rails.env.production? ? nil : e.message }.compact, status: :bad_gateway
      end
    end
  end
end