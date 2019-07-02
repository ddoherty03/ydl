# Extension of Array class.
class Array
  def xref?
    select { |v| v.is_a?(String) }.any?(&:xref?)
  end
end
