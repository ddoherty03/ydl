module Ydl
  module ArrayRefinements
    refine Array do
      # Return true of this array has other as a prefix.  If self is [:a, :b, :c,
      # :d], then other is a prefix if it consists of elements equal to the
      # corresponding element of self through other's whole length.
      def prefixed_by(other)
        return false if other.length > length
        residuals = zip(other).drop_while { |(a, b)| a == b }
        residuals.empty? || residuals.all? { |(a, b)| !a.nil? && b.nil? }
      end
    end
  end
end
