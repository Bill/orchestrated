module Orchestrated
  module InstanceMethods
    # set by the framework (Orchestration) before
    # an orchestrated method is called
    # cleared (nil) outside such a call
    attr_accessor :orchestration
  end
  class ::Object
    class << self
      def acts_as_orchestrated
        Orchestrated.belongs_to self # define "orchestrated instance method"
        include InstanceMethods
      end
    end
  end
end
