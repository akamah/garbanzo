# coding: utf-8
require 'test/unit'
require './stream.rb'
require './rule.rb'


class TC_Stream < Test::Unit::TestCase
  include Garbanzo

  def test_source_token
    s1 = Store.create_source("h\nge")

    t = s1.parse_token

    assert_equal("h".to_repr, t)
    assert_equal(1.to_repr, s1['line'])
    assert_equal(2.to_repr, s1['column'])
    assert_equal(1.to_repr, s1['index'])

    s1.parse_token

    assert_equal(2.to_repr, s1['line'])
    assert_equal(1.to_repr, s1['column'])
  end

  def test_source_terminal
    s1 = Store.create_source("homuhomu")

    t = s1.parse_terminal("homu".to_repr)

    assert_equal("homu".to_repr, t)
    assert_equal(1.to_repr, s1['line'])
    assert_equal(5.to_repr, s1['column'])
    assert_equal(4.to_repr, s1['index'])

    assert_raise(Rule::ParseError) do
      s1.parse_terminal("mado".to_repr)
    end
  end
  
  def test_parse_string
    s1 = Store.create_source('"homuhomu"madomado')

    t = s1.parse_string

    assert_equal("homuhomu".to_repr, t)
    assert_equal(10.to_repr, s1['index'])
    assert_equal(11.to_repr, s1['column'])
  end

  def test_parse_state
    s1 = Store.create_source("homuhomu")
    st = s1.copy_state
   
    begin
      s1.parse_terminal("sayasaya".to_repr)
    rescue
      s1.set_state(st)

      t = s1.parse_terminal("homuhomu".to_repr)

      assert_equal("homuhomu".to_repr, t)
      assert_equal(8.to_repr, s1['index'])
    end
  end
end
