require 'tsort'

# Extend Hash for use with TSort and add xref?.
class Hash
  include TSort

  alias tsort_each_node each_key

  def tsort_each_child(node, &block)
    fetch(node).each(&block)
  end

  def xref?
    values.select { |v| v.is_a?(String)}.any?(&:xref?)
  end
end
