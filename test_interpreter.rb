require 'test/unit'
require './repr.rb'
require './lib.rb'
require './rule.rb'
require './evaluator.rb'
require './parser.rb'
require './proto1.rb'

class TC_Interpreter < Test::Unit::TestCase
  include Garbanzo
  
  def test_native_proc
    inter = Proto1.new
    
    prog = Repr::call(Repr::get(Repr::getenv, "add".to_repr),
                      Repr::store({ 'right'.to_repr => 3.to_repr,
                                    'left'.to_repr  => 5.to_repr }))
                                     
    assert_equal(8.to_repr, inter.evaluate(prog))
    assert_not_equal(7.to_repr, inter.evaluate(prog))
  end
end
