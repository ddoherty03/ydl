require 'spec_helper'

RSpec.describe Ydl do
  it 'has a version number' do
    expect(Ydl::VERSION).not_to be nil
  end

  describe 'ydl_files' do
    it 'finds all ydl files' do
      ydls = Ydl.ydl_files
      expect(ydls.size).to be > 5
      expect(ydls.last).to match(/subproject/)
    end
  end
end
