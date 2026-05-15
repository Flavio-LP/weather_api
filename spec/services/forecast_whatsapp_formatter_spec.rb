require "rails_helper"

RSpec.describe ForecastWhatsappFormatter do
  let(:base_day) do
    {
      date: "2025-01-15",
      day_label: "Hoje",
      temp_min_c: 18,
      temp_max_c: 28,
      rain_mm: 2.5,
      rain_probability_percent: 30,
      wind_direction: "SE",
      wind_kmh: 15,
      summary: "Parcialmente nublado",
      temperature_alert: false,
    }
  end

  let(:base_data) do
    {
      city: "Forquilhinha",
      state: "SC",
      days: [base_day],
    }
  end

  describe ".format" do
    it "retorna uma string" do
      expect(described_class.format(base_data)).to be_a(String)
    end

    it "inclui o nome da cidade e estado no cabeçalho" do
      result = described_class.format(base_data)
      expect(result).to include("Forquilhinha-SC")
    end

    it "inclui a data de atualização" do
      result = described_class.format(base_data)
      expect(result).to include(Date.today.strftime("%d/%m/%Y"))
    end

    it "inclui separadores" do
      result = described_class.format(base_data)
      expect(result).to include("━━━━━━━━━━━━━━━━━━━━━")
    end

    it "inclui a fonte no rodapé" do
      result = described_class.format(base_data)
      expect(result).to include("Climatempo")
    end

    it "limita a quantidade de dias via days_count" do
      data = base_data.merge(days: Array.new(15) { base_day })
      result = described_class.format(data, days_count: 3)
      expect(result.scan("15/01").size).to eq(3)
    end

    it "usa cidade padrão quando não informada" do
      result = described_class.format({ days: [base_day] })
      expect(result).to include("Forquilhinha-SC")
    end
  end

  describe "formatação do dia" do
    it "inclui a temperatura mínima e máxima" do
      result = described_class.format(base_data)
      expect(result).to include("18-28°C")
    end

    it "inclui a direção do vento em português" do
      result = described_class.format(base_data)
      expect(result).to include("Sudeste")
    end

    it "inclui a velocidade do vento" do
      result = described_class.format(base_data)
      expect(result).to include("15km/h")
    end

    it "inclui o resumo do clima" do
      result = described_class.format(base_data)
      expect(result).to include("Parcialmente nublado")
    end

    it "inclui a chuva em mm" do
      result = described_class.format(base_data)
      expect(result).to include("2.5mm")
    end

    it "formata a data com label" do
      result = described_class.format(base_data)
      expect(result).to include("15/01 Hoje")
    end

    it "formata a data sem label quando não informado" do
      day = base_day.merge(day_label: nil)
      result = described_class.format(base_data.merge(days: [day]))
      expect(result).to include("15/01")
      expect(result).not_to include("15/01 ")
    end
  end

  describe "emoji de chuva" do
    it "exibe verde para probabilidade baixa (0-20%)" do
      day = base_day.merge(rain_probability_percent: 10)
      result = described_class.format(base_data.merge(days: [day]))
      expect(result).to include("🟢")
    end

    it "exibe amarelo para probabilidade moderada (21-50%)" do
      day = base_day.merge(rain_probability_percent: 35)
      result = described_class.format(base_data.merge(days: [day]))
      expect(result).to include("🟡")
    end

    it "exibe laranja para probabilidade alta (51-80%)" do
      day = base_day.merge(rain_probability_percent: 65)
      result = described_class.format(base_data.merge(days: [day]))
      expect(result).to include("🟠")
    end

    it "exibe vermelho para probabilidade muito alta (81-100%)" do
      day = base_day.merge(rain_probability_percent: 90)
      result = described_class.format(base_data.merge(days: [day]))
      expect(result).to include("🔴")
    end
  end

  describe "emoji do tempo" do
    it "exibe tempestade para chuva intensa com alta probabilidade" do
      day = base_day.merge(rain_probability_percent: 90, rain_mm: 10, summary: "Tempestade")
      result = described_class.format(base_data.merge(days: [day]))
      expect(result).to include("⛈️")
    end

    it "exibe chuva para probabilidade >= 70%" do
      day = base_day.merge(rain_probability_percent: 75, rain_mm: 3, summary: "Nublado")
      result = described_class.format(base_data.merge(days: [day]))
      expect(result).to include("🌧️")
    end

    it "exibe sol com nuvens para probabilidade >= 40%" do
      day = base_day.merge(rain_probability_percent: 45, rain_mm: 1, summary: "Nublado")
      result = described_class.format(base_data.merge(days: [day]))
      expect(result).to include("🌦️")
    end

    it "exibe sol para probabilidade baixa e céu limpo" do
      day = base_day.merge(rain_probability_percent: 5, rain_mm: 0, summary: "Céu limpo")
      result = described_class.format(base_data.merge(days: [day]))
      expect(result).to include("☀️")
    end
  end

  describe "alerta de temperatura" do
    it "inclui alerta quando temperature_alert é true" do
      day = base_day.merge(temperature_alert: true)
      result = described_class.format(base_data.merge(days: [day]))
      expect(result).to include("⚠️")
      expect(result).to include("Mudança brusca de temperatura")
    end

    it "não inclui alerta quando temperature_alert é false" do
      result = described_class.format(base_data)
      expect(result).not_to include("Mudança brusca de temperatura")
    end
  end

  describe "truncamento do resumo" do
    it "trunca resumos longos com reticências" do
      long_summary = Faker::Lorem.characters(number: 150)
      day = base_day.merge(summary: long_summary)
      result = described_class.format(base_data.merge(days: [day]))
      expect(result).to include("...")
    end

    it "não trunca resumos curtos" do
      day = base_day.merge(summary: "Ensolarado")
      result = described_class.format(base_data.merge(days: [day]))
      expect(result).not_to include("...")
    end
  end
end
