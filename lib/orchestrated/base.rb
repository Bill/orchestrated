module Orchestrated

  class Proxy < BasicObject
    include ::Kernel
    def initialize(prerequisite, target)
      @prerequisite = prerequisite
      @target       = target
    end
    def method_missing(sym, *args)
      raise ArgumentError.new('cannot orchestrate with blocks because they are not portable across processes') if block_given?
      Orchestration.create( @target, sym, args, @prerequisite)
    end
  end

  # because this class is called "Orchestrate", the method defined (on Object) will be "orchestrate"
  class Orchestrate
    class << self
      #snarfed from Ruby On Rails
      def underscore(camel_cased_word)
        camel_cased_word.to_s.gsub(/::/, '/').
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          tr("-", "_").
          downcase
      end
      def belongs_to clazz
        # borrowed from Ick
        method_name = self.underscore(self.name.split('::')[-1])
        unless clazz.method_defined?(method_name)
          clazz.class_eval "
            def #{method_name}(prerequisite=Complete.new)
              raise ArgumentError.new('orchestrate does not take a block') if block_given?
              raise ArgumentError.new(%[cannot use \#{prerequisite.class.name} as a prerequisite]) unless
                prerequisite.kind_of?(CompletionExpression)
              Proxy.new(prerequisite, self)
            end"
        end
      end
    end
  end

end
