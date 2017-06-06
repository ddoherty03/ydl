require 'ydl'

module Ydl
  SYSTEM_DIR = '/etc/ydl'
  CONFIG_FILE = '~/.ydl/config.yaml'

  class << self
    # Configuration hash for Ydl, read from ~/.ydl/config.yaml on require.
    attr_accessor :config
  end
  self.config = {}

  # Load all .ydl files.
  def self.load_all(**options)
    binding.pry
    # Load each file in order
    file_names = find_dd_files(options)
    file_names.each do |fn|
      Ydl.load_file(fn, options)
    end
  end

  def self.load_file(name, **options)
    puts name
  end

  def self.find_dd_files(**options)
    file_names = []
    file_names += Dir.glob("#{SYSTEM_DIR}/**/*.ydl")
    file_names += Dir.glob(File.join("#{ENV['HOME']}", ".ydl/**/*.ydl"))

    # Find directories from pwd to home, then reverse
    dir_list = []
    dir = __dir__
    while dir != File.expand_path("~/..")
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
