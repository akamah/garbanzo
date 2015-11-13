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

    int.evaluator.dot['/']['parser']['sentence'] =
      int.evaluator.evaluate(
      Repr::call(int.evaluator.dot['/']['oneof'],
                 { "string" => "ABCDE" }.to_repr))
    
    assert_equal("B".to_repr, int.execute("B"))
  end

  def test_string
    int = Interpreter2.new(false)

    int.evaluator.dot['/']['parser']['sentence']['children']['white'] =
      int.evaluator.dot['/']['parser']['whitespaces']
    assert_equal("   ".to_repr, int.execute("   "))
  end

  def test_pair
    int = Interpreter2.new(false)

    int.evaluator.dot['/']['parser']['sentence'] =
      int.evaluator.dot['/']['parser']['pair']

    assert_equal({ 'hoge' => 'hige' }.to_repr,
                 int.execute('"hoge":"hige"'))
  end

  def test_datastore
    int = Interpreter2.new(false)

    assert_equal({}.to_repr,
                 int.execute('{ }'))
    
    assert_equal({ 'hoge' => 'hige' }.to_repr,
                 int.execute('{"hoge" : "hige"}'))

    assert_equal({ 'hoge' => 'hige',
                    'homu' => 'mado' }.to_repr,
                 int.execute('{"hoge" : "hige", "homu" : "mado", }'))

    assert_equal({ 'hoge' => {'homu' => 'mado'}.to_repr }.to_repr,
                 int.execute('{"hoge":{"homu": "mado",},}'))

    assert_raise(Rule::ParseError) {
      int.execute('{"hoge":"hige",,}')
    }
  end
end

