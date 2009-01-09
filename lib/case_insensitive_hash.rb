class CaseInsensitiveHash < Hash
  def CaseInsensitiveHash.[](*params)
    even = false
    params.map!{|v| (even = !even) ? convert_key(v) : v}
    super(*params)
  end
  def initialize(constructor = {})
    if constructor.is_a?(Hash)
      super()
      update(constructor)
    else
      super(constructor)
    end
  end

  def default(key = nil)
    if key.respond_to?(:downcase) && include?(key = key.downcase)
      self[key]
    else
      super
    end
  end

  alias_method :regular_writer, :[]= unless method_defined?(:regular_writer)
  alias_method :regular_update, :update unless method_defined?(:regular_update)

  def []=(key, value)
    regular_writer(convert_key(key), value)
  end

  def update(other_hash)
    other_hash.each_pair { |key, value| regular_writer(convert_key(key), value) }
    self
  end

  alias_method :merge!, :update

  def key?(key)
    super(convert_key(key))
  end

  alias_method :include?, :key?
  alias_method :has_key?, :key?
  alias_method :member?, :key?

  def fetch(key, *extras)
    super(convert_key(key), *extras)
  end

  def values_at(*indices)
    indices.collect {|key| self[convert_key(key)]}
  end

  def dup
    CaseInsensitiveHash.new(self)
  end

  def merge(hash)
    self.dup.update(hash)
  end

  def delete(key)
    super(convert_key(key))
  end

  # Convert to a Hash with String keys.
  def to_hash
    Hash.new(default).merge(self)
  end

protected
  def self.convert_key(key)
    key.respond_to?(:downcase) ? key.downcase : key
  end
  def convert_key(key)
    CaseInsensitiveHash.convert_key(key)
  end
end