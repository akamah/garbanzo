# coding: utf-8

require 'test/unit'
require './repr.rb'
require './evaluator.rb'
require './proto2.rb'

class TC_Grammar2 < Test::Unit::TestCase
  include Garbanzo

  def setup
    # 初期文法を読み込む．
    @int = Proto2.new(false)
    @int.start(["predef.tmp.garb"])
  end

  def get_rule(rule_name)
    path = rule_name.split('.')
    dot  = @int.evaluator.dot
    
    path.reduce(dot) { |obj, key| obj[key] }
  end
  
  def install_source(input)
    dst = @int.evaluator
    src = Repr::Store.create_source(input)

    %w(source index token_called line_numbers).each do |attr|
      dst.dot['source'][attr] = src[attr]
    end
  end
  
  ## rule_name は，'parser.sentence'のようにドット区切り
  ## inputはある文字列．
  ## resultは何かしら．
  def rule(rule_name, input, expected)
    rule = get_rule(rule_name)
    install_source(input)
      
    result = @int.evaluator.evaluate(rule)

    msg = build_message('Parse Error:', "? doesn't matches ?", rule_name, input)
    assert_equal(expected, result, msg)
  end
  
  def test_integer
    rule 'parser.integer', '0', 0.to_repr
    rule 'parser.expression', '1', 1.to_repr
    rule 'parser.integer', '142857', 142857.to_repr
  end

  def test_bool
    rule 'parser.expression', 'true', true.to_repr
    rule 'parser.expression', 'false', false.to_repr
  end
  
  def test_string
    rule 'parser.string', '"hogehoge"', "hogehoge".to_repr
    rule 'parser.string', '""', "".to_repr
    rule 'parser.string', '"string with \newline"', "string with \newline".to_repr
  end

  def test_symbol
    rule 'parser.symbol', 'homuhomu', 'homuhomu'.to_repr
  end

  def test_variable
    rule 'parser.expression', 'a/b/c', Repr::get(Repr::get(Repr::get(Repr::getenv, 'a'.to_repr),
                                                          'b'.to_repr),
                                                'c'.to_repr)
                                                          
  end

  def test_block
    result = Repr::begin(
      { 0 => Repr::print("hoge".to_repr),
        1 => Repr::print("poyo".to_repr)
      }.to_repr)
    
    rule 'parser.block', <<END, result
begin
  {"@": "print", "value": "hoge"}
  {"@": "print", "value": "poyo"}
end
END
  end

  def test_while
    result = Repr::while(true.to_repr, Repr::begin({}.to_repr))

    rule 'parser.sentence', <<END, result
while true
end
END
  end

  def test_if
    result = Repr::if(true.to_repr, Repr::begin({}.to_repr), Repr::begin({}.to_repr))

    rule 'parser.sentence', <<END, result
if true
else
end
END
  end

  def test_eval
    result = Repr::eval(Repr::getenv, 3.to_repr)

    rule 'parser.expression', "%3", result
  end

  def test_call
    r1 = Repr::call(
      Repr::get(Repr::getenv, "func".to_repr),
      { 0 => Repr::get(Repr::getenv, "foo".to_repr),
        1 => Repr::get(Repr::getenv, "bar".to_repr) }.to_repr)
                                                               
    rule 'parser.expression', "func(foo, bar)", r1

    r2 = Repr::call(
      Repr::get(Repr::getenv, "func".to_repr), {}.to_repr)

    rule 'parser.expression', "func()", r2
  end
  
  def test_function
    result = ""
    rule 'parser.expression', <<END, result
fun(a)
  while a
  end
end
END
  end
  
  def test_fail
    assert_raise {
      rule 'parser.integer', 'hoge', 3.to_repr
    }

    assert_raise {
      rule 'negi.poyoshi', 'nyann', "hoge".to_repr
    }
  end
end
