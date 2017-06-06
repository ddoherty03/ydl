require 'ydl'

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
    binding.pry
    # Load each file in order to self.data
    file_names = ydl_files(options)
    file_names.each do |fn|
      Ydl.load_file(fn, options)
    end
  end

  def self.load_file(name, **options)
    puts name
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
    file_names
  end

  def self.read_config
    cfg_file = File.expand_path(CONFIG_FILE)
    Ydl.config = YAML.load_file(cfg_file) if File.exist?(cfg_file)
  end

  read_config
end
