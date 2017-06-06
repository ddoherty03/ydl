require 'ydl'

module Ydl
  SYSTEM_DIR = '/etc/ydl'
  # Load all .ydl files.
  def self.load_all(**options)
    binding.pry
    file_names ||= []
    file_names += Dir.glob("#{SYSTEM_DIR}/**/*.ydl")
    file_names += Dir.glob(File.join("#{ENV['HOME']}", ".ydl/**/*.ydl"))
    dir_list = []
    dir = __dir__
    while dir != File.expand_path("~/..")
      dir_list << dir
      dir = Pathname.new(dir).parent.to_s
    end
    dir_list = dir_list.reverse
    dir_list.each do |dir|
      file_names += Dir.glob("#{dir}/*.ydl")
    end
    # Load each file in order
    file_names.each do |fn|
      Ydl.load_file(fn, options)
    end
  end

  def self.load_file(name, **options)
    puts name
  end
end
