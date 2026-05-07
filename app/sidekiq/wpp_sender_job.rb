class WppSenderJob
  include Sidekiq::Job

  def perform(*args)
    
    response = Net::HTTP.get(URI(localhost:))
    dados = JSON.parse(response)
  end
end
