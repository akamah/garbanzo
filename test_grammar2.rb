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
    
    rule = path.reduce(dot) { |obj, key| obj[key] }
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
    rule 'parser.integer', '@0', 0.to_repr
    rule 'parser.integer', '@1', 1.to_repr
    rule 'parser.integer', '@142857', 142857.to_repr
  end

  def test_string
    rule 'parser.string', '"hogehoge"', "hogehoge".to_repr
    rule 'parser.string', '""', "".to_repr
    rule 'parser.string', '"string with \newline"', "string with \newline".to_repr
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
