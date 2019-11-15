require 'spec_helper'

RSpec.describe Ydl do
  before :all do
    require 'test/law_doc_stub'
  end

  describe 'load ydl_file with errors' do
    it 'shows file where error occurred' do
      expect {
        Ydl.load_file('../../../../person_err.ydl')
      }.to raise_error Ydl::UserError, /person_err.*line.*column/
    end
  end
end
