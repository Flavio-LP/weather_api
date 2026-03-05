# frozen_string_literal: true

class ForecastWhatsappFormatter
  WEATHER_EMOJI = [
    [/tempestade|raio/i,           "⛈️"],
    [/pancada|aguaceiro/i,         "🌧️"],
    [/garoa|chuvisco/i,            "🌦️"],
    [/chuva/i,                     "🌧️"],
    [/nublado|encoberto/i,         "☁️"],
    [/nuvens.*sol|sol.*nuvens/i,   "⛅"],
    [/sol|limpo|céu limpo/i,       "☀️"],
  ].freeze

  RAIN_EMOJI = [
    [(0..20),   "🟢"],
    [(21..50),  "🟡"],
    [(51..80),  "🟠"],
    [(81..100), "🔴"],
  ].freeze

  WIND_DIRECTION = {
    "N"   => "Norte",
    "S"   => "Sul",
    "E"   => "Leste",
    "W"   => "Oeste",
    "NE"  => "Nordeste",
    "NW"  => "Noroeste",
    "SE"  => "Sudeste",
    "SW"  => "Sudoeste",
    "NNE" => "N-Nordeste",
    "NNW" => "N-Noroeste",
    "SSE" => "S-Sudeste",
    "SSW" => "S-Sudoeste",
    "ENE" => "L-Nordeste",
    "ESE" => "L-Sudeste",
    "WNW" => "O-Noroeste",
    "WSW" => "O-Sudoeste",
  }.freeze

  def self.format(data, days_count: 12)
    new(data, days_count:).format
  end

  def initialize(data, days_count: 12)
    @city  = data[:city] || "Forquilhinha"
    @state = data[:state] || "SC"
    @days  = (data[:days] || []).first(days_count)
  end

  def format
    today = Date.today.strftime("%d/%m/%Y")
    lines = []
    lines << "🌤️ *Previsão #{@city}-#{@state}*"
    lines << "📅 #{@days.size} dias  •  Atualizado #{today}"
    lines << "━━━━━━━━━━━━━━━━━━━━━"
    lines << ""
    @days.each_with_index do |day, i|
      lines << format_day(day)
      lines << "" if i < @days.size - 1
    end
    lines << "━━━━━━━━━━━━━━━━━━━━━"
    lines << "_Fonte: Climatempo_"
    lines.join("\n")
  end

  private

  def format_day(day)
    emoji = weather_emoji(day)
    date  = format_date(day[:date], day[:day_label])
    temp  = "🌡 #{day[:temp_min_c]}-#{day[:temp_max_c]}°C"
    rain  = format_rain(day[:rain_mm], day[:rain_probability_percent])
    wind  = format_wind(day[:wind_direction], day[:wind_kmh])
    summ  = truncate(day[:summary].to_s.strip, 52)

    [
      "#{emoji} *#{date}*",
      "   #{temp}   #{rain}   #{wind}",
      "   📝 #{summ}",
    ].join("\n")
  end

  def format_date(iso, label)
    date_str = Date.parse(iso).strftime("%d/%m")
    label ? "#{date_str} #{label}" : date_str
  rescue
    label.to_s
  end

  def weather_emoji(day)
    prob    = day[:rain_probability_percent].to_i
    mm      = day[:rain_mm].to_f
    summary = day[:summary].to_s

    return "⛈️" if summary.match?(/tempestade|raio/i) || (prob >= 80 && mm >= 8)
    return "🌧️" if prob >= 70
    return "🌦️" if prob >= 40
    return "⛅"  if prob >= 20 || summary.match?(/nuvens/i)
    return "☁️"  if summary.match?(/nublado|encoberto/i)
    "☀️"
  end

  def format_rain(mm, prob)
    prob_int = prob.to_i
    dot = RAIN_EMOJI.find { |range, _| range.include?(prob_int) }&.last || "⚪"
    "#{dot} #{mm.to_i}mm (#{prob_int}%)"
  end

  def format_wind(direction, kmh)
    dir_pt = WIND_DIRECTION[direction&.upcase] || direction
    "💨 #{dir_pt} #{kmh.to_i}km/h"
  end

  def truncate(str, max)
    return str if str.length <= max
    str[0, max].sub(/\s+\S*$/, "") + "..."
  end
end
