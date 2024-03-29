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
  CONFIG_FILE = File.join(ENV['HOME'], '.ydl/config.yaml')

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
  def self.load(base = '*', ignore: nil, verbose: true)
    Ydl.read_config
    # Load each file in order to self.data.  Note that there may be many files
    # with the same basename and, hence, will be merged into the same
    # top-level hash key with the later files overriding the earlier ones.
    # Thus, it is important that ydl_files returns the file names starting
    # with those having the lowest priority and ending with those having the
    # highest.
    yaml = {}
    file_names = ydl_files(glob: base, ignore: ignore)
    warn "ydl: files found:" if verbose
    file_names.each do |fn|
      file_hash = Ydl.load_file(fn)
      yaml = yaml.deep_merge(file_hash)
    end

    # At this point, all of the files are incorporated into a single hash with
    # the top-level keys corresponding to the basenames of the files read in,
    # but all of the leaf nodes are simple ruby objects, not yet instantiated
    # into application-level objects.  That is what the Ydl::Tree class is
    # designed to accomplish, including resolving any cross-reference strings
    # of the form 'ydl:/path/to/other/part/of/ydl/tree'.  It does this by
    # constructing a Ydl::Tree from the yaml hash.
    tree = Tree.new(yaml)

    # After the leaf nodes of the tree have been instantiated by the Tree
    # object, we need to convert the Tree back into a hash, but only down to
    # the level above the reified ruby objects.  By this time, all the ruby
    # objects will have been instantiated and all cross-references resolved.
    self.data = data.merge(tree.to_hash)

    # Just return the base name's branch if base is set
    base = base.to_sym
    if data.key?(base)
      data[base]
    else
      data
    end
  rescue UserError, CircularReference, BadXRef => e
    warn e
    exit 1
  end

  # Return a Hash of a Hash with a single top-level key of the basename of the
  # given file and a value equal to the result of reading in the given YAML
  # file.  The single top-level hash key will determine the class into which
  # each of the elements of the inner Hash will be instantiated.  For example,
  # reading the file "persons.ydl" might result in a Hash of
  #
  # result[:person] = {jsmith: {first: 'John', middle: 'A.', last: 'Smith',
  # address: {street1: '123 Main', city: 'Middleton', state: 'KS', zip:
  # '66213'}, sex: 'male'}, fordmotor: {name: 'Ford Motor Company, Inc.'},
  # sex: 'entity', ...}
  #
  # Thus, each of jsmith and fordmotor will eventually get instantiated into a
  # Person object using the hash to initialize it.  Some of the keys in that
  # hash, e.g., :address, might themselves represent classes to be initialized
  # with their sub-hashes, and so forth recursively.

  def self.load_file(name, verbose: true)
    key = File.basename(name, '.ydl').to_sym
    warn "ydl: loading file #{name}..." if verbose
    result = {}
    begin
      result[key] = Psych.safe_load_file(name, permitted_classes: [Date, DateTime])
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
  def self.ydl_files(glob: '*', ignore: nil, verbose: true)
    read_config
    warn "ydl: gathering ydl files #{glob}.ydl..." if verbose
    warn "ydl: ignoring files #{ignore}.ydl..." if verbose && ignore
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
    file_names.each { |f| warn "  ->reading #{f}" } if verbose
    file_names
  end

  # From the list of file name paths, names, delete those whose basename
  # (without the .ydl extension) match the pattern or patterns in ~ignores~,
  # which can be a String, a Regexp, or an Array of either.  Return the list
  # thus filtered.
  def self.filter_ignores(names, ignores)
    ignores = [ignores] unless ignores.is_a?(Array)
    return names if ignores.empty?

    names.reject { |n| ignores.any? { |ig| File.basename(n).match(ig) } }
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
        .select { |klass| klass =~ %r{^[A-Z]} }
        .reject { |klass| klass =~ %r{^Errno::} }

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
