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
      depends_on =
        case depends_on
        when Array
          depends_on
        else
          [depends_on]
        end
      @dependencies[dependent] ||= []
      @dependencies[dependent] += depends_on
      # Add an empty dependency for all the depends_on members; the TSort
      # module expects this to indicate that the ref depends on nothing else.
      depends_on.each do |ref|
        @dependencies[ref] = [] unless @dependencies.key?(ref)
      end
      self
    end

    def print_out
      puts 'Dependencies:'
      pp @dependencies.tsort
    end

    def topological_xrefs
      @dependencies.tsort
    rescue TSort::Cyclic => e
      raise Ydl::CircularReference, e.to_s
    end
  end
end
