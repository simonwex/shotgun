require 'test/unit'
require 'case_insensitive_hash'


class CaseInsensitiveHashTest < Test::Unit::TestCase
  
  def test_basics
    hash = CaseInsensitiveHash.new
    hash['Blah'] = 'abcd'
    assert_equal('abcd', hash['Blah'])
    assert_equal('abcd', hash['blah'])
    assert(hash['blah'] == hash['Blah'])
  end
  
  def test_funky_instantiation
    hash = CaseInsensitiveHash[*['a', :a, 'b', :b, 'C', :c]]
    assert_equal(:a, hash['a'])
    assert_equal(:b, hash['B'])
    assert_equal(:c, hash['C'])
    assert_equal(:c, hash['c'])
  end
end