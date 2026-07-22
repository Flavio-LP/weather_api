# frozen_string_literal: true
module Api
  module V1
    class WhatsappController < ApplicationController
      skip_before_action :verify_authenticity_token, raise: false

      # POST /api/v1/whatsapp/send
      def send_message
        message  = params[:message].presence
        group_id = params[:group_id].presence

        unless message
          return render json: { error: 'Campo "message" é obrigatório' }, status: :unprocessable_entity
        end

        unless group_id
          return render json: { error: 'Campo "group_id" é obrigatório' }, status: :unprocessable_entity
        end

        url     = ENV.fetch("WHATSAPP_SERVICE_URL", "http://whatsapp:3001")
        payload = { message: message, group_id: group_id }

        response = HTTP.post("#{url}/send", json: payload)
        body     = JSON.parse(response.body.to_s, symbolize_names: true)

        if response.status.success?
          Rails.logger.info("[WhatsappController#send_message] Mensagem enviada (#{message.length} chars, group: #{body[:group]})")
          render json: body, status: :ok
        else
          Rails.logger.error("[WhatsappController#send_message] Falha #{response.status}: #{response.body}")
          render json: body, status: response.status.code
        end
      rescue => e
        Rails.logger.error("[WhatsappController#send_message] #{e.class}: #{e.message}")
        render json: { error: "Falha ao contatar o serviço WhatsApp", details: Rails.env.production? ? nil : e.message }.compact, status: :bad_gateway
      end
    end
  end
end
