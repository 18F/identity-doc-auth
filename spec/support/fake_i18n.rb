require 'set'

class FakeI18n
  attr_reader :known_keys

  def initialize(*known_keys)
    @known_keys = known_keys.to_set
  end

  def locale
    :en
  end

  def t(key)
    if known_keys.include?(key)
      key
    else
      raise "unknown i18n key #{key} received"
    end
  end
end
