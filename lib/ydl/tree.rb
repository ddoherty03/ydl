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
      @tree_id = object_id
      @root = Node.new([], hsh, tree_id: @tree_id)
      # A Queue of unresolved Nodes as a Hash keyed by the path to the dependent
      # nodes with a value of the nodes on which that node depends.
      @workq = Ydl::TopQueue.new
      # Depth-first recursive build and instantiation of root node
      # cross reference paths.
      @root.build_subtree
      instantiate
    end

    def inspect
      "Tree<#{object_id}> with top-level keys: #{@root.children.keys.join(', ')}"
    end

    def to_hash
      @root.to_params
    end

    # Resolution.  Note: a 'xref' means a string of the form
    # 'ydl:/path/to/other/object' referencing an object in another part of the
    # root tree.  A 'path' is an Array of Symbols such as [:path, :to, :other,
    # :object], which can correspond to an xref and vice-versa.  A 'node'
    # means a ruby reference to the object instatiated at some path.

    # Instantiate nodes in the tree in the order of any cross-references,
    # topologically sorted.  That is, instantiate those on which others depend
    # first, and those dependent on earlier nodes last.
    def instantiate
      workq.topological_xrefs.each do |ref|
        node = node_at_xref(ref)
        if node.val.instance_of?(String) && node.val.xref?
          node.val = node_at_xref(node.val).val
        else
          node.instantiate
        end
      end
      @root.instantiate_subtree
      self
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

    # Return the Node referenced by the given xref string
    def node_at_xref(xref)
      node_at_path(Tree.xref_to_path(xref))
    end

    # Return an Array of symbols representing a the path described by a ydl xref
    # string. Return nil if str is not an xref string.
    def self.xref_to_path(xref)
      match = xref.to_s.clean.match(%r{\Aydl:/(?<path_str>.*)\z})
      return nil unless match

      match[:path_str].split('/').map(&:to_sym)
    end

    def self.path_to_xref(path)
      "ydl:/#{path.map(&:to_s).join('/')}"
    end
  end
end
