require 'spec_helper'

module Ydl
  RSpec.describe 'Boolean extensions' do
    it 'can detect if it is a cross-ref' do
      expect(true.xref?).to be false
      expect(false.xref?).to be false
    end
  end
end
