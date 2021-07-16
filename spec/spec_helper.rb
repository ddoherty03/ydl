require 'bundler/setup'
require 'ydl'

require 'pry'
require 'pry-byebug'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # The following sets up a mock-up of a file system to use for testing under
  # the project's spec/example_files directory.  It copies the configuration
  # template file to a configuration file that changes where the system ydl
  # directory is to be found.
  begin_cwd = Dir.pwd
  begin_home = ENV['HOME']
  spec_sys_dir = File.join(__dir__, 'example_files', 'sys')
  spec_home_dir = File.join(__dir__, 'example_files', 'home', 'user')
  spec_project_dir = File.join(spec_home_dir, 'project', 'subproject')
  cfg_template = File.join(spec_home_dir, '.ydl', 'config_template.yaml')
  cfg_file = File.join(spec_home_dir, '.ydl', 'config.yaml')

  config.before(:suite) do
    # FileUtils.cp_r(spec_sys_dir, tmp_dir)
    FileUtils.cp(cfg_template, cfg_file)
    File.open(cfg_file, 'a') do |f|
      cfg_line = <<-EOS

system_ydl_dir: #{spec_sys_dir}

      EOS
      f.write(cfg_line)
    end
    ENV['HOME'] = spec_home_dir
    ENV['YDL_CONFIG_FILE'] = cfg_file
    Dir.chdir(spec_project_dir)
  end

  config.after(:suite) do
    FileUtils.rm_rf(cfg_file)
    # FileUtils.rm_rf(tmp_sys)
    ENV['HOME'] = begin_home
    Dir.chdir(begin_cwd)
  end

  config.before(:each) do
    $save_err = $stderr
    $err_output = StringIO.new
    $stderr = $err_output
  end
end
