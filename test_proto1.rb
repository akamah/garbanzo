require 'test/unit'
require './proto1.rb'
require './test_parser.rb'


class TC_Proto1 < Test::Unit::TestCase
  include Garbanzo
  include Repr

  def test_wrapper
    assert_equal(Num.new(1), 1.to_repr)
    assert_equal(String.new("hoge"), "hoge".to_repr)
    assert_equal(Store.new({ "num".to_repr => Num.new(1),
                             "str".to_repr => String.new("hoge"),
                             "true".to_repr => Bool.new(true) }),
                 Store.new({ "num".to_repr => 1.to_repr,
                             "str".to_repr => "hoge".to_repr,
                             "true".to_repr => true.to_repr }))
  end
  
  def test_equal
    ev = Evaluator.new

    assert_equal(true, Num.new(3) == Num.new(3))
    assert_equal(Num.new(3), Num.new(3))
    assert_equal(Num.new(4), ev.evaluate(Add.new(Num.new(1),
                                                 Num.new(3))))
    assert_not_equal(Bool.new(true), Bool.new(false))

    assert_equal(Bool.new(true),
                 ev.evaluate(Equal.new(
                              String.new("homu"),
                              String.new("homu"))))

    ds = Store.new({})
    key = String.new("saya")
    val = Num.new("38")

    ev.evaluate(Set.new(ds, key, val))
    assert_equal(val, ev.evaluate(Get.new(ds, key)))
  end

  
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

    command = Begin.new(Lib::make_list(Set.new(Dot.new, String.new("a"), Num.new(3)),
                                       Set.new(Dot.new, String.new("a"), Add.new(Num.new(2),
                                                                                  Get.new(Dot.new, String.new("a"))))))

    ev.evaluate(command)
    assert_equal(Num.new(5), ev.evaluate(Get.new(Dot.new, String.new("a"))), ev.show(command))
  end

  def test_function
    ev = Evaluator.new

    func = Function.new(Store.new({}), Add.new(Get.new(Dot.new, String.new("a")), Num.new(10)))
    call = Call.new(func, Store.new({String.new('a') => Num.new(32)}))

    assert_equal(Num.new(42), ev.evaluate(call))
  end
end

