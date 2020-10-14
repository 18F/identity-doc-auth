require 'set'

class FakeI18n
  attr_reader :translations

  def initialize(*known_keys)
    @translations = {}

    if known_keys.last.kind_of?(Hash)
      @translations = known_keys.pop
    end

    known_keys.each do |key|
      @translations[key] = key
    end
  end

  def locale
    :en
  end

  def t(key)
    translations.fetch(key)
  end
end
