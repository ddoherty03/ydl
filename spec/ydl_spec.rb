require 'spec_helper'

RSpec.describe Ydl do
  before :all do
    require 'law_doc'
  end

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

  describe 'class instantiation' do
    it 'should be able to find candidate classes within any module' do
      cnds = Ydl.candidate_classes(:set)
      expect(cnds.size).to be > 3
      expect(cnds).to include(Set)
      expect(cnds).to include(Psych::Set)
      expect(cnds).to include(RSpec::Core::Set)
    end

    it 'should be able to find candidate classes within modules as string' do
      cnds = Ydl.candidate_classes(:set, 'Psych')
      expect(cnds.size).to eq(1)
      expect(cnds).to include(Psych::Set)

      cnds = Ydl.candidate_classes(:set, ',Psych, RSpec::Core')
      expect(cnds.size).to eq(3)
      expect(cnds).to include(Set)
      expect(cnds).to include(Psych::Set)
      expect(cnds).to include(RSpec::Core::Set)
    end

    it 'should find candidate_classes with modules as array' do
      cnds = Ydl.candidate_classes(:set, ['', 'Psych'])
      expect(cnds.size).to eq(2)
      expect(cnds).to include(Set)
      expect(cnds).to include(Psych::Set)
    end

    it 'should know how to map keys to classes' do
      Ydl.read_config
      expect(Ydl.class_map(:persons)).to eq(LawDoc::Person)
      expect(Ydl.class_map(:address)).to eq(LawDoc::Address)
      expect(Ydl.class_map(:junk)).to be nil
    end

    it 'should know init method for classes' do
      Ydl.read_config
      # expect(Ydl.class_init('LawDoc::Person')).to eq(:from_hash)
      expect(Ydl.class_init('LawDoc::Address')).to eq(:new)
    end
  end

  describe 'selective load' do
    before :all do
      @people = Ydl.load('persons')
      @lawyers = Ydl.load('lawyers')
    end

    it 'should return a merged Hash keyed by symbols' do
      expect(@people.class).to eq(Hash)
      expect(@people.class).to eq(Hash)
      expect(@people[:revive].class).to eq(LawDoc::Person)
      expect(@people.keys.sort)
        .to eq(%i[erickson mainstreet mdg morgan revive tdoherty zmeac zmpef1 zmpef2])

      expect(@lawyers.class).to eq(Hash)
      expect(@lawyers.class).to eq(Hash)
      expect(@lawyers[:ded].class).to eq(LawDoc::Lawyer)
      expect(@lawyers.keys.sort)
        .to eq(%i[cjh dclarke ded jclarke mcrisp pittenger rjones tfarrell])
    end

    it 'should resolve cross references' do
      expect(@people[:erickson].name).to eq('Erickson Incorporated')
      expect(@lawyers[:ded].last).to eq('Doherty')
    end

    it 'should instantiate all persons' do
      klasses = { persons: 'LawDoc::Person' }
      klasses.each_pair do |sym, kls|
        Ydl[sym].each_pair do |_nm, obj|
          expect(obj.class.name).to eq(kls)
        end
      end
    end

    it 'should instantiate all lawyers' do
      klasses = { lawyers: 'LawDoc::Lawyer' }
      klasses.each_pair do |sym, kls|
        Ydl[sym].each_pair do |_nm, obj|
          expect(obj.class.name).to eq(kls)
        end
      end
    end

    it 'should allow access through Ydl[]' do
      expect(Ydl.data[:persons].class).to eq(Hash)
      expect(Ydl[:persons].class).to eq(Hash)
      expect(Ydl.data[:lawyers].class).to eq(Hash)
      expect(Ydl[:lawyers].class).to eq(Hash)
    end
  end

  describe 'load everything' do
    before :all do
      @hsh = Ydl.load
    end

    it 'should return a merged Hash keyed by symbols' do
      expect(@hsh.class).to eq(Hash)
      expect(Ydl.data.class).to eq(Hash)
      expect(Ydl.data[:lawyers][:ded].class).to eq(LawDoc::Lawyer)
      expect(Ydl.data.keys.sort)
        .to eq(%i[cases constants courts judges junk lawyers persons])
    end

    it 'should resolve cross references' do
      expect(Ydl[:cases][:erickson].parties.first.lawyers.first.last)
        .to eq('Doherty')
    end

    it 'should instantiate all objects' do
      klasses = { cases: 'LawDoc::Case', courts: 'LawDoc::Court',
                  judges: 'LawDoc::Judge', lawyers: 'LawDoc::Lawyer',
                  persons: 'LawDoc::Person' }
      klasses.each_pair do |sym, kls|
        Ydl[sym].each_value do |obj|
          expect(obj.class.name).to eq(kls)
        end
      end
    end

    it 'should include court in mainstreet case' do
      mainstreet = Ydl[:cases][:mainstreet]
      expect(mainstreet.court.state).to eq('KS')
    end

    it 'should allow access through []' do
      expect(Ydl[:lawyers].class).to eq(Hash)
      expect(Ydl[:lawyers][:ded].class).to eq(LawDoc::Lawyer)
      expect(Ydl[:lawyers][:ded].address.class).to eq(LawDoc::Address)
      ad = Ydl[:cases][:erickson].parties.first.lawyers.first.address
      expect(ad.class).to eq(LawDoc::Address)
      expect(ad.city).to eq('Overland Park')
    end
  end
end
