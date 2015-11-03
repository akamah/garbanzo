require 'test/unit'
require './repr.rb'
require './lib.rb'
require './rule.rb'
require './evaluator.rb'
require './parser.rb'
require './proto2.rb'

class TC_Proto2 < Test::Unit::TestCase
  include Garbanzo
  
  def test_oneof
    int = Interpreter2.new(false)

    int.evaluator.dot['/']['parser']['sentence']['children']['hoge'] =
      int.evaluator.evaluate(
      Repr::call(int.evaluator.dot['/']['oneof'],
                 { "string" => "ABCDE" }.to_repr))
    
    assert_equal("B".to_repr, int.execute("B"))
  end
end

