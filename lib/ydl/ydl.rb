require 'ydl'
require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/hash/keys'

module Ydl
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
  # - ignore: [String|/regexp/] :: ignore all .ydl files whose base name matches any of
  #   the given strings or regexp's.
  # - config: String :: use the config file given in the pathname String instead
  #   of the default in ~/.ydl/config.yaml.
  #
  # @param [Hash] options selectively ignore files; use alternative config
  # @return [Hash] data read from .ydl files as a Hash
  def self.load_all(**options)
    # Apply special config, if any
    read_config(options[:config].to_s) if options[:config]

    # Load each file in order to self.data
    file_names = ydl_files(options)
    file_names.each do |fn|
      self.data = data.deep_merge(Ydl.load_file(fn, options))
    end

    # Revert special config to default config
    read_config if options[:config]
    data
  end

  # Return a Hash with a single key of the basename of the given file and a
  # value equal to the result of reading in the given YAML file.
  def self.load_file(name, **options)
    key = File.basename(name, '.ydl')
    result = {}
    result[key] = YAML.load_file(name)
    result[key].deep_symbolize_keys! if result[key].is_a?(Hash)
    result
  end

  def self.ydl_files(**options)
    file_names = []
    file_names += Dir.glob("#{Ydl.config['system_ydl_dir']}/**/*.ydl")
    file_names += Dir.glob(File.join(ENV['HOME'], '.ydl/**/*.ydl'))

    # Find directories from pwd to home, then reverse
    dir_list = []
    dir = Dir.pwd
    while dir != File.expand_path('~/..')
      dir_list << dir
      dir = Pathname.new(dir).parent.to_s
    end
    dir_list = dir_list.reverse

    # Gather the .ydl files in those directories
    dir_list.each do |dir|
      file_names += Dir.glob("#{dir}/*.ydl")
    end

    # Filter out any files whose base name matches options[:ignore]
    unless options[:ignore].blank?
      file_names = filter_ignores(file_names, options[:ignore])
    end
    file_names
  end

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

  def self.read_config(cfg_file = nil)
    cfg_file = File.expand_path(cfg_file) if cfg_file
    cfg_file ||= File.expand_path(CONFIG_FILE)
    Ydl.config = YAML.load_file(cfg_file) if File.exist?(cfg_file)
    Ydl.config['system_ydl_dir'] ||= SYSTEM_DIR
    Ydl.config
  end

  read_config
end
