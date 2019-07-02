require 'spec_helper'

module Ydl
  RSpec.describe 'Date extensions' do
    it 'can detect if it is a cross-ref' do
      expect(Date.today.xref?).to be false
    end
  end
end
