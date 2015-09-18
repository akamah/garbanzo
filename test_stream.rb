# coding: utf-8
require 'test/unit'
require './stream.rb'

class TC_Stream < Test::Unit::TestCase
  include Garbanzo

  def test_source
    s1 = Source.new("abcdefg")

    assert_equal("a".to_repr, s1.token)
  end
end
