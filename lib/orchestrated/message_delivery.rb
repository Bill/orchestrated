module Orchestrated
  class MessageDelivery
    attr_accessor :orchestrated, :method_name, :args, :orchestration_id

    def initialize(orchestrated, method_name, args, orchestration_id)
      raise 'all arguments to MessageDelivery constructor are required' unless
        orchestrated and method_name and args and orchestration_id
      self.orchestrated = orchestrated
      self.method_name  = method_name
      self.args         = args
      self.orchestration_id = orchestration_id
    end

    def perform
      orchestration = Orchestration.find(self.orchestration_id)

      orchestrated.orchestration = orchestration
      orchestrated.send(method_name, *args)
      orchestrated.orchestration = nil

      orchestration.message_delivery_succeeded
    end

    # delayed_job hands us this message after max_attempts are exhausted
    def failure
      orchestration = Orchestration.find(self.orchestration_id)
      orchestration.message_delivery_failed
    end

  end
end
