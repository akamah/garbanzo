# coding: utf-8

# 内部表現
module Garbanzo
    # 内部表現
  module Repr
    class ::Object
      def is_repr?
        return false
      end
    end

    ## Garbanzoのオブジェクトとしてのトップ
    ## サブクラスでは，属性宣言とinitializeとeql?とcopyを実装．
    class GarbObject
      def to_repr; self; end
      def is_repr?; true; end

      def eql?(other)
        raise "eql? is not defined for #{self.class}"
      end

      def hash
        raise "hash is not defined for #{self.class}. It cannot be a key."
      end
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
#    define_repr_class("Num", Object, "num")               # 言語の内部表現としての整数
#    define_repr_class("String", Object, "value")          # 内部表現としての文字列
#    define_repr_class("Bool", Object, "value")            # 内部表現としての文字列
#    define_repr_class("Store", Object, "table")           # データストアオブジェクト
#    define_repr_class("Callable", Object)                  # 呼び出し可能なオブジェクト、という意味で
#    define_repr_class("Function", Callable, "env", "body")  # 関数
#    define_repr_class("Procedure", Callable, "proc")        # ネイティブの関数

    class Num < GarbObject
      attr_accessor :num
      
      def initialize(num)
        @num = num
      end
      
      def copy
        self
      end

      def inspect
        self.num.inspect
      end

      def eql?(other)
        other.class == Num && self.num.eql?(other.num)
      end

      def ==(other)
        other.class == Num && self.num == other.num
      end
      
      def hash
        num.hash
      end
    end

    def self.num(num)
      Num.new(num)
    end

    class String < GarbObject
      attr_accessor :value

      @@creation = 0
      @@created_in = Hash.new { 0 }
      
      at_exit {
        $stderr.puts "string is created #{@@creation} times"

        locations = @@created_in.keys.sort { |a, b|
          @@created_in[a] <=> @@created_in[b]
        }
        
        locations.each do |k|
          $stderr.puts "#{@@created_in[k]} => #{k}"
        end
      }
      
      def initialize(value)
        @value = value

        @@creation += 1

#        if @@creation % 113 == 0        
#          @@created_in[caller(1..5)] += 1
#        end

#        if @@creation % 113 == 0        

      end
      
      def copy; String.new(::String.new(self.value)); end
      def ==(other); other.class == String && other.value == self.value; end
      def eql?(other); other.class == String && other.value.eql?(self.value); end      
      def inspect; self.value.inspect; end
      def to_s; inspect; end

      def hash; value.hash; end
    end

    def self.string(value)
      String.new(value)
    end
    
    class Bool < GarbObject
      attr_accessor :value

      def initialize(value); @value = value; end      
      def copy; self; end
      def inspect; self.value.inspect; end

      def self.true_object;  @@true_object;  end
      def self.false_object; @@false_object; end

      def hash; self.value.hash; end

      def ==(other)
        other.class == Bool && self.value == other.value
      end
      
      @@true_object = self.new(true)
      @@false_object = self.new(false)
    end

    def self.bool(value)
      value ? Bool.true_object : Bool.false_object
    end

    class Callable < GarbObject
    end
    
    class Function < Callable
      attr_accessor :env, :body

      def initialize(env, body)
        @env = env; @body = body
      end
      
      def copy
        Function.new(self.env.copy, self.body.copy)
      end

      def inspect
        "^ (#{self.body.inspect})"
      end

      def ==(other)
        other.class == Function && other.env == self.env && other.body == self.body
      end
    end

    def self.function(env, body)
      Function.new(env, body)
    end
    
    class Procedure < Callable
      attr_accessor :procedure

      def initialize(procedure)
        @procedure = procedure
      end
      
      def copy
        Procedure.new(self.procedure)
      end

      def inspect
        "#<procedure>"
      end

      def ==(other)
        other.class == Procedure && other.procedure == self.procedure
      end
    end

    def self.procedure(procedure)
      Procedure.new(procedure)
    end
    
    class Store < GarbObject
      attr_accessor :keys, :table
      
      def initialize(obj)
#        @@creation_count += 1
#        ca = caller[3]
#        @@callers[ca] ||= 0
#        @@callers[ca] += 1

        case obj
        when Hash
          @keys  = obj.keys.map {|k| as_key k }
          @table = obj.map {|k, v| [as_key(k), v] }.to_h
        when Array
          @keys  = obj.map {|k| as_key k[0] }
          @table = obj.map {|k| [as_key(k[0]), k[1]] }.to_h
        else
          raise "cannot construct a datastore from: #{obj}"
        end
      end

      def copy
        Store.new(@keys.map {|k| [from_key(k), @table[k].copy] })
      end

      def as_key(r)
        case r
        when ::String
          r
        when Repr::String
          r.value
        when Repr::Num
          r.num
        when Repr::Bool
          r.value
        when ::Symbol
          r.to_s
        when ::Numeric
          r
        when ::Bool
          r
        else
          raise "this is not a key #{key.class}"
        end
      end

      def from_key(inner)
        case inner
        when ::String
          inner.to_repr
        when ::Numeric
          inner.to_repr
        when ::Symbol
          inner.to_s.to_repr
        when true, false
          inner.to_repr
        else
          raise "this is not a key #{inner.class.ancestors}"          
        end
      end
      
      def find_index(key)
        @keys.index(as_key key)
      end
      
      def lookup(key)
        realkey = as_key key
        result = @table[realkey]

        raise "no entry found: #{realkey}:#{realkey.class} in #{@keys.inspect}" if result == nil

        result
      end
      
      def [](key)
        if key.is_a? Store
          if key.size.num == 0
            self
          else
            k = key.first_key
            path = key.copy
            path.remove k

            actualkey = key[k]
            nextds = self[actualkey]

            if path.size.num == 0
              nextds
            else
              nextds[path]
            end
          end
        else
          lookup(key)
        end
      end

      def []=(key, value)
        realkey = as_key key
        
        if @keys.include?(realkey)
          @table[realkey] = value
        else
          @table[realkey] = value
          @keys << realkey
        end

        refresh_analyzed
      end

      def size
        @table.size.to_repr
      end

      def remove(key)
        realkey = as_key key
        result = lookup(key)
        
        @table.delete(realkey)
        @keys.delete(realkey)

        refresh_analyzed
        
        result
      end

      def exist(key)
        @table.include?(as_key key).to_repr
      end

      def exist_path(*args)
        ds = self
        args.each { |k|
          return false unless ds.exist(k)
          ds = ds[k]
        }
        return true
      end

      def get_prev_key(origin)
        index = find_index(origin)
        return from_key @keys[index - 1]
      end

      def get_next_key(origin)
        index = find_index(origin)
        return from_key @keys[index + 1]
      end

      def insert_prev(origin, key, value)
        index = find_index(origin)
        realkey = as_key key
        @table[realkey] = value.to_repr

        refresh_analyzed
        
        @keys.insert(index, realkey)
      end

      def insert_next(origin, key, value)
        index = find_index(origin)
        realkey = as_key key
        @table[realkey] = value.to_repr

        refresh_analyzed
        
        @keys.insert(index + 1, realkey)
      end

      def first_key
        from_key @keys.first
      end

      def last_key
        from_key @keys.last
      end

      def each_key
        @keys.each do |k|
          yield(from_key(k), @table[k])
        end
      end

      # wants realkey a string
      def get_raw(realkey)
        @table[realkey]
      end

      # recには，もうすでにでてきたデータストアを記録し，再帰的に出力しないようにする．
      # indentは，そのデータストアの字下げ．
      def inspect_rec(rec = [], indent = 0)
        return ' ' * indent + "<<rec>>" if rec.include?(self)
        contents = []
        
        self.each_key do |k, v|
          value =
            if v.is_a? Store
              ":\n#{v.inspect_rec([self] + rec, indent + 2)}"
            else
              ": #{v.inspect}"
            end
          
          contents << k.inspect + value
        end

        return ' ' * indent + '{' + contents.join(",\n #{' ' * indent}") + "\n" + ' ' * indent + '}'
      end
      
      def inspect
        inspect_rec()
      end

      def ==(other)
        other.class == Store && self.table == other.table && self.keys == other.keys
      end
    end

    def self.store(store)
      Store.new(store)
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
    define_command("IsDataStore", "value") # データストアオブジェクトかどうか判定。    
    
    ## 制御構文
    define_command("Quote", "value");                # 評価の抑制
    define_command("While", "condition", "body")     # ループ命令
    define_command("If", "condition", "consequence", "alternative") # 条件分岐
    define_command("Lambda", "env", "body")          # 関数を作る
    define_command("Begin", "body")                  # 逐次実行命令
    define_command("Scope", "body")                  # スコープを導入しての逐次実行

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

    define_command("parsestring")

    # 与えられた文字列のうち，どれか一文字に一致
    define_command("oneof", "string")

    # 与えられた文字列ではない，どれか一文字に一致
    define_command("noneof", "string")
    
    # 与えられた正規表現に沿ってパースするコマンド．
    # マッチした箇所全体の文字列を返す．
    # 今のところ，正規表現の記法はRubyに依存することとする．
    define_command("regex", "regex")

    # ルールの優先度付きテーブルを元に，パースを行う．
    # 優先順位は，低いほど硬く，高いほど柔らかい．
    # 例： expr + expr は柔らかく，優先的にルールが適用される．
    # ( expr ) は硬く，そこまで優先的には働かない．

    # テーブルに指定するデータストアの形式は，次のようなものとする．
    # { name: {prec: n, parser: p } * }
    define_command("precrule", "table", "prec")

    # あるテーブルでの構文解析を，キャッシュ（メモ）を有効にしつつ実行する
    define_command("withcache", "table")
    
    
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
