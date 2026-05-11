class WppSenderJob
  include Sidekiq::Job

  def perform
    SendWeatherForecastJob.perform_now
  end
end
