# coding: utf-8

# 内部表現
module Garbanzo
    # 内部表現
  module Repr
    # 内部表現のオブジェクトを適当に定義してくれるメソッド。
    def self.define_repr_class(classname, superclass, *attrs)
      attr_list  = attrs.map {|x| ":" + x.inspect }.join(', ')
      attr_def   = attrs.length > 0 ? "attr_accessor " + attr_list : ""
      arguments  = attrs.join(', ')
      assignment = attrs.map {|x| "@#{x} = #{x}" }.join('; ')

      hash_def   = attrs.map   {|x| "#{x}.hash" }.join(' ^ ')
      eql_def    = (["class"] + attrs).map {|x| "self.#{x}.eql?(other.#{x})" }.join(' && ')

      factory_name = classname.downcase

      str = <<"EOS"
class #{classname} < #{superclass}
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
    define_repr_class("Num", Object, "num")               # 言語の内部表現としての整数
    define_repr_class("String", Object, "value")          # 内部表現としての文字列
    define_repr_class("Bool", Object, "value")            # 内部表現としての文字列
    define_repr_class("Store", Object, "table")           # データストアオブジェクト
    define_repr_class("Callable", Object)                  # 呼び出し可能なオブジェクト、という意味で
    define_repr_class("Function", Callable, "env", "body")  # 関数
    define_repr_class("Procedure", Callable, "proc")        # ネイティブの関数

    class Num
      def copy
        Num.new(self.num)
      end

      def inspect
        self.num.inspect
      end
    end

    class String
      def copy
        String.new(::String.new(self.value))
      end

      def inspect
        self.value.inspect
      end
    end

    class Bool
      def copy
        Bool.new(self.value)
      end

      def inspect
        self.value.inspect
      end
    end

    class Function
      def copy
        Function.new(self.env.copy, self.body.copy)
      end

      def inspect
        "#<func>"
      end
    end
    
    class Procedure
      def copy
        Procedure.new(self.proc)
      end

      def inspect
        "#<proc>"
      end
    end
    
    class Store
      def initialize(obj)
        case obj
        when Hash
          @table = obj.to_a
        when Array
          @table = obj
        end
      end

      def copy
        Store.new(@table.to_a.map {|k, v| [k.copy, v.copy] })
      end

      def find_entry(key)
        @table.find { |e| e[0] == key.to_repr }
      end

      def find_entry_index(key)
        @table.find_index { |e| e[0] == key.to_repr }
      end
      
      def [](key)
        entry = find_entry(key)

        if entry != nil
          entry[1]
        else
          raise "Store[], no entry found: #{key.to_repr.value} in #{@table.map {|k| k[0]}}"
        end
      end

      def []=(key, value)
        entry = find_entry(key)
        if entry != nil
          entry[1] = value
        else
          @table << [key.to_repr, value]
        end
      end
      

      def size
        @table.size.to_repr
      end

      def remove(key)
        entry = find_entry(key)
        @table.delete(entry)
        entry[1]
      end

      def exist(key)
        (find_entry(key) != nil).to_repr
      end

      def get_prev_key(origin)
        index = find_entry_index(origin)
        return @table[index - 1][0]
      end

      def get_next_key(origin)
        index = find_entry_index(origin)
        return @table[index + 1][0]
      end

      def insert_prev(origin, key, value)
        index = find_entry_index(origin)
        @table.insert(index, key, value)
      end

      def insert_next(origin, key, value)
        index = find_entry_index(origin)
        @table.insert(index + 1, key, value)
      end

      def first_key
        @table[0][0]
      end

      def last_key
        @table[-1][0]
      end

      def each_key
        @table.each do |kv|
          yield(kv[0], kv[1])
        end
      end

      def inspect
        @table.inspect
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
    define_binary_command("LessThan")                # <

    ## 論理演算
    define_binary_command("And")
    define_binary_command("Or")
    define_command("Not", "value")
    
    define_command("Print", "value")                 # print式を意味する内部表現

    ## データストア関連
    # * get by key
    # * get by index
    # * size
    # insert to index
    # set to key
    # set to index
    # remove by key
    # remove by index
    # ? indexがout of rangeになったらどうしよう？
    # => parse error みたいに？
    # ? set to key, set to indexって、存在してない場合はどうするんだ？
    # ?? set to indexの場合、indexが存在しないならエラーで良さそう
    # ?? set to keyの場合、存在していなかったら追加でいいか？
    # ??? 追加ということにすると、キーが重複したらどうするのか？
    ## しかしだ、順序付けられたマップは欲しい、すごく欲しい。
    ## この際、配列のどこどこを指定して〜とかできなくてもいいから欲しい。
    ## シーケンシャルアクセスくらいしかしないだろうから欲しい。

    ## ユースケース
    ### 末尾に、"hoge"を追加する
    ### 先頭に、"hoge"を追加する。
    ### "poyo" の後に、 "hoge"を追加する。
    ### "hoge"を削除
    ### "hoge"を置き換える。
    ### 純粋に配列として使う場合は、添え字そのものを数値にすると思う。
    ### じゃあ、ランダムアクセスまでできなくても良いのでは？

    ## とりあえず作りたい
    # そのキーがあるか
    # キーより取得
    # あるキーの前/次のキーを取得
    # あるキーの前/後に追加
    # 最初/最後のキーを取得
    # あるキーを削除
    # サイズを取得
    # * イテレータだとかを考えるのは後。
    # * アクセスできない場合は容赦なくエラーを飛ばす。

    
    define_command("Set", "object", "key", "value")  # データストアへの代入を表す
    define_command("Get", "object", "key")           # データストアからの読み出しを表す
    define_command("Size", "object")                 # データストアのサイズを取得

    define_command("Remove", "object", "key")        # キーを削除
    define_command("Exist", "object", "key")         # キーが存在するか
    
    define_command("GetPrevKey", "object", "origin") # あるキーの前のキーを取得
    define_command("GetNextKey", "object", "origin") # あるキーの次のキーを取得
    
    define_command("InsertPrev", "object", "origin", "key", "value") # あるキーの前に挿入
    define_command("InsertNext", "object", "origin", "key", "value") # 後に

    define_command("FirstKey", "object") # 最初のキーを取得
    define_command("LastKey", "object") # 最後のキーを取得

    define_command("DataStore", "object") # データストアオブジェクトを作成。
    
    
    ## 制御構文
    define_command("Quote", "value");                # 評価の抑制
    define_command("While", "condition", "body")     # ループ命令
    define_command("If", "condition", "consequence", "alternative") # 条件分岐
    define_command("Lambda", "env", "body")          # 関数を作る
    define_command("Begin", "body")                  # 逐次実行命令

    ## 環境
    define_command("GetEnv")                         # 現在の環境を取得
    define_command("SetEnv", "env")                  # 拡張

    define_command("Call", "func", "args")           # 呼び出し

    define_command("Eval", "env", "program")         # 禁断のやつ
    
    ## 文字列処理
    define_command("Append", "left", "right")
    define_command("CharAt", "string", "index")
    define_command("Length", "string")

    # 文字列の先頭の文字コードを取得する
    define_command("ToCode", "string")

    # 数値を文字コードに対応する文字列に変換する
    define_command("FromCode", "num")

    
    ## パース関連
    # token: 現在の環境の、sourceという名前の文字列の先頭から1文字切り出し返却する。
    #        sourceが空文字列ならエラーを投げる。
    define_command("token")

    # raise: いわゆる例外を投げる。
    define_command("fail", "message")

    # choice: いくつかの選択肢を順番に試す
    define_command("choice", "children")
    
    # terminal: 終端記号をパース
    define_command("terminal", "string")

    # many: 任意個数のマッチ、要は例外が飛ぶまでそのプログラムを繰り替えす。
    define_command("many", "parser")

    
    class ::Integer
      def to_repr; Garbanzo::Repr::num(self); end
    end

    class ::String
      def to_repr; Garbanzo::Repr::string(self); end
    end

    class ::Hash
      def to_repr
        Garbanzo::Repr::store(self.map {|k, v| [k.to_repr, v.to_repr] })
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
