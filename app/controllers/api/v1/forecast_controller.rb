# frozen_string_literal: true
module Api
  module V1
    class ForecastController < ApplicationController
      skip_before_action :verify_authenticity_token, raise: false

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

      # POST /api/v1/forecast/send_whatsapp
      def send_whatsapp
        cache_key = "climatempo:15d:#{Digest::SHA1.hexdigest([ClimatempoScraper::DEFAULT_URL, 'Forquilhinha', 'SC'].join('|'))}"
        data = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
          ClimatempoScraper.fetch_15_days
        end

        return render json: { error: "Nenhum dado de previsao disponivel" }, status: :unprocessable_entity if data[:days].blank?

        body   = ForecastWhatsappFormatter.format(data, days_count: 10)
        result = TwilioWhatsappService.send_message(body:)

        render json: { sent: true, sid: result[:sid], days_sent: [data[:days].size, 10].min, message_length: body.length }, status: :ok

      rescue TwilioWhatsappService::ConfigurationError => e
        render json: { error: "Configuracao Twilio invalida", details: Rails.env.production? ? nil : e.message }.compact, status: :service_unavailable
      rescue TwilioWhatsappService::DeliveryError => e
        render json: { error: "Falha ao enviar WhatsApp", details: Rails.env.production? ? nil : e.message }.compact, status: :bad_gateway
      rescue => e
        Rails.logger.error("[ForecastController#send_whatsapp] #{e.class}: #{e.message}")
        render json: { error: "Erro interno", details: Rails.env.production? ? nil : e.message }.compact, status: :internal_server_error
      end
    end
  end
end
