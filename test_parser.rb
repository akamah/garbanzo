require 'test/unit'
require './rule.rb'
require './parser.rb'

class TC_Parser < Test::Unit::TestCase
  include Garbanzo
  
  def build_parser(rule)
    Parser.new(Rule::Grammar.new({ start: rule }, :start))
  end
  
  def test_sequence
    s1 = build_parser(Rule::sequence(Rule::string("mado"),
                                     Rule::string("homu"),
                                     Rule::string("saya")))
    assert_equal("kyou", s1.parse("madohomusayakyou")[1])
    assert_raise(Rule::ParseError) {
      s1.parse("madohomumami")
    }

    s2 = build_parser(Rule::sequence(Rule::string("mado"), Rule::string("homu")) { |*args|
                        args.length
                      })

    assert_equal([2, ""], s2.parse("madohomu"))
  end

  def test_choice
    s2 = build_parser(Rule::choice(Rule::string("mado"),
                                   Rule::string("homu"),
                                   Rule::string("saya")))
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

    
    assert_equal(["OK", ""], s1.parse("madohomusaya"))
    assert_equal("saya", s2.parse("mamisaya")[1])
  end

  def test_optional
    s1 = build_parser(Rule::optional("homu".to_rule, nil))
    assert_equal([nil, "mado"], s1.parse("mado"))
  end

  def test_one_of
    s1 = build_parser(Rule::many_one(Rule::one_of("1234567890")))
    assert_equal([%w(1 4 2 8 5 7).map{|x| x.to_repr}, "hoge"], s1.parse("142857hoge"))
    assert_raise(Rule::ParseError) {
      s1.parse("hoge")
    }
  end

  def test_split_by_spaces
    s1 = build_parser(Rule::split_by_spaces("mado".to_rule, "homu".to_rule))
    assert_equal([%w(mado homu).map(&:to_repr), "saya"], s1.parse("mado homusaya"))
  end

  def test_and
    s1 = build_parser(Rule::and("homu".to_rule) >> "homu".to_rule)
    assert_equal(["homu".to_repr, "saya"], s1.parse("homusaya"))
  end

  def test_any
    s = build_parser(Rule::any >> Rule::any)
    assert_equal(["a".to_repr, "do"], s.parse("mado"))
  end
  
  def test_not
    r = "/*".to_rule >> Rule::many(Rule::not("*/".to_rule) >> Rule::any) >> "*/".to_rule
    s1 = build_parser(r)

    assert_equal(["*/".to_repr, "hogetara"], s1.parse("/* this is comment line */hogetara"))
  end
end

