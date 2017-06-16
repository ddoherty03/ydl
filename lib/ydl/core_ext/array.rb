class Array
  def xref?
    any?(&:xref?)
  end
end
