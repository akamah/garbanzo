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
      list_node?(obj) ? obj.table[HEAD] : Unit.new
    end

    def self.rest(obj)
      list_node?(obj) ? obj.table[REST] : Unit.new
    end
    
    def self.each_list(lst)
      while list_node?(lst)
        yield head(lst)
        lst = rest(lst)
      end
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
  end
end
