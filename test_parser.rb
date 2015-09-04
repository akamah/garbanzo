require 'test/unit'
require './rule.rb'
require './parser.rb'

class TC_Parser < Test::Unit::TestCase
  include Garbanzo
  
  def build_parser(rule)
    Parser.new(Rule::Grammar.new({ start: rule }, :start))
  end
  
  def test_sequence
    s1 = build_parser(Rule::Sequence.new(Rule::String.new("mado"),
                                         Rule::String.new("homu"),
                                         Rule::String.new("saya")))
    assert_equal("kyou", s1.parse("madohomusayakyou")[1])
    assert_raise(Rule::ParseError) {
      s1.parse("madohomumami")
    }

    s2 = build_parser(Rule::Sequence.new(Rule::String.new("mado"), Rule::String.new("homu")) { |*args|
                        args.length
                      })

    assert_equal([2, ""], s2.parse("madohomu"))
  end

  def test_choice
    s2 = build_parser(Rule::Choice.new(Rule::String.new("mado"),
                                       Rule::String.new("homu"),
                                       Rule::String.new("saya")))
    assert_equal("ka", s2.parse("madoka")[1])
    assert_equal("ra", s2.parse("homura")[1])
    assert_equal("ka", s2.parse("sayaka")[1])
    assert_raise(Rule::ParseError) {
      s2.parse("mami")
    }
  end

  def test_open_class
    s1 = build_parser(["mado", "homu", "saya"].sequence { |m, h, s|
                        "OK"
                      })
    s2 = build_parser(["mado", "mami"].choice)

    s3 = build_parser(lambda { |source| return true, source }.to_rule)
    
    assert_equal(["OK", ""], s1.parse("madohomusaya"))
    assert_equal("saya", s2.parse("mamisaya")[1])
    assert_equal([true, "hoge"], s3.parse("hoge"))
  end

  def test_optional
    s1 = build_parser(Rule::Optional.new(Rule::String.new("homu")))
    assert_equal([nil, "mado"], s1.parse("mado"))
  end
end
