require 'test/unit'
require './proto1.rb'

class TC_Proto1 < Test::Unit::TestCase
  include Garbanzo
  
  def test_sequence
    s1 = Sequence.new(String.new("mado"),
                      String.new("homu"),
                      String.new("saya"))
    assert_equal("kyou", s1.parse("madohomusayakyou")[1])
    assert_raise(ParseError) {
      s1.parse("madohomumami")
    }

    s2 = Sequence.new(String.new("mado"), String.new("homu")) { |*args|
      args.length
    }

    assert_equal([2, ""], s2.parse("madohomu"))
  end

  def test_choice
    s2 = Choice.new(String.new("mado"),
                      String.new("homu"),
                      String.new("saya"))
    assert_equal("ka", s2.parse("madoka")[1])
    assert_equal("ra", s2.parse("homura")[1])
    assert_equal("ka", s2.parse("sayaka")[1])
    assert_raise(ParseError) {
      s2.parse("mami")
    }
  end
end
