# Weather API

API Rails que raspa previsões meteorológicas do [Climatempo](https://www.climatempo.com.br) e envia resumos formatados via WhatsApp usando o Twilio.

## Tecnologias

- Ruby 3.3.1 / Rails 7.1
- Sidekiq 8 + Redis (filas de background)
- Nokogiri + HTTP (web scraping)
- Twilio Ruby SDK (WhatsApp)
- Docker / Docker Compose

## Pré-requisitos

- Docker e Docker Compose
- Conta Twilio com número habilitado para WhatsApp

## Variáveis de ambiente

Crie um arquivo `.env` (desenvolvimento) ou `.env.production` (produção) na raiz do projeto:

```env
# Twilio
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_FROM=whatsapp:+14155238886   # número Twilio (sandbox ou aprovado)
TWILIO_TO=whatsapp:+55119xxxxxxxx   # número destinatário

# Redis
REDIS_URL=redis://redis:6379/0

# Rails (obrigatório em produção)
RAILS_MASTER_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## Como rodar

### Desenvolvimento

```bash
docker compose -f docker-compose.dev.yml up --build
```

A aplicação ficará disponível em `http://localhost:3000`.

### Produção

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

## Endpoints da API

### GET `/api/v1/climatempo/15dias/forquilhinha`

Retorna a previsão dos próximos 15 dias para Forquilhinha/SC (padrão). Aceita parâmetros opcionais para buscar outra cidade.

**Query params (opcionais)**

| Parâmetro | Descrição | Exemplo |
|-----------|-----------|---------|
| `url` | URL completa do Climatempo | `https://www.climatempo.com.br/previsao-do-tempo/15-dias/cidade/4598/forquilhinha-sc` |
| `city` | Nome da cidade (informativo) | `Criciuma` |
| `state` | Sigla do estado (informativo) | `SC` |

**Exemplo**

```bash
curl http://localhost:3000/api/v1/climatempo/15dias/forquilhinha
```

**Resposta (200)**

```json
{
  "forecast": [
    {
      "date": "2024-05-05",
      "summary": "Chuva",
      "temp_min": 16,
      "temp_max": 24,
      "rain_mm": 12.4,
      "rain_probability": 80,
      "wind_direction": "SE",
      "wind_speed": 15,
      "humidity": 85
    }
  ],
  "city": "Forquilhinha",
  "state": "SC"
}
```

> Os resultados ficam em cache por 30 minutos no Redis.

---

### POST `/api/v1/forecast/send_whatsapp`

Busca a previsão dos próximos 10 dias e envia uma mensagem formatada via WhatsApp para o número configurado em `TWILIO_TO`.

**Exemplo**

```bash
curl -X POST http://localhost:3000/api/v1/forecast/send_whatsapp
```

**Resposta (200)**

```json
{ "message": "WhatsApp message sent successfully" }
```

## Arquitetura dos serviços

```
app/services/
├── climatempo_scraper.rb          # Scraping HTML com Nokogiri + retry automático
├── forecast_whatsapp_formatter.rb # Formata previsão com emojis para WhatsApp
└── twilio_whatsapp_service.rb     # Envia mensagem via API Twilio
```

| Serviço | Responsabilidade |
|---------|-----------------|
| `ClimatempScraper` | Faz o parse do HTML do Climatempo (temperatura, chuva, vento, umidade) com até 3 tentativas e backoff exponencial |
| `ForecastWhatsappFormatter` | Converte os dados em texto legível com emojis e indicadores coloridos de chuva |
| `TwilioWhatsappService` | Valida credenciais, limita mensagem a 1600 chars e envia via Twilio |

## Testes

```bash
# dentro do container
docker compose -f docker-compose.dev.yml exec web rails test
```

## Monitoramento

O painel do Sidekiq está disponível em `http://localhost:3000/sidekiq` para acompanhar filas e jobs em background.
