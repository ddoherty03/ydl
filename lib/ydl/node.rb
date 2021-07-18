module Ydl
  # A Node in a Ydl::Tree
  class Node
    attr_reader :path, :tree_id
    attr_accessor :val, :resolved, :klass, :children

    def initialize(path, val, klass = nil, tree_id:)
      # The path is an array of symbols representing the series of references
      # taken from the root of the tree to this Node.
      @path = path
      # The Object id for the root Node of the tree of which this Node is a
      # part.
      @tree_id = tree_id
      # The uninterpreted value for this Node, which when instantiated, will
      # be an instance of klass.  Either a Hash or a primitive type.
      @val = val

      # The class into which this Node should be instantiated.
      @klass = klass
      # child Nodes built from val; always a Hash, but keys may be numeric
      # symbols, such a :'1', :'88', etc, where an sequential array-like
      # structure is wanted.
      @children = {}
      # # Has this Node resolved any cross-references in val yet?
      @resolved = false
    end

    # Return a reference to the Ydl::Tree to which this Node belongs, in case we
    # instantiate more than one tree.
    def our_tree
      ObjectSpace._id2ref(tree_id)
    end

    # Query whether this node is resolved, that is, does it contain a string
    # reference to another part of the tree to which this Node belongs.
    def resolved?
      result = true
      children.each_value do |v|
        result &&=
          case v
          when String
            !v.xref?
          when Hash
            v.resolved?
          when Array
            v.all?(&:resolved?)
          else
            true
          end
      end
      result
    end

    # Return an Array of the
    def prerequisites
      result = []
      if children.size.positive?
        children.each_value do |child|
          result += child.prerequisites
        end
      elsif val.instance_of?(String)
        result << val if val.xref?
      end
      result.flatten
    end

    # Return the /val/ of child at key +key+ or nil if there is none
    def [](key)
      return nil if children.empty?

      key = key.to_s.to_sym if key.is_a?(Numeric)
      children[key]
    end

    # Return the xref for this Node.
    def xref
      Tree.path_to_xref(path)
    end

    # Record a dependency of this Node on a foreign Node by virtue of a
    # cross-reference to the foreign Node.  The argument foreign can be a
    # string in the form of a Node xref or an array of xrefs.
    def depends_on(foreign)
      our_tree.workq.add_dependency(xref, foreign) unless foreign.empty?
    end

    # Convert this Node's children to a Hash or Array.
    def to_params
      return {} if children.empty?

      make_arr = children.keys.map(&:to_s).all? { |k| k =~ /\A[0-9]+\z/ }
      result = make_arr ? [] : {}

      children.each_pair do |k, child|
        k = make_arr ? k.to_s.to_i : k
        result[k] =
          if child.children.empty? || child.instantiated?
            child.val
          else
            child.to_params
          end
      rescue TypeError
        warn "ydl: cannot convert #{path} with value '#{child.val}' to params"
      end
      result
    end

    # Recursively build the subtree of Nodes starting at this Node and set
    #  this node's instance variables. Attempt to instantiate the node's val
    #  into an object of type klass if possible; record cross-references in
    #  Ydl::Tree.workq for later resolution.
    #
    # This Node's val is either (1) a String (not a cross-reference) or a Date
    # (or a Numeric? or a Boolean?) that is the direct value of the Node, in
    # which case, @children must be empty and the Node is considered
    # "resolved", or (2) a String that is a cross reference, in which case it
    # needs to be resolved and the Node at the path up to the penultimate
    # component becomes a "prerequisite" to resolving this Node; if its
    # prerequisites are resolved, set @val to that Node and set this Node to
    # resolved; otherwise, place this Node on a queue of unresolved Nodes that
    # need to be re-visited after the prerequisite is resolved; once the
    # cross-reference is resolved, @val become a reference to the other object
    # in the tree and this Node is marked resolved and removed from the queue,
    # or (3) a Hash in which case its elements become the children of this
    # Node and @val is set to nil, or (4) an Array, in which case its elements
    # become the children of this Node (with their numeric indices as keys)
    # and @val is set nil.
    def build_subtree
      case val
      when Hash
        warn "Build from Hash for class '#{klass}': #{val.keys.join('|')}"
        # Build child subtrees first
        val.each_pair do |k, v|
          child_klass = Ydl.class_for(k) || klass
          child = Node.new(path + [k], v, child_klass, tree_id: tree_id)
          children[k] = child.build_subtree
        end
        # Note cross-reference dependencies for this Node
        depends_on(prerequisites)
        self.val = nil
      when Array
        self.resolved = true
        child_klass = Ydl.class_for(path.last) || klass
        val.each_with_index do |v, k|
          child = Node.new(path + [k.to_s.to_sym], v, child_klass, tree_id: tree_id)
          children[k.to_s.to_sym] = child.build_subtree
          self.resolved &&= child.resolved?
        end
        depends_on(prerequisites)
        self.klass = nil
        self.val = nil
      when String
        if val.xref?
          depends_on(val)
          self.resolved = false
        else
          # warn "reify string: #{val}"
          self.resolved = true
          self.klass = String
        end
        self.children = {}
      else
        # E.g., Numeric, Date, DateTime
        # warn "reify #{val.class}: #{val}"
        self.resolved = true
        self.children = {}
        self.klass = val.class
      end
      self
    end

    # Return an object of class @klass if one can be initialized with the Hash
    # val or the current Node converted to a params hash.
    def instantiate
      return nil if klass.blank?
      return val if instantiated?

      result =
        if val.instance_of?(Hash)
          klass.send(konstructor, **val)

        elsif resolved?
          klass.send(konstructor, **to_params)
        end
      warn "Instantiated #{path} to #{klass}" if result
      self.val = result
    rescue ArgumentError
      nil
    end

    def instantiated?
      klass && val.instance_of?(klass)
    end

    # Do a depth-first instantiation of this node's children, then this node.
    def instantiate_subtree
      children.each_value do |child|
        next if child.instantiated?

        child.val =
          if child.children.empty?
            child.instantiate
          else
            child.instantiate_subtree
          end
      end
      self.val = instantiate
    end

    # Return a symbol for the constructor method for klass: either :new or the
    # user-defined constructor from the config.
    def konstructor
      return nil if klass.blank?

      Ydl.class_init(klass.to_s)
    end
  end
end
