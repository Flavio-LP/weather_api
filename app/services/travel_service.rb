# frozen_string_literal: true

class TravelService
  DEPARTURE_DATE = Date.new(2026, 8, 19).freeze
  RETURN_DATE    = Date.new(2026, 8, 23).freeze

  def self.countdown_message
    today              = Date.today
    days_to_departure  = (DEPARTURE_DATE - today).to_i

    if today > RETURN_DATE
      "🇦🇷 A viagem pra Argentina já ficou na saudade! Foram dias incríveis né? 😄✈️🥩🍷"
    elsif today >= DEPARTURE_DATE
      days_remaining = (RETURN_DATE - today).to_i
      if days_remaining == 0
        "😢 *Último dia na Argentina!* Aproveita cada segundo antes de voltar... 🇦🇷✈️🥩"
      else
        "🇦🇷 *Você está na Argentina!* ✈️🎉 Ainda #{days_remaining} dia#{"s" if days_remaining > 1} de aventura pela frente! Bora aproveitar! 🥩🍷🔥"
      end
    elsif days_to_departure == 1
      "🚨 *AMANHÃ É O DIA!* ✈️ A Argentina nos espera! Tá tudo na mala? 🧳🇦🇷🎊"
    else
      "✈️ Faltam apenas *#{days_to_departure} dias* para a grande aventura na Argentina! 🇦🇷🎉 Vai chegando, vai chegando... a contagem regressiva tá rolando! 🗓️🔥"
    end
  end
end
