require 'test/unit'
require './repr.rb'
require './evaluator.rb'


class TC_Repr < Test::Unit::TestCase
  include Garbanzo
  include Garbanzo::Repr
  
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
    assert_equal(Num.new(4), ev.evaluate(Repr::add(Num.new(1),
                                                   Num.new(3))))
    assert_not_equal(Bool.new(true), Bool.new(false))

    assert_equal(Bool.new(true),
                 ev.evaluate(Repr::equal(String.new("homu"),
                                         String.new("homu"))))

    ds = Store.new({})
    key = String.new("saya")
    val = Num.new("38")

    ev.evaluate(Repr::set(ds, key, val))
    assert_equal(val, ev.evaluate(Repr::get(ds, key)))

    assert_equal(true.to_repr, ev.evaluate(Repr::lessthan(3.to_repr, 10.to_repr)))
  end

  
  def test_while_repr
    ev = Evaluator.new
    
    sum  = String.new("sum")
    a    = String.new("a")
    env  = Store.new({ sum => Num.new(0), a => Num.new(0) })

    # cond: (10 == a) == false
    cond = Repr::equal(Repr::equal(Num.new(10), Repr::get(env, a)), Bool.new(false))
    body = Repr::equal(Repr::set(env, sum,
                                 Repr::add(Repr::get(env, sum), Repr::get(env, a))),
                       Repr::set(env, a,
                                 Repr::add(Num.new(1), Repr::get(env, a))))
    expr = Repr::while(cond, body)
    ev.evaluate(expr)
    
    assert_equal(Num.new(45), ev.evaluate(Repr::get(env, sum)))
  end

  def test_begin
    ev = Evaluator.new

    command = Repr::begin(Lib::make_list(Repr::set(Repr::getenv, String.new("a"), Num.new(3)),
                                         Repr::set(Repr::getenv, String.new("a"), Repr::add(Num.new(2),
                                                                                            Repr::get(Repr::getenv, String.new("a"))))))

    ev.evaluate(command)
    assert_equal(Num.new(5), ev.evaluate(Repr::get(Repr::getenv, String.new("a"))), ev.show(command))
  end

  def test_function
    ev = Evaluator.new

    func = Repr::function(Store.new({}), Repr::add(Repr::get(Repr::getenv, String.new("a")), Num.new(10)))
    c = Repr::call(func, Store.new({String.new('a') => Num.new(32)}))

    assert_equal(Num.new(42), ev.evaluate(c))
  end

  def test_store
    store = Repr::store({})
    store["hoge"] = "hige".to_repr

    assert_equal("hige".to_repr, store["hoge".to_repr])
  end

  def test_quote
    ev = Evaluator.new
    store = Repr::quote(Repr.add(3.to_repr, 4.to_repr))
    assert_equal(Repr.add(3.to_repr, 4.to_repr),
                 ev.evaluate(store))
  end

  def test_string_manip
    ev = Evaluator.new

    ap = Repr::append("mado".to_repr, "homu".to_repr)
    at = Repr::charat("homu".to_repr, 2.to_repr)
    le = Repr::length("homuhomu".to_repr)

    assert_equal("madohomu".to_repr, ev.evaluate(ap))
    assert_equal("m".to_repr, ev.evaluate(at))
    assert_equal(8.to_repr, ev.evaluate(le))
  end

  def test_proc
    ev = Evaluator.new

    pr = Repr::procedure(lambda {|a|
                           (a['right'].num + a['left'].num).to_repr
                         })
    args = Repr::store({})
    args['right'] = 1.to_repr
    args['left']  = 3.to_repr
    assert_equal(4.to_repr, ev.evaluate(Repr::call(pr, args)))
    assert_equal(pr, ev.evaluate(pr))
  end

  def test_type_check
    ev = Evaluator.new

    pr = Repr::add(3.to_repr, "hoge".to_repr)

    assert_raise {
      ev.evaluate(pr)
    }
    
  end
end
