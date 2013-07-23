require 'active_record'
require 'state_machine'
require 'delayed_job'
require 'delayed_job_active_record'

module Orchestrated

  class Handler
    attr_accessor :value
    attr_accessor :sym
    attr_accessor :args
    def initialize(value,sym,args)
      @value,@sym,@args=value,sym,args
    end
  end

  class Orchestration < ActiveRecord::Base


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

      # a before (rather than an after) so that if we change state it'll be saved (piggybacked)
      before_transition any => :ready do |orchestration, transition|
        orchestration.enqueue
      end

      before_transition :ready => :canceled do |orchestration, transition|
        orchestration.dequeue
      end

      after_transition any => complete_states do |orchestration, transition|
        orchestration.dependent.prerequisite_complete
      end

      after_transition [:ready, :waiting] => :canceled do |orchestration, transition|
        orchestration.dependent.prerequisite_canceled
      end

    end

    # Actually creates a completion (wrapper). Not _exactly_ an orchestration—ssh…
    def self.create( value, sym, args, prerequisite)
      # wee! static analysis FTW!
      raise ArgumentError.new('prerequisite can never be complete') if prerequisite.never_complete?
      prerequisite.save!
      OrchestrationCompletion.new.tap do |completion|
        completion.orchestration = new.tap do |orchestration|
          orchestration.handler = Handler.new( value, sym, args)
          orchestration.save!
          interest = OrchestrationInterest.new.tap do |interest|
            interest.prerequisite = prerequisite
            interest.orchestration = orchestration
            interest.save!
          end # interest
          # interest linkage can often change orchestration state so we have to reload here
          orchestration.reload
        end # orchestration
        completion.save!
      end # completion
    end

    def enqueue
      self.delayed_job = Delayed::Job.enqueue( MessageDelivery.new( handler.value, handler.sym, handler.args, self.id) )
    end

    def dequeue
      self.delayed_job.destroy
    end

  end
end
