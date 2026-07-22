class TravelSenderJob
  include Sidekiq::Job

  def perform
    SendTravelCountdownJob.perform_now
  end
end
