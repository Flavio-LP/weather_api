redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }

  config.on(:startup) do
    Sidekiq::Cron::Job.load_from_hash(
      "send_weather_forecast" => {
        "cron"  => ENV.fetch("WEATHER_JOB_CRON", "0 7 * * *"),
        "class" => "SendWeatherForecastJob"
      }
    )
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
