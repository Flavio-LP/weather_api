class SendTravelCountdownJob < ApplicationJob
  queue_as :default

  def perform
    message  = TravelService.countdown_message
    url      = ENV.fetch("WHATSAPP_SERVICE_URL", "http://whatsapp:3001")
    group_id = ENV.fetch("WHATSAPP_TRAVEL_GROUP_ID")

    response = HTTP.post("#{url}/send", json: { message:, group_id: })

    unless response.status.success?
      raise "Falha ao enviar WhatsApp: #{response.status} — #{response.body}"
    end

    Rails.logger.info("[SendTravelCountdownJob] Mensagem enviada (#{message.length} chars, group: #{group_id})")
  end
end
