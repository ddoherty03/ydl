module Ydl
  # The Tree class holds the data read from the .ydl files while any
  # cross-references are being resolved and objects are being instantiated.
  # After all that work is done, its nodes are merged into the main Ydl.data
  # hash to be referenced by the application.
  class Tree
    attr_reader :tree_id, :root, :workq

    # A new Tree is initialized with a Hash, which is itself a tree structure,
    # but not of instantiated classes of the type we want.  The nodes of the
    # input hash will be basic ruby objects such as Strings, Dates, Numerics,
    # and so forth, just as they are read from the ydl files by Psych.  Some
    # of the String objects will be in the form of cross-references to other
    # parts of this tree, or of other trees that my not even exist at the time
    # this one is being built.
    def initialize(hsh)
      $stop = false
      @tree_id = object_id
      @root = Node.new([], hsh, tree_id: @tree_id)
      # A Queue of unresolved Nodes as a Hash keyed by the path to the dependent
      # nodes with a value of the nodes on which that node depends.
      @workq = Ydl::TopQueue.new

      # Depth-first recursive instantiation of root node, adding unresolved
      # cross reference paths.
      @root.reify
      # Replace xrefs with reified nodes that they point to
      resolve_xrefs
      # Instantiate nodes that could not be instantiated before the
      # cross-references were resolved.
      $stop = true
      instantiate
    end

    def to_hash
      @root.to_params
    end

    # Resolution.  Note: a 'xref' means a string of the form
    # 'ydl:/path/to/other/object' referencing an object in another part of the
    # root tree.  A 'path' is an Array of Symbols such as [:path, :to, :other,
    # :object], which can correspond to an xref and vice-versa.  A 'node'
    # means a ruby reference to the object instatiated at some path.

    # All the cross-reference dependencies have been recorded on the @workq,
    # which records the dependencies and, using TSort via its TopQueue#tsort
    # method.  That will enumerate each xref that was either pointing to
    # another node or was pointed to by another node in the order that
    # eliminates any forward references to xrefs later in the list.


    # Attempt to resolve all the xrefs inserted into the given q, a
    # Ydl::TopQueue object.
    def resolve_xrefs
      workq.replacements.each_pair do |from_path, to_xref|
        from_node = node_at_path(from_path)
        to_node = node_at_path(xref_to_path(to_xref))
        from_node.val = to_node.val
        from_node.resolved = true
      end
      self
    rescue TSort::Cyclic => e
      raise Ydl::CircularReference, e.to_s
    end

    # Instantiate nodes in the tree that can be instantiated but are not
    def instantiate
      root.instantiate_subtree
    end

    # Return the Ydl::Node at path in Ydl.data or nil if there is no node at
    # the given path.
    def node_at_path(path)
      node = @root
      partial_path = []
      path.each do |key|
        if node[key].nil?
          xref = Tree.path_to_xref(path)
          pxref = Tree.path_to_xref(partial_path)
          klass = node.klass
          msg = "can\'t resolve cross-ref '#{xref}' beyond #{klass} object '#{pxref}'"
          raise Ydl::BadXRef, msg
        end
        partial_path << key
        node = node[key]
      end
      node
    end

    # Return an Array of symbols representing a the path described by a ydl xref
    # string. Return nil if str is not an xref string.
    def xref_to_path(xref)
      match = xref.to_s.clean.match(%r{\Aydl:/(?<path_str>.*)\z})
      return nil unless match

      match[:path_str].split('/').map(&:to_sym)
    end

    def self.path_to_xref(path)
      "ydl:/#{path.map(&:to_s).join('/')}"
    end
  end
end
