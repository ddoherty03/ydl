require 'spec_helper'

module Ydl
  RSpec.describe 'Numeric extensions' do
    it 'can detect if it is a cross-ref' do
      require 'bigdecimal'
      expect(25.xref?).to be false
      expect(3.14159.xref?).to be false
      expect(BigDecimal('18.578').xref?).to be false
      expect(Rational(2, 3).xref?).to be false
    end
  end
end
