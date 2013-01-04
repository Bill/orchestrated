require 'active_record'
require 'state_machine'
require 'delayed_job'
require 'delayed_job_active_record'

module Orchestrated
  class Orchestration < ActiveRecord::Base

    Handler = Struct.new('Handler', :value, :sym, :args)

    serialize :handler

    has_one :prerequisite, :class_name => 'OrchestrationInterest'
    has_one :dependent, :class_name => 'OrchestrationCompletion'

    belongs_to :delayed_job, :polymorphic => true # loose-ish coupling with delayed_job

    complete_states = [:succeeded, :failed]
    state_machine :initial => :waiting do
      state :waiting
      state :ready
      state :succeeded
      state :failed
      state :canceled

      state all - complete_states do
        def complete?
          false
        end
      end

      state *complete_states do
        def complete?
          true
        end
      end

      event :prerequisite_complete do
        transition :waiting => :ready
      end

      event :prerequisite_canceled do
        transition [:waiting, :ready] => :canceled
      end

      event :message_delivery_succeeded do
        transition :ready => :succeeded
      end

      event :message_delivery_failed do
        transition :ready => :failed
      end

      event :cancel do
        transition [:waiting, :ready] => :canceled
      end

      after_transition any => :ready do |orchestration, transition|
        orchestration.enqueue
      end

      after_transition :ready => :canceled do |orchestration, transition|
        orchestration.dequeue
      end

      after_transition any => complete_states do |orchestration, transition|
        orchestration.dependent.prerequisite_complete
      end

      after_transition [:ready, :waiting] => :canceled do |orchestration, transition|
        orchestration.dependent.prerequisite_canceled
      end

    end

    def self.create( value, sym, args, prerequisite)
      # set prerequisite in new call so it is passed to state_machine :initial proc
      new.tap do |orchestration|

        orchestration.handler = Handler.new( value, sym, args)

        # wee! static analysis FTW!
        raise 'prerequisite can never be complete' if prerequisite.never_complete?

        prerequisite.save!
        orchestration.save!
        interest = OrchestrationInterest.new.tap do |interest|
          interest.prerequisite = prerequisite
          interest.orchestration = orchestration
        end
        interest.save!

        # prime the pump for a constant prerequisite
        orchestration.prerequisite_complete! if prerequisite.complete?
     end
    end

    def enqueue
      self.delayed_job = Delayed::Job.enqueue( MessageDelivery.new( handler.value, handler.sym, handler.args, self.id) )
    end

    def dequeue
      delayed_job.destroy# if DelayedJob.exists?(delayed_job_id)
    end

  end
end
