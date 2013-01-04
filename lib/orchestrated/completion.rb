require 'active_record'

module Orchestrated
  # a little ditty to support the completion algebra
  # a composite!
  # Completion is used as a prerequisite (prerequisites) for message passing
  class CompletionExpression < ActiveRecord::Base
    # I'd like to make this abstract, but Rails gets confused if I do
    # self.abstract_class = true
    has_many :dependent_associations, :class_name => 'OrchestrationDependency', :foreign_key => 'prerequisite_id'
    has_many :dependents, :through => :dependent_associations, :autosave => true
    def complete?; throw 'subclass must override!';end
    # for static analysis
    def always_complete?; throw 'subclass must override!';end
    def never_complete?; throw 'subclass must override!';end
    def canceled?; throw 'subclass must override!';end
    def prerequisite_complete; throw 'subclass must override!';end
    def notify_dependents_of_completion
      # NB: we are notifying the Join Model here (it keeps track of status)
      dependent_associations.each{|d| d.prerequisite_completed}
    end
    def notify_dependents_of_cancellation
      # NB: we are notifying the Join Model here (it keeps track of status)
      dependent_associations.each{|d| d.prerequisite_canceled}
    end
  end
  class Complete < CompletionExpression
    def complete?; true; end
    def always_complete?; true; end
    def never_complete?; false; end
    def canceled?; false; end
  end
  # Only known use is in testing the framework
  class Incomplete < CompletionExpression
    def complete?; false; end
    def always_complete?; false; end
    def never_complete?; true; end
    def canceled?; false; end
  end
  class CompositeCompletion < CompletionExpression
    # self.abstract_class = true
    has_many :prerequisite_associations, :class_name => 'OrchestrationDependency', :foreign_key => 'dependent_id'
    has_many :prerequisites, :through => :prerequisite_associations, :autosave => true
    def +(c); self << c; end # synonymc
  end
  class LastCompletion < CompositeCompletion
    def complete?; prerequisites.all?(&:complete?); end
    def always_complete?; prerequisites.empty?; end
    def never_complete?; prerequisites.any?(&:never_complete?); end
    def canceled?; prerequisites.any?(&:canceled?); end
    def <<(c)
      prerequisites << c unless c.always_complete?
      self
    end
    def prerequisite_complete
      notify_dependents_of_completion unless prerequisite_associations.without_states('complete').exists?
    end
    def prerequisite_canceled
      notify_dependents_of_cancellation
    end
  end
  class FirstCompletion < CompositeCompletion
    def complete?; prerequisites.any?(&:complete?); end
    def always_complete?; prerequisites.any?(&:always_complete?); end
    def never_complete?; prerequisites.empty?; end
    def canceled?; prerequisites.all?(&:canceled?); end
    def <<(c)
      prerequisites << c unless c.never_complete?
      self
    end
    def prerequisite_complete
      notify_dependents_of_completion
    end
    def prerequisite_canceled
      notify_dependents_of_cancellation unless prerequisite_associations.without_states('canceled').exists?
    end
  end
  class OrchestrationCompletionShim < CompletionExpression
    # Arguably, it is "bad" to make this class derive
    # from CompletionExpression since doing so introduces
    # the orchestration_id into the table (that constitutes
    # denormalization since no other types need that field).
    # The alternative is that we have to do difficult-to-
    # understand joins when computing dependents at runtime.
    belongs_to :orchestration
    validates_presence_of :orchestration_id
  end
  # wraps an Orchestration and makes it usable as a completion expression
  class OrchestrationCompletion < OrchestrationCompletionShim
    delegate :complete?, :canceled?, :cancel!, :to => :orchestration
    def always_complete?; false; end
    def never_complete?; false; end
    def prerequisite_complete
      notify_dependents_of_completion
    end
    def prerequisite_canceled
      notify_dependents_of_cancellation
    end
  end
  # registers an Orchestration's interest in a completion expression
  class OrchestrationInterest < OrchestrationCompletionShim
    has_one :prerequisite_association, :class_name => 'OrchestrationDependency', :foreign_key => 'dependent_id'
    has_one :prerequisite, :through => :prerequisite_association, :autosave => true
    def prerequisite_complete
      orchestration.prerequisite_complete
    end
    def prerequisite_canceled
      orchestration.prerequisite_canceled
    end
  end
end
