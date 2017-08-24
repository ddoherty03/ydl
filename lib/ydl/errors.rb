module Ydl
  class UserError < RuntimeError; end
  class CircularReference < RuntimeError; end
  class BadXRef < RuntimeError; end
end
