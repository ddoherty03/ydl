require 'ydl'
require 'fat_core/string'
require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/hash/keys'
# For singularize, camelize
require 'active_support/core_ext/string'

# Name-space module for the ydl gem.
module Ydl
  using ArrayRefinements

  SYSTEM_DIR = '/usr/local/share/ydl'.freeze
  CONFIG_FILE = '~/.ydl/config.yaml'.freeze

  @@config_printed = false

  class << self
    # Configuration hash for Ydl, read from ~/.ydl/config.yaml on require.
    attr_accessor :config

    # Holder of all the data read from the .ydl files as a Hash
    attr_accessor :data
  end
  self.config = { class_map: {}, class_init: {} }
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
  #   any of the given strings or regexp's in the given Array.
  #
  # @param [Hash] options selectively ignore files; use alternative config
  # @return [Hash] data read from .ydl files as a Hash
  def self.load(base = '*', ignore: nil)
    Ydl.read_config
    # Load each file in order to self.data
    yaml = {}
    file_names = ydl_files(glob: base, ignore: ignore)
    file_names.each do |fn|
      yaml = yaml.deep_merge(Ydl.load_file(fn))
    end

    tree = Tree.new(yaml).to_params
    self.data = data.merge(tree)

    # Just return the base name's branch if base is set
    base = base.to_sym
    if data.key?(base)
      data[base]
    else
      data
    end
  rescue UserError, CircularReference, BadXRef => e
    $stderr.puts e
    exit 1
  end

  # Return a Hash with a single key of the basename of the given file and a
  # value equal to the result of reading in the given YAML file.
  def self.load_file(name)
    key = File.basename(name, '.ydl').to_sym
    result = {}
    begin
      result[key] = Psych.load_file(name)
    rescue Psych::SyntaxError => e
      usr_msg = "#{File.expand_path(name)}: #{e.problem} #{e.context} at line #{e.line} column #{e.column}"
      raise UserError, usr_msg
    end
    result[key].deep_symbolize_keys! if result[key].is_a?(Hash)
    result
  end

  # Return the component at key from Ydl.data.
  def self.[](key)
    msg = "no key '#{key}' in Ydl data"
    raise UserError, msg unless data.key?(key)

    Ydl.data[key]
  end

  # Return a list of all the .ydl files in order from lowest to highest
  # priority, ignoring those whose basenames match the ignore parameter, which
  # can be a String, a Regexp, or an Array of either (all of which are matched
  # against the basename without the .ydl extension).
  def self.ydl_files(glob: '*', ignore: nil)
    read_config
    sys_ydl_dir = Ydl.config[:system_ydl_dir] || '/etc/ydl'
    file_names = []
    unless sys_ydl_dir.blank?
      file_names += Dir.glob("#{sys_ydl_dir}/**/#{glob}.ydl")
    end
    file_names += Dir.glob(File.join(ENV['HOME'], ".ydl/**/#{glob}.ydl"))

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
      file_names += Dir.glob("#{d}/#{glob}.ydl")
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

  mattr_accessor :class_for_cache
  self.class_for_cache = {}

  def self.class_for(key)
    return nil if key.blank?
    return class_for_cache[key] if class_for_cache[key]
    return class_map(key) if class_map(key)

    klasses = candidate_classes(key, Ydl.config[:class_modules])
    return nil if klasses.empty?

    class_for_cache[key] = klasses.first
    klasses.first
  end

  def self.class_map(key)
    return nil if key.blank?
    return nil if key.is_a?(Numeric)

    key = key.to_sym
    return nil unless Ydl.config[:class_map].key?(key)

    klass_name = Ydl.config[:class_map][key]
    klass_name.constantize
  rescue NameError
    raise "no declared class named '#{klass_name}'"
  end

  def self.class_init(klass_name)
    klass_name = klass_name.to_sym
    klass_config = Ydl.config[:class_init]
    return :new unless klass_config.key?(klass_name)

    klass_config[klass_name].to_sym
  end

  mattr_accessor :all_classes

  def self.candidate_classes(key, modules = nil)
    # Add all known classes to module attribute as a cache on first call; except
    # Errno
    all_classes ||=
      ObjectSpace.each_object(Class)
        .map(&:to_s)
        .select { |klass| klass =~ /^[A-Z]/ }
        .reject { |klass| klass =~ /^Errno::/ }

    suffix = key.to_s.singularize.camelize
    modules = modules.split(',').map(&:clean) if modules.is_a?(String)
    all_classes.select { |cls|
      if modules
        # If modules given, restrict to those classes within the modules, where
        # a blank string is the main module.
        modules.any? do |mod|
          cls =~ (mod.blank? ? /\A#{suffix}\z/ : /\A#{mod}::#{suffix}\z/)
        end
      else
        # Otherwise, all classes ending with suffix.
        cls == suffix || cls =~ /::#{suffix}\z/
      end
    }.sort.map(&:constantize)
  end

  # Set the Ydl.config hash to the configuration given in the YAML string, cfg,
  # or read the config from the file ~/.ydl/config.yaml if cfg is nil
  def self.read_config
    cfg_file = ENV['YDL_CONFIG_FILE'] || CONFIG_FILE
    cfg_file = File.expand_path(cfg_file)
    Ydl.config ||= {}
    Ydl.config = YAML.load_file(cfg_file) if File.exist?(cfg_file)
    Ydl.config.deep_symbolize_keys!
    Ydl.config[:class_map] ||= {}
    Ydl.config[:class_init] ||= {}
    Ydl.config[:system_ydl_dir] ||= SYSTEM_DIR
    Ydl.config
  end
end
