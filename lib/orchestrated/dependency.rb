require 'state_machine'

module Orchestrated
  class OrchestrationDependency < ActiveRecord::Base
    # TODO: figure out why Rails thinks I'm mass-assigning this over in Orchestration when I'm not really!
    attr_accessible :prerequisite_id
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
      after_transition any => :complete do |dependency, transition|
        dependency.dependent.prerequisite_complete
      end
      after_transition any => :canceled do |dependency, transition|
        dependency.dependent.prerequisite_canceled
      end
    end
  end
end
