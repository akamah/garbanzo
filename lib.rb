# coding: utf-8

require './repr'

module Garbanzo
  # いわゆる、言語の標準ライブラリに値するモジュール。
  module Lib
    HEAD = Repr::String.new("head")
    REST = Repr::String.new("rest")

    def self.null
      Repr::Store.new({})
    end
    
    def self.list_node?(obj)
      obj.class == Repr::Store && obj.table.include?(HEAD) && obj.table.include?(REST)
    end

    def self.head(obj)
      list_node?(obj) ? obj.table[HEAD] : Bool.new(false)
    end

    def self.rest(obj)
      list_node?(obj) ? obj.table[REST] : Bool.new(false)
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
      objs.reduce(l) { |lst, obj|
        lst.table[HEAD] = obj
        lst.table[REST] = null
        lst.table[REST]
      }
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
