require 'bundler/setup'
require 'ydl'
require 'pry'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # The following sets up a mock-up of a file system to use for testing under
  # the project's tmp directory.  It modifies the configuration file there to
  # include a system ydl directory as well.
  spec_sys_dir = File.join(__dir__, 'example_files', 'sys')
  spec_home_dir = File.join(__dir__, 'example_files', 'home')
  tmp_dir = File.expand_path(File.join(__dir__, '../tmp'))
  tmp_home = File.join(tmp_dir, 'home')
  tmp_user_home = File.join(tmp_dir, 'home', 'user')
  tmp_sys = File.join(tmp_dir, 'sys')
  tmp_sys_ydl_dir = File.join(tmp_dir, 'sys', 'ydl')
  tmp_project_dir = File.join(tmp_user_home, 'project', 'subproject')
  begin_cwd = Dir.pwd
  begin_home = ENV['HOME']

  config.before(:suite) do
    FileUtils.cp_r(spec_sys_dir, tmp_dir)
    FileUtils.cp_r(spec_home_dir, tmp_dir)
    cfg_file = File.join(tmp_user_home, '.ydl', 'config.yaml')
    File.open(cfg_file, 'a') do |f|
      cfg_line = <<-EOS

system_ydl_dir: #{tmp_sys_ydl_dir}

      EOS
      f.write(cfg_line)
    end
    ENV['HOME'] = tmp_user_home
    Dir.chdir(tmp_project_dir)
  end

  config.after(:suite) do
    FileUtils.rm_rf(tmp_home)
    FileUtils.rm_rf(tmp_sys)
    ENV['HOME'] = begin_home
    Dir.chdir(begin_cwd)
  end
end
