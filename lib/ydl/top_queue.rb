module Ydl
  # A class for keeping track of dependencies among nodes in a Ydl::Tree caused
  # by the use of cross-references. This class collects those dependencies with
  # #add_dependency and can return a "total ordering" consistent with the
  # dependencies with its #tsort method.
  class TopQueue
    def initialize
      @dependencies = {}
    end

    def add_dependency(dependent, depends_on)
      @dependencies[dependent] ||= []
      case depends_on
      when Array
        @dependencies[dependent] += depends_on
      else
        @dependencies[dependent] += [depends_on]
      end
      # Add an empty dependency for all the depends_on members; the TSort module
      # expects this to indicate that the ref depends on nothing else.
      depends_on.each do |ref|
        unless @dependencies.key?(ref)
          @dependencies[ref] = []
        end
      end
      self
    end

    def tsort
      @dependencies.tsort
    end
  end
end
