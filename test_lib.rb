require 'test/unit'
require './repr.rb'
require './lib.rb'


class TC_Lib < Test::Unit::TestCase
  include Garbanzo
  include Garbanzo::Repr

=begin  
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
=end
end
