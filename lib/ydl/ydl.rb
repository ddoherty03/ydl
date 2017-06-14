require 'ydl'
require 'fat_core/string'
require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/hash/keys'
# For singularize, camelize
require 'active_support/core_ext/string'

module Ydl
  class CircularReference < RuntimeError; end

  using ArrayRefinements

  SYSTEM_DIR = '/usr/local/share/ydl'.freeze
  CONFIG_FILE = '~/.ydl/config.yaml'.freeze

  class << self
    # Configuration hash for Ydl, read from ~/.ydl/config.yaml on require.
    attr_accessor :config

    # Holder of all the data read from the .ydl files as a Hash
    attr_accessor :data
  end
  self.config = {}
  self.data = {}

  # Load all .ydl files, subject to the given options.  After loading, the data
  # in the .ydl files will be available in Ydl.data and accessible with Ydl[].
  #
  # The following options affect which files are loaded:
  #
  # - ignore: String :: ignore all .ydl files whose base name matches the given
  #   string.
  # - ignore: /regexp/ :: ignore all .ydl files whose base name matches the
  #   given regexp.
  # - ignore: [String|/regexp/] :: ignore all .ydl files whose base name matches
  #   any of the given strings or regexp's.
  # - config: String :: use the config file given in the pathname String instead
  #   of the default in ~/.ydl/config.yaml.
  #
  # @param [Hash] options selectively ignore files; use alternative config
  # @return [Hash] data read from .ydl files as a Hash
  def self.load_all(resolve: true, instantiate: true, config: nil, ignore: nil)
    # Apply special config, if any, or ~/.ydl/config.yaml if config is nil
    read_config(config)

    # Load each file in order to self.data
    file_names = ydl_files(ignore: ignore, config: config)
    file_names.each do |fn|
      self.data = data.deep_merge(Ydl.load_file(fn))
    end

    instantiate_objects(data, nil) if instantiate
    resolve_xref(data) if resolve

    # Revert special config to default config
    read_config if config
    data
  end

  # Return a Hash with a single key of the basename of the given file and a
  # value equal to the result of reading in the given YAML file.
  def self.load_file(name)
    key = File.basename(name, '.ydl').to_sym
    result = {}
    result[key] = YAML.load_file(name)
    result[key].deep_symbolize_keys! if result[key].is_a?(Hash)
    result
  end

  # Return the component at key from Ydl.data.
  def self.[](key)
    Ydl.data[key]
  end

  # Return a list of all the .ydl files in order from lowest to highest
  # priority, ignoring those whose basenames match the ignore parameter, which
  # can be a String, a Regexp, or an Array of either (all of which are matched
  # against the basename without the .ydl extension).
  def self.ydl_files(ignore: nil, config: nil)
    read_config(config)
    file_names = []
    file_names += Dir.glob("#{Ydl.config[:system_ydl_dir]}/**/*.ydl")
    file_names += Dir.glob(File.join(ENV['HOME'], '.ydl/**/*.ydl'))

    # Find directories from pwd to home (or root), then reverse
    dir_list = []
    dir = Dir.pwd
    while dir != File.expand_path('~/..') && dir != '/'
      dir_list << dir
      dir = Pathname.new(dir).parent.to_s
    end
    dir_list = dir_list.reverse

    # Gather the .ydl files in those directories
    dir_list.each do |d|
      file_names += Dir.glob("#{d}/*.ydl")
    end

    # Filter out any files whose base name matches options[:ignore]
    file_names = filter_ignores(file_names, ignore) unless ignore.blank?
    file_names
  end

  # From the list of file name paths, names, delete those whose basename
  # (without the .ydl extension) match the pattern or patterns in ~ignores~,
  # which can be a String, a Regexp, or an Array of either.  Return the list
  # thus filtered.
  def self.filter_ignores(names, ignores)
    ignores = [ignores] unless ignores.is_a?(Array)
    return names if ignores.empty?
    result = names
    ignores.each do |ign|
      names.each do |nm|
        base = File.basename(nm, '.ydl')
        match = false
        match ||= ign.match(base) if ign.is_a?(Regexp)
        match ||= (ign == base) if ign.is_a?(String)
        result.delete(nm) if match
      end
    end
    result
  end

  # Return an Array of symbols and integers representing a the path described by
  # a ydl xref string. Return nil if str is not an xref string.
  def self.xref_to_path(str)
    match = str.to_s.clean.match(%r{\Aydl:/(?<path_str>.*)\z})
    return nil unless match
    match[:path_str].split('/').map do |k|
      if k =~ /\A\s*[0-9]+\s*\z/
        k.to_i
      else
        k.to_sym
      end
    end
  end

  # Convert all the cross-references of the form ydl:/path/to/other/entry to the
  # contents of that other entry by dup-ing the other entry into the Hash tree
  # where the cross-reference appeared.  This modifies Ydl.data in place.
  def self.resolve_xref(tree, path_to_here: [])
    root_path = path_to_here.dup
    case tree
    when Hash
      tree.each_pair do |key, val|
        resolve_xref(val, path_to_here: root_path + [key])
      end
    when Array
      tree.each_with_index do |val, k|
        resolve_xref(val, path_to_here: root_path + [k])
      end
    when String
      path_to_there = xref_to_path(tree)
      if path_to_there
        if path_to_here.prefixed_by(path_to_there)
          raise CircularReference,
                "circular reference: '#{tree}' at #{path_to_here}"
        end
        if (there_node = node_at_path(path_to_there))
          set_node(path_to_here, there_node.dup)
        else
          STDERR.puts "invalid cross reference: #{tree}"
        end
      end
    end
  end

  # Return the node at path in Ydl.data or nil if there is no node at the given
  # path.
  def self.node_at_path(path)
    node = Ydl.data
    path.each do |key|
      if node.is_a?(Hash) && node.key?(key)
        node = node[key]
      elsif node.is_a?(Array) && key.to_i <= node.length
        node = node[key.to_i]
      else
        return nil
      end
    end
    node
  end

  # Set the node at path in Ydl.data to node.
  def self.set_node(path, node)
    cur_node = Ydl.data
    path[0..-2].each do |key|
      cur_node = cur_node[key]
    end
    cur_node[path.last] = node
  end

  def self.instantiate_objects(cur_node, cur_klass, path = [])
    # STDERR.puts path.join(':')
    case cur_node
    when Hash
      if cur_klass
        instantiate_here = true
        begin
          # Two cases to consider: (1) cur_node is the argument hash for
          # instantiating an object at cur_node, (2) cur_node is a hash, each
          # element of which is to be instantiated as an object of cur_klass.
          if instantiate_here
            cur_node.each_pair do |key, val|
              next unless val.is_a?(Hash) || val.is_a?(Array)
              instantiate_objects(cur_node[key], nil, path + [key])
              klass = class_for(key) # || cur_klass
              next if xref_to_path(val)
              if klass
                konstructor = class_init(klass.name)
                set_node(path + [key], klass.send(konstructor, val))
              end
            end
            unless xref_to_path(cur_node)
              konstructor = class_init(cur_klass.name)
              set_node(path, cur_klass.send(konstructor, cur_node))
            end
          else
            cur_node.each_pair do |key, val|
              next unless val.is_a?(Hash) || val.is_a?(Array)
              # Instantiate all the sub-nodes first
              klass = class_for(key)
              instantiate_objects(cur_node[key], klass, path + [key])
              # Then set the in the Ydl.data tree
              next if xref_to_path(val)
              konstructor = class_init(cur_klass.name)
              set_node(path + [key], cur_klass.send(konstructor, val))
            end
          end
        rescue ArgumentError, /unknown keywords/ => ex
          raise ex unless instantiate_here
          instantiate_here = false
          retry
        end
      else
        cur_node.each_pair do |key, val|
          next unless val.is_a?(Hash) || val.is_a?(Array)
          klass = class_for(key)
          instantiate_objects(val, klass, path + [key])
          set_node(path + [key], cur_node[key])
        end
      end
    when Array
      # Two cases: (1) cur_klass is defined, so we want an Array of instantiated
      # cur_klass objects at cur_node, (2) cur_klass is nil, just recurse down
      # the tree.
      if cur_klass
        konstructor = class_init(cur_klass.name)
        cur_node.each_with_index do |node, k|
          instantiate_objects(node, nil, path + [k])
          next if xref_to_path(node)
          set_node(path + [k], cur_klass.send(konstructor, node))
        end
      else
        cur_node.each_with_index do |node, k|
          instantiate_objects(node, nil, path + [k])
        end
      end
    end
  end

  #
  mattr_accessor :class_for_cache
  self.class_for_cache = {}

  def self.class_for(key)
    return nil if key.blank?
    if class_for_cache[key]
      return class_for_cache[key]
    end
    return class_map(key) if class_map(key)
    klasses = candidate_classes(key, Ydl.config[:class_modules])
    return nil if klasses.empty?
    class_for_cache[key] = klasses.first
    klasses.first
  end

  def self.class_map(key)
    return nil if key.blank?
    return nil if key.is_a?(Numeric)
    return nil unless Ydl.config[:class_map].keys.include?(key.to_sym)
    klass_name = Ydl.config[:class_map][key.to_sym]
    klass_name.constantize
  rescue NameError => ex
    raise "no declared class named '#{klass_name}'"
  end

  def self.class_init(klass_name)
    return :new unless Ydl.config[:class_init].keys.include?(klass_name.to_sym)
    Ydl.config[:class_init][klass_name.to_sym].to_sym
  end

  mattr_accessor :all_classes

  def self.candidate_classes(key, modules = nil)
    # Add all known classes to module attribute as a cache on first call; except
    # Errno
    all_classes ||= ObjectSpace.each_object(Class).map(&:to_s)
                    .select { |c| c =~ /^[A-Z]/ }
                    .reject { |c| c =~ /^Errno::/ }

    suffix = key.to_s.singularize.camelize
    modules = modules.split(',').map(&:clean) if modules.is_a?(String)
    all_classes.select { |cls|
      if modules
        # If modules given, restrict to those classes within the modules, where
        # a blank string is the main module.
        modules.any? do |m|
          cls =~ (m.blank? ? /\A#{suffix}\z/ : /\A#{m}::#{suffix}\z/)
        end
      else
        # Otherwise, all classes ending with suffix.
        cls == suffix || cls =~ /::#{suffix}\z/
      end
    }.sort.map(&:constantize)
  end

  # Set the Ydl.config hash to the configuration given in the YAML string, cfg,
  # or read the config from the file ~/.ydl/config.yaml if cfg is nil
  def self.read_config(cfg = nil)
    if cfg
      Ydl.config = YAML.safe_load(cfg)
    else
      cfg_file = File.expand_path(CONFIG_FILE)
      Ydl.config = YAML.load_file(cfg_file) if File.exist?(cfg_file)
    end
    Ydl.config.deep_symbolize_keys!
    Ydl.config[:system_ydl_dir] ||= SYSTEM_DIR
    Ydl.config
  end
end
