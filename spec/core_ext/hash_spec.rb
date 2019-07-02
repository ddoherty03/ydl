require 'spec_helper'

module Ydl
  RSpec.describe Hash do
    it 'can be topologically sorted if values are arrays' do
      hash_a = {:a => [:d], :b => [:d, :c], :c => [],
                :d => [:g, :h], :g => [], :h => []}
      expect(hash_a.tsort).to eq([:g, :h, :d, :a, :c, :b])
    end

    it 'can tell its not a cross-ref' do
      hash_a = {:a => [:d], :b => [:d, :c], :c => [],
                :d => [:g, :h], :g => [], :h => []}
      expect(hash_a.xref?).to be false
      hash_b = {:a => true, :b => 'ydl:hello/world'}
      expect(hash_b.xref?).to be true
    end
  end
end
