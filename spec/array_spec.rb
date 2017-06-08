require 'spec_helper'

module Ydl
  using ArrayRefinements
  RSpec.describe ArrayRefinements do
    it 'can detect if other array is its prefix' do
      arr_a = [:a, :b, :c, :d]
      arr_b = [:a, :b, :c]
      expect(arr_a.prefixed_by(arr_b)).to be true
      expect(arr_a.prefixed_by(arr_a)).to be true
      expect(arr_b.prefixed_by(arr_a)).to be false
    end
  end
end
