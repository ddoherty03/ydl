module Ydl
  # A Node in a Ydl::Tree
  class Node
    attr_reader :path, :val, :children, :klass, :referee

    # The val is either (1) a String (not a cross-reference) or a Date (or a
    # Numeric? or a Boolean?) that is the direct value of the Node, in which
    # case, @children must be empty and the Node is considered "resolved", or
    # (2) a String that is a cross reference, in which case it needs to be
    # resolved and the Node at the path up to the penultimate component
    # becomes a "prerequisite" to resolving this Node; if its prerequisites
    # are resolved, set @val to that Node and set this Node to resolved;
    # otherwise, place this Node on a queue of unresolved Nodes that need to
    # be re-visited after the prerequisite is resolved; once the
    # cross-reference is resolved, @val become a reference to the other object
    # in the tree and this Node is marked resolved and removed from the queue,
    # or (3) a Hash in which case its elements become the children of this
    # Node and @val is set to nil, or (4) an Array, in which case its elements
    # become the children of this Node (with their numeric indices as keys)
    # and @val is set nil.
    def initialize(path, val, klass = nil)
      @path = path
      @klass = klass
      @val = val
      # Child Nodes; always a Hash, but keys may be numeric symbols, such a
      # :'1', :'88', etc, where an array-like structure is wanted.
      @children = {}
      @resolved = false
      @referee = nil
      @depends_on = []
      build
      self
    end

    def resolved?
      @resolved
    end

    def keys
      children.keys
    end

    def key?(key)
      keys.include?(key)
    end

    # Return the /val/ of child at key +key+ or nil if there is none
    def [](key)
      return nil if children.empty?
      key = key.to_s.to_sym if key.is_a?(Numeric)
      children[key]
    end

    # Return the /object/ of this Node
    def object
      val
    end

    def resolve_xref
      return self unless @referee
      ref_path = Tree.xref_to_path(@referee)
      obj = Ydl.data.node_at_path(ref_path)
      if obj.val.class == klass
        @val = obj.val
        @resolved = true
      end
      instantiate
      self
    end

    private

    # Build this node and the children subnodes of self and set this node's
    # instance variables. Attempt to instantiate the node's val into an object
    # of type klass if possible; record cross-references in Ydl::Tree.workq for
    # later resolution.
    def build
      case val
      when String
        if val.xref?
          @referee = val
          @depends_on << val
          @val = nil
          @resolved = false
        else
          @resolved = true
          @referee = nil
        end
        @children = {}
      when Hash
        has_xref = val.xref?
        obj = (klass && !has_xref) ? instantiate : nil
        if obj
          @val = obj
          @resolved = true
        else
          children_resolved = true
          val.each_pair do |k, v|
            klass = Ydl.class_for(k) || @klass
            child = Node.new(path + [k], v, klass)
            @depends_on << child.referee unless child.referee.blank?
            @children[k] = child
            children_resolved &&= child.resolved?
          end
          @val = nil
          # @resolved = false
          @resolved = children_resolved
          obj = klass ? instantiate : nil
        end
        @referee = nil
      when Array
        val.each_with_index do |v, k|
          child = Node.new(path + [k.to_s.to_sym], v, @klass)
          @depends_on << child.referee unless child.referee.blank?
          @children[k.to_s.to_sym] = child
        end
        @val = nil
        @referee = nil
        @resolved = false
      else
        # An ordinary, scalar Node, perhaps a Date
        @resolved = true
        @children = {}
        @referee = nil
      end
      unless @depends_on.empty?
        Tree.workq.add_dependency(Tree.path_to_xref(path), @depends_on)
      end
      self
    end

    def instantiated?
      return true if val.class == klass
      result = false
      unless children.empty?
        result = children.values.all? { |n| n.val.class == n.klass }
      end
      result
    end

    # Return an object of class klass if one can be initialized with the Hash
    # val.
    def instantiate
      return nil if klass.blank?
      return val if instantiated?
      if val
        klass.send(konstructor, val)
      elsif resolved?
        binding.pry
        klass.send(konstructor, val)
      end
    rescue ArgumentError
      return nil
    end

    # Return a symbol for the constructor method for klass: either :new or the
    # user-defined constructor from the config.
    def konstructor
      return nil if klass.blank?
      Ydl.class_init(klass.to_s)
    end
  end
end
