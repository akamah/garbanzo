require 'test/unit'
require './proto1.rb'

class TC_Proto1 < Test::Unit::TestCase
  include Garbanzo
  
  def test_sequence
    s1 = Sequence.new(String.new("mado"),
                      String.new("homu"),
                      String.new("saya"))
    assert_equal(["saya", "kyou"], s1.parse("madohomusayakyou"))
    assert_raise(ParseError) {
      s1.parse("madohomumami")
    }
  end

  def test_choice
    s2 = Choice.new(String.new("mado"),
                      String.new("homu"),
                      String.new("saya"))
    assert_equal(["mado", "ka"], s2.parse("madoka"))
    assert_equal(["homu", "ra"], s2.parse("homura"))
    assert_equal(["saya", "ka"], s2.parse("sayaka"))
    assert_raise(ParseError) {
      s2.parse("mami")
    }
  end
end
