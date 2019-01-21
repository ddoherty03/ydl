require 'active_support/core_ext/string'

# Some useful monkey patching for Ydl
class String
  def singular?
    singularize == self
  end

  def plural?
    !singular?
  end

  def xref?
    clean.match?(%r{\Aydl:/})
  end
end
