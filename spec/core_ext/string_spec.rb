require 'spec_helper'

module Ydl
  RSpec.describe 'String extensions' do
    it 'can detect if it is a cross-ref' do
      expect('hello, world'.xref?).to be false
      expect('   ydl:this/is/a/cross-reference '.xref?).to be true
      expect('   ydl:/this/is/a/cross-reference '.xref?).to be true
    end

    it 'can determine whether it is singular' do
      expect('person'.singular?).to be true
      expect('people'.singular?).to be false
      expect('dogs'.singular?).to be false
      expect('dog'.singular?).to be true
      expect('sheep'.singular?).to be true
    end

    it 'can determine whether it is plural' do
      expect('person'.plural?).to be false
      expect('people'.plural?).to be true
      expect('dogs'.plural?).to be true
      expect('dog'.plural?).to be false
      expect('sheep'.plural?).to be false
    end
  end
end
