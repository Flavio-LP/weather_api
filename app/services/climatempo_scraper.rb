# frozen_string_literal: true
require "nokogiri"
require "date"

class ClimatempoScraper
  DEFAULT_URL = "https://www.climatempo.com.br/previsao-do-tempo/15-dias/cidade/4598/forquilhinha-sc"

  def self.fetch_15_days(url: DEFAULT_URL, city: "Forquilhinha", state: "SC")
    new(url:, city:, state:).fetch_15_days
  end

  def initialize(url:, city:, state:)
    @url = url
    @city = city
    @state = state
  end

  def fetch_15_days
    html = fetch_html_with_retries(@url)
    doc  = Nokogiri::HTML(html)

    days = extract_days(doc)

    result = {
      city: @city,
      state: @state,
      source: @url,
      days: days.first(15)
    }

    if days.empty?
      Rails.logger.warn("[ClimatempoScraper] Nenhum dia extraído. Estrutura pode ter mudado. URL=#{@url}")
    end

    result
  rescue => e
    Rails.logger.error("[ClimatempoScraper] #{e.class}: #{e.message}")
    Rails.logger.error("[ClimatempoScraper] backtrace: #{e.backtrace&.first(5)&.join(' | ')}")
    raise
  end

  private

  # ---------------- HTTP ----------------

  def fetch_html_with_retries(url, max_retries: 3, backoff: 1.0)
    last_error = nil
    (1..max_retries).each do |attempt|
      resp = HTTP.headers(default_headers)
                 .follow(max_hops: 5)
                 .timeout(connect: 10, write: 15, read: 30)
                 .get(url)

      if resp.status.success?
        return resp.to_s
      else
        snippet = resp.to_s[0, 600]
        Rails.logger.error("[ClimatempoScraper] HTTP #{resp.status} (tentativa #{attempt}) | snippet=#{snippet.inspect}")
        last_error = RuntimeError.new("HTTP #{resp.status}")
      end
      sleep(backoff * attempt)
    end
    raise last_error || "Falha ao obter HTML"
  rescue => e
    Rails.logger.error("[ClimatempoScraper] Erro de rede: #{e.class}: #{e.message}")
    raise
  end

  def default_headers
    {
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36",
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
      "Accept-Language" => "pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7",
      "Cache-Control" => "no-cache",
      # Ajuste conforme consentimento do site se necessário:
      "Cookie" => "cookie_consent=true"
    }
  end

  # ---------------- EXTRAÇÃO ----------------

  def extract_days(doc)
    # Limitar ao container principal de “15 dias”, quando possível
    root = doc.at_xpath("//section[.//text()[contains(., 'Previsão do Tempo') and contains(., '15 Dias')]]") || doc

    # Cards candidatos: nós que contenham temperaturas “°”
    candidate_blocks = root.xpath(".//*[self::div or self::section or self::article][.//text()[contains(., '°')]]")

    raw_days = []

    candidate_blocks.each do |blk|
      texts = blk.xpath(".//text()")
                 .map(&:text)
                 .map { |t| t.gsub(/\s+/, " ").strip }
                 .reject(&:empty?)

      # Resumo — âncora para reconhecer que é um card de dia válido
      summary = texts.find { |t|
        t =~ /\b(Dom|Seg|Ter|Qua|Qui|Sex|Sáb)\b/i && t =~ /(Sol|Nublado|Chuva|Garoa|céu|nebulosidade)/i
      } || texts.find { |t|
        t =~ /(Sol|Nublado|Chuva|Garoa|céu|nebulosidade)/i && t.length.between?(12, 220)
      }
      next unless summary

      # Temperaturas — usar o par mais próximo para evitar contaminação
      deg_idxs = []
      texts.each_with_index { |t, i| deg_idxs << i if t.include?("°") }
      next if deg_idxs.size < 2

      best_pair = nil
      best_gap = 1_000
      (0...deg_idxs.size - 1).each do |k|
        i1, i2 = deg_idxs[k], deg_idxs[k + 1]
        gap = i2 - i1
        if gap < best_gap
          best_gap = gap
          best_pair = [texts[i1], texts[i2]]
        end
      end
      temps_pair = best_pair || [texts[deg_idxs[0]], texts[deg_idxs[1]]]
      t1 = extract_temp(temps_pair[0])
      t2 = extract_temp(temps_pair[1])
      next if t1.nil? || t2.nil?
      temp_min_c = [t1, t2].min
      temp_max_c = [t1, t2].max

      # Chuva — recompor “mm - %” mesmo se separados; aceitar casos só com %
      rain_line = find_rain_line(texts)
      rain_mm, rain_prob = parse_rain(rain_line)

      # Vento e umidade
      wind_line = find_wind_line(texts)
      wind_dir, wind_kmh = parse_wind(wind_line)

      humidity_vals = find_humidity_values(texts)
      hum_min, hum_max = parse_humidity(humidity_vals)

      # Data
      day_number = texts.find { |t| t =~ /^(0?[1-9]|[12]\d|3[01])$/ }
      day_label  = texts.find { |t| %w[Dom Seg Ter Qua Qui Sex Sáb].include?(t) }
      date_iso   = build_date_iso(day_number)
      date_key   = date_iso || day_number || day_label

      # Score de completude (para dedupe)
      score = [
        !date_iso.nil?,
        !temp_min_c.nil?, !temp_max_c.nil?,
        !rain_mm.nil?, !rain_prob.nil?,
        !wind_dir.nil?, !wind_kmh.nil?,
        !hum_min.nil?, !hum_max.nil?,
        !summary.nil?
      ].count(true)

      raw_days << {
        date: date_iso,
        date_key: date_key,
        day_label: day_label,
        temp_min_c: temp_min_c,
        temp_max_c: temp_max_c,
        rain_mm: rain_mm,
        rain_probability_percent: rain_prob,
        wind_direction: wind_dir,
        wind_kmh: wind_kmh,
        humidity_min_percent: hum_min,
        humidity_max_percent: hum_max,
        summary: summary,
        _score: score
      }
    end

    # Deduplicar por chave de data (date/date_number/label), priorizando card mais completo
    by_key = {}
    raw_days.each do |d|
      key = d[:date_key]
      next unless key
      best = by_key[key]
      if best.nil? || d[:_score] > best[:_score]
        by_key[key] = d
      end
    end

    deduped = by_key.values.map { |d| d.reject { |k,_| k == :_score || k == :date_key } }
    deduped.sort_by! { |d| [d[:date].to_s, d[:day_label].to_s] }
    deduped.first(15)
  end

  # ---------------- HELPERS ----------------

  def extract_temp(str)
    return nil unless str
    # "15°", "15,0°", "-1°"
    if (m = str.match(/(-?\d{1,2})(?:[.,]\d+)?\s*°/))
      m[1].to_i
    else
      nil
    end
  end

  def to_temp_val(str)
    t = extract_temp(str)
    t.nil? ? -999 : t
  end

  # Monta janela de chuva a partir de mm/%/Chuva/Prob em diversas combinações
  def find_rain_line(texts)
    return nil if texts.nil? || texts.empty?

    norm = texts.map { |t| t.gsub(/\s+/, " ").strip }.reject(&:empty?)

    # Direto: "X mm ... Y%"
    direct = norm.find { |t| t =~ /mm/i && t =~ /\b\d{1,3}%\b/ }
    return direct if direct

    # Janela a partir de "mm"
    norm.each_with_index do |t, i|
      next unless t =~ /[\d.,]+\s*mm/i
      window = norm[i, 6].join(" ")
      return window if window =~ /\b\d{1,3}\s*%/
    end

    # Janela a partir de "%"
    norm.each_with_index do |t, i|
      next unless t =~ /\b\d{1,3}\s*%/
      window = norm[[i - 3, 0].max, 6].join(" ")
      return window if window =~ /[\d.,]+\s*mm/i
    end

    # A partir de "Chuva"/"Prob(abilidade)"
    idxs = []
    norm.each_with_index do |t, i|
      idxs << i if t =~ /\bChuva\b/i || t =~ /\bProb\b/i || t =~ /\bProbabilidade\b/i
    end
    idxs.each do |i|
      window = norm[i, 10].join(" ")
      return window if window =~ /mm/i && window =~ /\b\d{1,3}\s*%/
      return window if window =~ /\b\d{1,3}\s*%/
    end

    # fallback: combine primeiro mm e primeiro %
    mm_token  = norm.find { |t| t =~ /[\d.,]+\s*mm/i }
    pct_token = norm.find { |t| t =~ /\b\d{1,3}\s*%/ }
    return "#{mm_token} - #{pct_token}" if mm_token && pct_token

    # sem mm, mas com % — retorna mesmo assim
    return pct_token if pct_token

    nil
  end

  def find_wind_line(texts)
    return nil if texts.nil? || texts.empty?
    direct = texts.find { |t| t =~ /km\/h/i }
    return direct if direct

    texts.each_with_index do |t, i|
      next unless t =~ /\b(N|S|E|W|NE|NW|SE|SW|ENE|ESE|SSE|SSW|NNW|NNE|WSW|WNW)\b/i
      window = texts[i, 4].join(" ")
      return window if window =~ /km\/h/i
    end
    nil
  end

  def find_humidity_values(texts)
    return [] if texts.nil? || texts.empty?
    vals = texts.select { |t| t.strip =~ /^\d{1,3}%$/ }
    return vals unless vals.empty?

    joined = texts.join(" ")
    inline = joined.scan(/(\d{1,3})\s*%/).flatten.map { |v| "#{v}%" }
    inline.uniq
  end

  def parse_rain(str)
    return [nil, nil] unless str
    mm   = str[/([\d.,]+)\s*mm/i, 1]
    pct  = str[/(\d{1,3})\s*%/, 1]

    mm_val = mm ? mm.tr(",", ".").to_f : nil
    prob   = pct ? pct.to_i : nil

    if prob
      prob = [[prob, 0].max, 100].min
    end

    [mm_val, prob]
  end

  def parse_wind(str)
    return [nil, nil] unless str
    dir = str[/\b(N|S|E|W|NE|NW|SE|SW|ENE|ESE|SSE|SSW|NNW|NNE|WSW|WNW)\b/i, 0]
    kmh = str[/([\d.,]+)\s*km\/h/i, 1] || str[/([\d.,]+)\s*Km\/h/i, 1]
    [
      dir&.upcase,
      kmh ? kmh.tr(",", ".").to_f : nil
    ]
  end

  def parse_humidity(arr)
    values = (arr || []).map { |t| t.delete("%").to_i }
    return [nil, nil] if values.empty?
    [values.min, values.max]
  end

  def build_date_iso(day_number_str)
    return nil unless day_number_str && day_number_str =~ /^\d{1,2}$/
    day = day_number_str.to_i
    today = Date.today
    month = today.month
    year = today.year

    # Rollover simples dentro da janela de 15 dias
    if day < today.day - 16
      month += 1
      if month > 12
        month = 1
        year += 1
      end
    end

    Date.new(year, month, day).iso8601
  rescue
    nil
  end
end