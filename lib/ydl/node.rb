module Ydl
  # A Node in a Ydl::Tree
  class Node
    attr_reader :path, :root_id, :val, :children, :klass, :referee

    def initialize(path, val, klass = nil, root_id:)
      # The path is an array of symbols representing the series of references
      # taken from the root of the tree to this Node.
      @path = path
      # The Object id for the root Node of the tree of which this Node is a
      # part.
      @root_id = root_id
      # The class into which this Node should be instantiated.
      @klass = klass
      # The uninterpreted value for this Node, which when instantiated, will
      # be an instance of klass.
      @val = val
      # Child Nodes; always a Hash, but keys may be numeric symbols, such a
      # :'1', :'88', etc, where an sequential array-like structure is wanted.
      @children = {}
      # Has this Node resolved any cross-references in val yet?
      @resolved = false
      @referee = nil
      @depends_on = []
      build
    end

    # Return a reference to the Ydl::Tree to which this Node belongs, in case we
    # instantiate more than one tree.
    def this_tree
      ObjectSpace._id2ref(root_id)
    end

    # Query whether this node is resolved, that is, does it contain a string
    # reference to another part of the tree to which this Node belongs.
    def resolved?
      @resolved
    end

    # Query the key for this Node.
    def key
      path.last
    end

    # The keys for children Nodes.
    def keys
      children.keys
    end

    # Does this Node include key.
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
      if @referee
        ref_path = Tree.xref_to_path(@referee)
        obj = this_tree.node_at_path(ref_path)
        if obj.val.class == klass
          @val = obj.val
          @resolved = true
        end
      else
        @resolved = true
      end
      unless instantiated?
        obj = instantiate
        @val = obj if obj
      end
      self
    end

    # Convert this Node's children to a Hash suitable for use as an argument to
    # a constructor.
    def to_params
      make_arr = children.keys.map(&:to_s).all? { |k| k =~ /\A[0-9]+\z/ }
      result = make_arr ? [] : {}
      children.each_pair do |k, child|
        k = make_arr ? k.to_s.to_i : k
        result[k] =
          if child.children.empty? || child.val.class == child.klass
            child.val
          else
            child.to_params
          end
      end
      result
    end

    def instantiated?
      return true if val.class == klass

      result = false
      unless children.empty?
        result = children.values.all? { |n| n.val.class == n.klass }
      end
      result
    end

    private

    # Build this node and the children subnodes of self and set this node's
    # instance variables. Attempt to instantiate the node's val into an object
    # of type klass if possible; record cross-references in Ydl::Tree.workq for
    # later resolution.
    #
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
        obj = klass && !has_xref ? instantiate : nil
        if obj
          @val = obj
          @resolved = true
        else
          children_resolved = true
          val.each_pair do |k, v|
            klass = Ydl.class_for(k) || @klass
            child = Node.new(path + [k], v, klass, root_id: root_id)
            @depends_on << child.referee unless child.referee.blank?
            @children[k] = child
            children_resolved &&= child.resolved?
          end
          @val = nil
          @resolved = children_resolved
        end
        @referee = nil
      when Array
        val.each_with_index do |v, k|
          child = Node.new(path + [k.to_s.to_sym], v, @klass, root_id: root_id)
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

    # Return an object of class @klass if one can be initialized with the Hash
    # val or the current Node converted to a params hash.
    def instantiate
      return nil if klass.blank?
      return val if instantiated?

      if val
        klass.send(konstructor, **val)
      elsif resolved?
        klass.send(konstructor, **to_params)
      end
    rescue ArgumentError
      nil
    end

    # Return a symbol for the constructor method for klass: either :new or the
    # user-defined constructor from the config.
    def konstructor
      return nil if klass.blank?

      Ydl.class_init(klass.to_s)
    end
  end
end
