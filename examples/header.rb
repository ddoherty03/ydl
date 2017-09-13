require 'law_doc'
require 'pry'

LawDoc.document do
  title 'Brief in Support of Plaintiff\'s Motion for Summary Judgment'
  kase Ydl[:cases][:erickson]
  binding.pry
  on_behalf_of 'plaintiffs', 'nominal'
  signer Ydl[:lawyers][:ded]
  sig_date '2015-11-20'
  server signer
  service_date sig_date
end
