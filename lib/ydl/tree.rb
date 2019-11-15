module Ydl
  # The Tree class holds the data read from the .ydl files while any
  # cross-references are being resolved and objects are being instantiated.
  # After all that work is done, its nodes are merged into the main Ydl.data
  # hash to be referenced by the application.
  class Tree
    # A Queue of unresolved Nodes as a Hash keyed by the path to the dependent
    # nodes with a value of the nodes on which that node depends.
    cattr_accessor :workq
    self.workq = Ydl::TopQueue.new

    cattr_accessor :trees
    self.trees = []

    def initialize(hsh)
      @id = object_id
      @root = Node.new([], hsh, root_id: @id)
      resolve_xrefs
      trees << self
    end

    def [](key)
      return nil unless @root.key?(key)

      @root[key]
    end

    def to_params
      @root.to_params
    end

    def keys
      @root.keys
    end

    def key?(key)
      @root.key?(key)
    end

    def resolve_xrefs
      workq.tsort.each do |xref|
        path = Tree.xref_to_path(xref)
        node = node_at_path(path)
        node.resolve_xref unless node.resolved?
      end
      self
    rescue TSort::Cyclic => e
      raise Ydl::CircularReference, e.to_s
    end

    # Return the node at path in Ydl.data or nil if there is no node at the
    # given path.
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
    def self.xref_to_path(str)
      match = str.to_s.clean.match(%r{\Aydl:/(?<path_str>.*)\z})
      return nil unless match

      match[:path_str].split('/').map(&:to_sym)
    end

    def self.path_to_xref(path)
      'ydl:/' + path.map(&:to_s).join('/')
    end
  end
end
