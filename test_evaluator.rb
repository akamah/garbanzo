require 'test/unit'
require './evaluator.rb'

class TC_Evaluator < Test::Unit::TestCase
  include Garbanzo

  def test_analyze
    num = Repr::num(3)
    str = Repr::string("hoge")

    add = Repr::add(num, Repr::num(5))
    
    assert_equal(num, num.analyzed.call())
    assert_equal(str, str.analyzed.call())
    assert_equal(8.to_repr, add.analyzed.call(nil))

    assert_raise {
      num.analyze
    }
  end
end
