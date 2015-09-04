# coding: utf-8

# 内部表現
module Garbanzo
    # 内部表現
  module Repr
    # 内部表現のオブジェクトを適当に定義してくれるメソッド。
    def self.define_repr_class(mod, classname, *attrs, **opts)
      attr_list  = attrs.map {|x| ":" + x.to_s }.join(', ')
      attr_def   = attrs.length > 0 ? "attr_accessor " + attr_list : ""
      arguments  = attrs.join(', ')
      assignment = attrs.map {|x| "@#{x} = #{x}" }.join('; ')

      hash_def   = attrs.map   {|x| "#{x}.hash" }.join(' ^ ')
      eql_def    = (["class"] + attrs).map {|x| "self.#{x}.eql?(other.#{x})" }.join(' && ')

#       to_repr    = ""
#       if opts.include?(:wrapper)
#         raise "attribute should be precisely 1 with wrapper class" if attrs.size != 1
#         wraps = opts[:wrapper] 
#         to_repr = <<"WRAPPER"
# class ::#{wraps}
#   def to_repr
#     return Garbanzo::Repr::#{classname}.new(self)
#   end
# end
# WRAPPER
#       end
      
      str = <<"EOS"
class #{classname}
  #{attr_def}
  def initialize(#{arguments})
    #{assignment}
  end

  def hash
    #{hash_def}
  end

  def eql?(other)
    #{eql_def}
  end

  def ==(other)
    eql?(other)
  end

  def to_repr
    self
  end
end
EOS
      if $DEBUG
        puts str
        p opts
      end
      
      mod.module_eval(str, classname)
    end
    
    define_repr_class(self, "Num", "num") # 言語の内部表現としての整数
    define_repr_class(self, "String", "value")  # 内部表現としての文字列
    define_repr_class(self, "Bool", "value")  # 内部表現としての文字列

    define_repr_class(self, "Add", "left", "right") # 言語の内部表現としての足し算
    define_repr_class(self, "Mult", "left", "right") # 言語の内部表現としての掛け算
    define_repr_class(self, "Equal", "left", "right") # 同じかどうかを判定
    define_repr_class(self, "NotEqual", "left", "right") # 違うかどうかを判定

    define_repr_class(self, "Print", "value") # print式を意味する内部表現
    define_repr_class(self, "Unit")  # いわゆるNOP
    define_repr_class(self, "Store", "table")  # データストアオブジェクト

    define_repr_class(self, "Set", "object", "key", "value")  # データストアへの代入を表す
    define_repr_class(self, "Get", "object", "key")  # データストアからの読み出しを表す
    define_repr_class(self, "While", "condition", "body") # ループ命令
    define_repr_class(self, "Begin", "body") # 逐次実行命令

    class ::Integer
      def to_repr; Garbanzo::Repr::Num.new(self); end
    end

    class ::String
      def to_repr; Garbanzo::Repr::String.new(self); end
    end

    class ::Hash
      def to_repr
        Garbanzo::Repr::Store.new(self.map {|k, v| [k, v.to_repr] }.to_h)
      end
    end

    class ::TrueClass
      def to_repr; Garbanzo::Repr::Bool.new(true); end
    end

    class ::FalseClass
      def to_repr; Garbanzo::Repr::Bool.new(false); end
    end
  end
end
