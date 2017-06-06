require 'bundler/setup'
require 'ydl'
require 'pry'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  ydl_dir = File.expand_path('~/.ydl')
  config_yaml = File.join(ydl_dir, 'config.yaml')
  config_yaml_template = File.join(__dir__, 'example_files', 'ydl', 'config.yaml')
  keep_ydl_dir = false
  keep_config_yaml = false
  spec_cwd = File.join(__dir__, '../tmp/project/subproject')
  spec_cwd_parent = File.join(__dir__, '../tmp')
  spec_template_parent = File.join(__dir__, 'example_files', 'project')
  begin_cwd = Dir.pwd

  config.before(:suite) do
    if Dir.exist?(ydl_dir)
      keep_ydl_dir = true
    else
      FileUtils.mkdir_p(ydl_dir)
    end
    if File.exist?(config_yaml)
      keep_config_yaml = true
    else
      FileUtils.cp(config_yaml_template, ydl_dir)
    end
    FileUtils.mkdir_p(spec_cwd) unless Dir.exist?(spec_cwd)
    FileUtils.cp_r(spec_template_parent, spec_cwd_parent)
    Dir.chdir(spec_cwd)
  end

  config.after(:suite) do
    FileUtils.rm_f(config_yaml) unless keep_config_yaml
    FileUtils.rm_rf(ydl_dir) unless keep_ydl_dir
    FileUtils.rm_rf(spec_cwd_parent)
    Dir.chdir(begin_cwd)
  end
end
