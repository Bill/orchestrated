require 'active_record'
require 'state_machine'
require 'delayed_job'
require 'delayed_job_active_record'

module Orchestrated
  class Orchestration < ActiveRecord::Base

    Handler = Struct.new('Handler', :value, :sym, :args)

    serialize :handler

    belongs_to :prerequisite, :class_name => 'CompletionExpression'
    belongs_to :delayed_job, :polymorphic => true # loose-ish coupling with delayed_job

    has_many :orchestration_completions

    complete_states = [:succeeded, :failed]
    state_machine :initial => :new do
      state :new
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

      event :prerequisite_changed do
        transition [:new, :waiting] => :ready, :if => lambda {|orchestration| orchestration.prerequisite.complete?}
        transition [:ready, :waiting] => :canceled, :if => lambda {|orchestration| orchestration.prerequisite.canceled?}
        transition :new => :waiting # otherwise
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
        # completion may make other orchestrations ready to run…
        # TODO: this is a prime target for benchmarking
        (Orchestration.with_state('waiting').all - [orchestration]).each do |other|
          other.prerequisite_changed
        end
      end

      after_transition [:ready, :waiting] => :canceled do |orchestration, transition|
        # cancellation may cancel other orchestrations
        (Orchestration.with_states(:ready, :waiting).all - [orchestration]).each do |other|
          other.prerequisite_changed
        end
      end

    end

    def self.create( value, sym, args, prerequisite)
      # set prerequisite in new call so it is passed to state_machine :initial proc
      new.tap do |orchestration|

        orchestration.handler = Handler.new( value, sym, args)

        # wee! static analysis FTW!
        raise 'prerequisite can never be complete' if prerequisite.never_complete?

        # saves object as side effect of this assignment
        # also moves orchestration to :ready state
        orchestration.prerequisite  = prerequisite
     end
    end

    def enqueue
      self.delayed_job = Delayed::Job.enqueue( MessageDelivery.new( handler.value, handler.sym, handler.args, self.id) )
    end

    def dequeue
      delayed_job.destroy# if DelayedJob.exists?(delayed_job_id)
    end

    alias_method :prerequisite_old_equals, :prerequisite=
    def prerequisite=(*args)
      prerequisite_old_equals(*args)
      prerequisite_changed
    end

  end
end
