require 'test/unit'
require './proto1.rb'

class TC_Proto1 < Test::Unit::TestCase
  include Garbanzo

  def build_parser(rule)
    Parser.new(Rule::Grammar.new({ start: rule }, start = :start))
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

  def test_equal
    ev = Evaluator.new

    assert_equal(true, Repr::Num.new(3) == Repr::Num.new(3))
    assert_equal(Repr::Num.new(3), Repr::Num.new(3))
    assert_equal(Repr::Num.new(4), ev.evaluate(Repr::Add.new(Repr::Num.new(1),
                                                             Repr::Num.new(3))))
    assert_not_equal(Repr::Bool.new(true), Repr::Bool.new(false))

    assert_equal(Repr::Bool.new(true),
                 ev.evaluate(Repr::Equal.new(
                              Repr::String.new("homu"),
                              Repr::String.new("homu"))))

    ds = Repr::Store.new({})
    key = Repr::String.new("saya")
    val = Repr::Num.new("38")

    ev.evaluate(Repr::Set.new(ds, key, val))
    assert_equal(val, ev.evaluate(Repr::Get.new(ds, key)))
  end

  def test_optional
    s1 = build_parser(Rule::Optional.new(Rule::String.new("homu")))
    assert_equal([nil, "mado"], s1.parse("mado"))
  end

  include Repr
  
  def test_while_repr
    ev = Evaluator.new
    
    sum  = String.new("sum")
    a    = String.new("a")
    env  = Store.new({ sum => Num.new(0), a => Num.new(0) })

    # cond: (10 == a) == false
    cond = Equal.new(Equal.new(Num.new(10), Get.new(env, a)), Bool.new(false))
    body = Equal.new(Set.new(env, sum,
                             Add.new(Get.new(env, sum), Get.new(env, a))),
                     Set.new(env, a,
                             Add.new(Num.new(1), Get.new(env, a))))
    expr = While.new(cond, body)
    ev.evaluate(expr)
    
    assert_equal(Num.new(45), ev.evaluate(Get.new(env, sum)))
  end

  def test_list_miscs
    hoge = Lib::make_list(String.new("mado"),
                          String.new("homu"),
                          String.new("saya"))
    expected = Store.new({ String.new("head") => String.new("mado"),
                           String.new("rest") => Store.new({ String.new("head") => String.new("homu"),
                                                             String.new("rest") => Store.new({ String.new("head") => String.new("saya"),
                                                                                               String.new("rest") => Store.new({})})})})
    assert_equal(expected, hoge)
    assert_equal(String.new("mado"), Lib::head(hoge))

    elms = []
    Lib::each_list(hoge) { |x|
      elms << x
    }

    assert_equal([String.new("mado"),
                  String.new("homu"),
                  String.new("saya")],
                 elms)
  end

  def test_begin
    ev = Evaluator.new

    command = Begin.new(Lib::make_list(Set.new(Unit.new, String.new("a"), Num.new(3)),
                                       Set.new(Unit.new, String.new("a"), Add.new(Num.new(2),
                                                                                  Get.new(Unit.new, String.new("a"))))))

    ev.evaluate(command)
    assert_equal(Num.new(5), ev.evaluate(Get.new(Unit.new, String.new("a"))), ev.show(command))
  end
end

