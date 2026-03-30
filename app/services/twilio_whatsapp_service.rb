# frozen_string_literal: true

class TwilioWhatsappService
  class ConfigurationError < StandardError; end
  class DeliveryError < StandardError; end

  def self.send_message(body:)
    new.send_message(body:)
  end

  def initialize
    @account_sid = fetch_env!("TWILIO_ACCOUNT_SID")
    @auth_token  = fetch_env!("TWILIO_AUTH_TOKEN")
    @from        = fetch_env!("TWILIO_FROM")
    @to          = fetch_env!("TWILIO_TO")
    @client      = Twilio::REST::Client.new(@account_sid, @auth_token)
  end

  def send_message(body:)
    raise ArgumentError, "body nao pode ser vazio" if body.blank?
    raise ArgumentError, "Mensagem excede 1600 caracteres (#{body.length})" if body.length > 1600

    message = @client.messages.create(from: @from, to: @to, body: body)
    Rails.logger.info("[TwilioWhatsappService] Enviado. SID=#{message.sid}")
    { success: true, sid: message.sid }
  rescue Twilio::REST::TwilioError => e
    Rails.logger.error("[TwilioWhatsappService] Erro Twilio: #{e.message}")
    raise DeliveryError, "Twilio falhou: #{e.message}"
  end

  private

  def fetch_env!(key)
    ENV[key].presence || raise(ConfigurationError, "ENV var #{key} nao configurada")
  end
end
