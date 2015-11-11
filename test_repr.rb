require 'test/unit'
require './repr.rb'
require './evaluator.rb'
require './rule.rb'


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

    ev.evaluate(Repr::set(Repr::quote(ds), key, val))
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
    body = Repr::equal(Repr::set(Repr::quote(env), sum,
                                 Repr::add(Repr::get(Repr::quote(env), sum),
                                           Repr::get(Repr::quote(env), a))),
                       Repr::set(Repr::quote(env), a,
                                 Repr::add(Num.new(1), Repr::get(Repr::quote(env), a))))
    expr = Repr::while(cond, body)
    ev.evaluate(expr)
    
    assert_equal(Num.new(45), ev.evaluate(Repr::get(Repr::quote(env), sum)))
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
    ev = Evaluator.new({'/' => 0}.to_repr)
    
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

  def test_remove
    ev = Evaluator.new

    pr = Repr::remove(Repr::quote(Repr::store({3.to_repr => 12.to_repr})), 3.to_repr)

    assert_equal(12.to_repr, ev.evaluate(pr))
  end

  def test_datastore
    st = Repr::store({})
    st['hoge'] = 3.to_repr

    assert_equal(3.to_repr, st['hoge'])
    assert_equal(1.to_repr, st.size)

    st['hoge'] = 5.to_repr
    
    assert_equal(5.to_repr, st['hoge'])

    assert_equal(true.to_repr, st.exist('hoge'))

    st['piyo'] = 8.to_repr
    st['fuga'] = 9.to_repr

    assert_equal('piyo'.to_repr, st.get_prev_key('fuga'))
    assert_equal('piyo'.to_repr, st.get_next_key('hoge'))

    assert_equal('hoge'.to_repr, st.first_key)
    assert_equal('fuga'.to_repr, st.last_key)
  end

  def test_eval
    ev = Evaluator.new

    env  = Repr::store({ "hoge".to_repr => 3.to_repr })
    prog = Repr::store({ "@".to_repr => "eval".to_repr,
                         "env".to_repr => Repr::quote(env),
                         "program".to_repr =>
                                   Repr::quote(
                                     Repr::add(33.to_repr,
                                               Repr::get(Repr::getenv,
                                                         "hoge".to_repr))) })
    assert_equal(36.to_repr, ev.evaluate(prog))
  end

  def test_copy
    st = Repr::store({ "apple".to_repr => 55.to_repr,
                       "banana".to_repr => true.to_repr,
                       "chocolate".to_repr => "kinoko".to_repr })
    st2 = st.copy

    st.remove("apple".to_repr)
    st["banana"] = false.to_repr
    st["chocolate"].value[3] = "a"

    assert_equal(Repr::store({ "banana".to_repr => false.to_repr,
                               "chocolate".to_repr => "kinako".to_repr }),
                 st)
    assert_equal(Repr::store({ "apple".to_repr => 55.to_repr,
                       "banana".to_repr => true.to_repr,
                       "chocolate".to_repr => "kinoko".to_repr }),
                 st2)
  end


  def test_token

    source = Repr::store({ 'source'.to_repr =>
                                    Repr::store({ 'source'.to_repr => "homuhomu".to_repr }) })
    source['/'] = source
    
    prog = Repr::token

    ev = Evaluator.new(source)
    
    assert_equal("h".to_repr, ev.evaluate(prog))
    assert_equal("o".to_repr, ev.evaluate(prog))
    assert_equal("m".to_repr, ev.evaluate(prog))
    assert_equal("u".to_repr, ev.evaluate(prog))
    assert_equal("homu".to_repr, source["source"]["source"])
    assert_equal("h".to_repr, ev.evaluate(prog))
    assert_equal("o".to_repr, ev.evaluate(prog))
    assert_equal("m".to_repr, ev.evaluate(prog))
    assert_equal("u".to_repr, ev.evaluate(prog))

    assert_raise(Rule::ParseError) {
      ev.evaluate(prog)
    }
  end

  def test_fail
    ev = Evaluator.new

    prog = Repr::fail("error".to_repr)

    assert_raise(Rule::ParseError) {
      ev.evaluate(prog)
    }
  end

  def test_choice
    prog = Repr::choice(
      { 'hoge' => Repr::fail('hoge'.to_repr),
        'hige' => Repr::fail('hige'.to_repr),
        'hage' => Repr::token
      }.to_repr)

    st = Repr::store({ 'source'.to_repr =>
                       Repr::store({ 'source'.to_repr => "homu".to_repr }) })
    st['/'] = st

    ev = Evaluator.new(st)
    assert_equal('h'.to_repr, ev.evaluate(prog))
    assert_equal('omu'.to_repr, st['/']['source']['source'])
  end

  def test_terminal
    st = Repr::store({ 'source'.to_repr =>
                                Repr::store({ 'source'.to_repr => "madohomu".to_repr }) })
    st['/'] = st

    ev = Evaluator.new(st)
    
    prog = Repr::begin(
      Repr::store({
                    "mado".to_repr => Repr::terminal('mado'.to_repr),
                    "homu".to_repr => Repr::terminal('homu'.to_repr)
                  }))
    assert_equal('homu'.to_repr, ev.evaluate(prog))
  end

  def test_datastore_cmd
    ev = Evaluator.new

    prog = Repr::datastore(
      Repr::store({ "hoge".to_repr => Repr::add(3.to_repr, 4.to_repr) }))
      
    assert_equal(Repr::store({ "hoge".to_repr => 7.to_repr }), ev.evaluate(prog))
  end

  def test_many
    prog = Repr::many(Repr::quote(Repr::terminal("homu".to_repr)))
    st = Repr::store({ 'source'.to_repr =>
                                Repr::store({ 'source'.to_repr => "homuhomuhomu".to_repr })
                     })
    st['/'] = st
    ev = Evaluator.new(st)
    result = Repr::store({ 0.to_repr => "homu".to_repr,
                           1.to_repr => "homu".to_repr,
                           2.to_repr => "homu".to_repr })

    assert_equal(result, ev.evaluate(prog))

    st['source']['source'] = "hoge".to_repr

    ev = Evaluator.new(st)
    assert_equal(Repr::store({}), ev.evaluate(prog))
  end

  def test_code
    ev = Evaluator.new

    prog1 = Repr::tocode("a".to_repr)
    prog2 = Repr::fromcode(65.to_repr)

    assert_equal(97.to_repr, ev.evaluate(prog1))
    assert_equal("A".to_repr, ev.evaluate(prog2))
  end

  def test_scope
    st = { "a" => "hoge", "/" => "root" }.to_repr
    ev = Evaluator.new(st)

    prog1 = Repr::scope(Repr::set(Repr::getenv, "a".to_repr, 42.to_repr))
    prog2 = Repr::get(Repr::getenv, "a".to_repr)
    ev.evaluate(prog1)

    assert_equal("hoge".to_repr, ev.evaluate(prog2))
  end
end
