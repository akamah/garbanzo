# coding: utf-8

require './repr'

module Garbanzo
  # いわゆる、言語の標準ライブラリに値するモジュール。
  module Lib
    HEAD = Repr::String.new("head")
    REST = Repr::String.new("rest")

    def self.null
      Repr::store({})
    end
    
    def self.list_node?(obj)
      obj.class == Repr::Store && obj.exist(HEAD).value && obj.exist(REST).value
    end

    def self.head(obj)
      list_node?(obj) ? obj[HEAD] : Bool.new(false)
    end

    def self.rest(obj)
      list_node?(obj) ? obj[REST] : Bool.new(false)
    end
    
    def self.each_list(lst)
      while list_node?(lst)
        yield head(lst)
        lst = rest(lst)
      end
    end

    def self.cons(hd, rt)
      Repr::store({HEAD => hd, REST => rt})
    end

    def self.make_list(*objs)
      l = null
      objs.each_with_index do |obj, i|
        l[i.to_repr] = obj
      end
#      objs.reduce(l) { |lst, obj|
#        lst[HEAD] = obj
#        lst[REST] = null
#        lst[REST]
#      }
      l
    end

    def self.add
      Repr::procedure(
        lambda {|a|
          (a['right'].num + a['left'].num).to_repr
        })
    end
  end
end
