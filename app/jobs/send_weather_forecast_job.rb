class SendWeatherForecastJob < ApplicationJob
  queue_as :default

  def perform
    data = Rails.cache.fetch("climatempo:15d:forecast", expires_in: 30.minutes) do
      ClimatempoScraper.fetch_15_days
    end

    if data[:days].blank?
      Rails.logger.warn("[SendWeatherForecastJob] Sem dados de previsão, abortando")
      return
    end

    message  = ForecastWhatsappFormatter.format(data)
    url      = ENV.fetch("WHATSAPP_SERVICE_URL", "http://whatsapp:3001")
    response = HTTP.post("#{url}/send", json: { message: })

    unless response.status.success?
      raise "Falha ao enviar WhatsApp: #{response.status} — #{response.body}"
    end

    Rails.logger.info("[SendWeatherForecastJob] Mensagem enviada (#{message.length} chars)")
  end
end
