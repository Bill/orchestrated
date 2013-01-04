require 'state_machine'

module Orchestrated
  class OrchestrationDependency < ActiveRecord::Base
    belongs_to :dependent, :class_name => 'CompletionExpression'
    belongs_to :prerequisite, :class_name => 'CompletionExpression'
    state_machine :initial => :incomplete do
      state :incomplete
      state :complete
      state :canceled
      event :prerequisite_completed do
        transition :incomplete => :complete
      end
      event :prerequisite_canceled do
        transition :incomplete => :canceled
      end
      after_transition any => :complete do |orchestration, transition|
        orchestration.dependent.prerequisite_complete
      end
      after_transition any => :canceled do |orchestration, transition|
        orchestration.dependent.prerequisite_canceled
      end
    end
  end
end
