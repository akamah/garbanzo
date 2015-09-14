# coding: utf-8

# 内部表現
module Garbanzo
    # 内部表現
  module Repr
    # 内部表現のオブジェクトを適当に定義してくれるメソッド。
    def self.define_repr_class(classname, *attrs, **opts)
      attr_list  = attrs.map {|x| ":" + x.to_s }.join(', ')
      attr_def   = attrs.length > 0 ? "attr_accessor " + attr_list : ""
      arguments  = attrs.join(', ')
      assignment = attrs.map {|x| "@#{x} = #{x}" }.join('; ')

      hash_def   = attrs.map   {|x| "#{x}.hash" }.join(' ^ ')
      eql_def    = (["class"] + attrs).map {|x| "self.#{x}.eql?(other.#{x})" }.join(' && ')

      factory_name = classname.downcase
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

def self.#{factory_name}(#{arguments})
  #{classname}.new(#{arguments})
end
EOS
      if $DEBUG
        puts str
        p opts
      end
      
      self.module_eval(str, classname)
    end

    def self.define_command(name, *arguments)
      str = <<"EOS"
def self.#{name.downcase}(#{arguments.join(', ')})
  s = Repr::store({})
  s['@'] = '#{name.downcase}'.to_repr
  #{arguments.map { |arg|
    's[\''+ arg + '\'] = ' + arg
    }.join("\n")}
  s  
end
EOS
      puts str if $DEBUG
      self.module_eval(str, name)
    end

    def self.define_binary_command(name)
      self.define_command(name, "left", "right")
    end
    
    ## 主にデータを表すオブジェクト
    define_repr_class("Num", "num")               # 言語の内部表現としての整数
    define_repr_class("String", "value")          # 内部表現としての文字列
    define_repr_class("Bool", "value")            # 内部表現としての文字列
    define_repr_class("Store", "table")           # データストアオブジェクト
    define_repr_class("Function", "env", "body")  # 関数

    class Store
      def [](key)
        table[key.to_repr]
      end

      def []=(key, value)
        table[key.to_repr] = value
      end
    end
    
    ## 算術演算
    define_binary_command("Add")                     # 言語の内部表現としての足し算
    define_binary_command("Sub")                     # 引き算
    define_binary_command("Mult")                    # 言語の内部表現としての掛け算
    define_binary_command("Div")                     # 割り算
    define_binary_command("Mod")                     # 割ったあまり

    ## 比較
    define_binary_command("Equal")                   # 同じかどうかを判定
    define_binary_command("NotEqual")                # 違うかどうかを判定

    ## 論理演算
    define_binary_command("And")
    define_binary_command("Or")
    define_command("Not", "value")
    
    define_command("Print", "value")                 # print式を意味する内部表現

    ## データストア関連
    define_command("Set", "object", "key", "value")  # データストアへの代入を表す
    define_command("Get", "object", "key")           # データストアからの読み出しを表す
    define_command("Size", "object")                 # 
    
    ## 制御構文
    define_command("While", "condition", "body")     # ループ命令
    define_command("If", "condition", "consequence", "alternative") # 条件分岐
    define_command("Lambda", "env", "body")          # 関数を作る
    define_command("Begin", "body")                  # 逐次実行命令

    ## 環境
    define_command("GetEnv")                         # 現在の環境を取得
    define_command("SetEnv", "env")                  # 拡張

    define_command("Call", "func", "args")           # 呼び出し
    
    
    class ::Integer
      def to_repr; Garbanzo::Repr::num(self); end
    end

    class ::String
      def to_repr; Garbanzo::Repr::string(self); end
    end

    class ::Hash
      def to_repr
        Garbanzo::Repr::store(self.map {|k, v| [k, v.to_repr] }.to_h)
      end
    end

    class ::TrueClass
      def to_repr; Garbanzo::Repr::bool(true); end
    end

    class ::FalseClass
      def to_repr; Garbanzo::Repr::bool(false); end
    end
  end
end
