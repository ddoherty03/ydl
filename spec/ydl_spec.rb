require 'spec_helper'

RSpec.describe Ydl do
  it 'has a version number' do
    expect(Ydl::VERSION).not_to be nil
  end

  describe 'ydl_files' do
    it 'finds all ydl files' do
      ydls = Ydl.ydl_files
      expect(ydls.size).to be > 5
      # The last element ought to contain the name of the cwd.
      expect(ydls.last).to match(/subproject/)
    end

    it 'can ignore ydl files by string' do
      all_ydls = Ydl.ydl_files
      some_ydls = Ydl.ydl_files(ignore: 'lawyers')
      expect(all_ydls.size).to be > some_ydls.size
      expect(all_ydls.any? { |n| n =~ /lawyer/ }).to be true
      expect(some_ydls.any? { |n| n =~ /lawyer/ }).to be false
      expect((all_ydls - some_ydls).all? { |n| n =~ /lawyer/ }).to be true
    end

    it 'can ignore ydl files by regexp' do
      all_ydls = Ydl.ydl_files
      some_ydls = Ydl.ydl_files(ignore: /law/)
      expect(all_ydls.size).to be > some_ydls.size
      expect(all_ydls.any? { |n| n =~ /lawyer/ }).to be true
      expect(some_ydls.any? { |n| n =~ /lawyer/ }).to be false
      expect((all_ydls - some_ydls).all? { |n| n =~ /lawyer/ }).to be true
    end

    it 'can ignore ydl files by array of string and regexp' do
      all_ydls = Ydl.ydl_files
      some_ydls = Ydl.ydl_files(ignore: ['courts', /law/])
      expect(all_ydls.size).to be > some_ydls.size
      expect(all_ydls.any? { |n| n =~ /lawyer|court/ }).to be true
      expect(some_ydls.any? { |n| n =~ /lawyer|court/ }).to be false
      expect((all_ydls - some_ydls).all? { |n| n =~ /lawyer|court/ }).to be true
    end
  end
  end
end
