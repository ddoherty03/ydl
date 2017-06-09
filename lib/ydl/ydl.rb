require 'ydl'
require 'fat_core/string'
require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/hash/keys'

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
  def self.load_all(resolve: true, config: nil, ignore: nil)
    # Apply special config, if any, or ~/.ydl/config.yaml if config is nil
    read_config(config)

    # Load each file in order to self.data
    file_names = ydl_files(ignore: ignore, config: config)
    file_names.each do |fn|
      self.data = data.deep_merge(Ydl.load_file(fn))
    end

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
    file_names += Dir.glob("#{Ydl.config['system_ydl_dir']}/**/*.ydl")
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
      match = tree.clean.match(%r{\Aydl:/(?<path_str>.*)\z})
      #binding.pry if tree =~ /zmeac/
      if match
        path_to_there = match[:path_str].split('/').map do |k|
          if k =~ /\A\s*[0-9]+\s*\z/
            k.to_i
          else
            k.to_sym
          end
        end
        if path_to_here.prefixed_by(path_to_there)
        elsif (there_node = node_from_path(path_to_there))
          #puts "valid cross reference: #{tree}"
          #puts "  resolves to #{there_node}"
          raise CircularReference,
                "circular reference: '#{tree}' at #{path_to_here}"
        end
        else
          STDERR.puts "invalid cross reference: #{tree}"
        end
      end
      # Other types are left alone
    end
  end

  def self.node_from_path(path)
    node = Ydl.data
    path.each do |key|
      if node.is_a?(Hash) && node.key?(key)
        node = node[key]
      elsif node.is_a?(Array) && key.to_i <= node.length
        # We want the index for arrays to be 1-based.
        node = node[key.to_i - 1]
      else
        return nil
      end
    end
    node
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
    Ydl.config['system_ydl_dir'] ||= SYSTEM_DIR
    Ydl.config
  end
end
