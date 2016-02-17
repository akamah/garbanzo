# coding: utf-8
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

  def test_change_comname
    one = 1.to_repr
    two = 2.to_repr    
    add = Repr::add(one, two)
    
    ev = Evaluator.new

    assert_equal(3.to_repr, ev.evaluate(add)) # まあいいでしょう．
    add['@'] = "sub".to_repr

    assert_equal(-1.to_repr, ev.evaluate(add)) # analyzeのキャッシュが正しく破棄されていないと，この部分がおかしくなるはず
    
  end
end
