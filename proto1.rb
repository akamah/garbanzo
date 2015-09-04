# coding: utf-8
=begin rdoc
言語処理系の開発：拡張可能な構文を持つ言語のプロトタイプその1
1. ちょっとしたASTを評価するものと
2. パーサコンビネータっぽい構文解析装置と
3. デフォルトでは構文の拡張しかできない構文を持つ
=end


module Garbanzo
  # 内部表現
  module Repr
    # 内部表現のオブジェクトを適当に定義してくれるメソッド。
    def self.define_repr_class(mod, classname, *attrs, **opts)
      attr_list = attrs.map {|x| ":" + x.to_s }.join(', ')
      attr_def = attrs.length > 0 ? "attr_accessor " + attr_list : ""
      arguments = attrs.join(', ')
      assignment = attrs.map {|x| "@#{x} = #{x}" }.join('; ')

      hash_def = attrs.map   {|x| "#{x}.hash" }.join(' ^ ')
      eql_def  = (["class"] + attrs).map   {|x| "self.#{x}.eql?(other.#{x})" }.join(' && ')

      str = <<"EOS"
class #{classname} < #{opts[:extend] || "Object"}
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
    
    
    # 評価するやつ。変数とか文脈とか何も考えていないので単純
    class Evaluator
      def initialize
        @dot = Store.new({})
      end

      HEAD = String.new("head")
      REST = String.new("rest")

      def null
        Store.new({})
      end
        
      def list_node?(obj)
        obj.class == Store && obj.table.include?(HEAD) && obj.table.include?(REST)
      end

      def head(obj)
        list_node?(obj) ? obj.table[HEAD] : Unit.new
      end

      def rest(obj)
        list_node?(obj) ? obj.table[REST] : Unit.new
      end
      
      def each_linear_list(lst)
        while list_node?(lst)
          yield head(lst)
          lst = rest(lst)
        end
      end

      def make_list(*objs)
        l = null
        objs.reduce(l) { |lst, obj|
          lst.table[HEAD] = obj
          lst.table[REST] = null
          lst.table[REST]
        }
        l
      end
      
      def evaluate(program)
        case program
        when Num, Store, Bool, String
          program
        when Add
          Num.new(evaluate(program.left).num + evaluate(program.right).num)
        when Mult
          Num.new(evaluate(program.left).num * evaluate(program.right).num)
        when Equal
          Bool.new(evaluate(program.left).eql?(evaluate(program.right)))
        when NotEqual
          Bool.new(!evaluate(program.left).eql?(evaluate(program.right)))
        when Print
          result = evaluate(program.value)
          puts show(result)
          result
        when Set
          obj = evaluate(program.object)
          key = evaluate(program.key)
          val = evaluate(program.value)

          raise "SET: object is not a store #{obj}" unless obj.is_a? Store
          obj.table[key] = val
        when Get
          obj = evaluate(program.object)
          key = evaluate(program.key)
          
          raise "GET: object is not a store #{obj}" unless obj.is_a? Store
          obj.table[key]
        when While
          cond, body = [program.condition, program.body]
          falseObj   = Bool.new(false)
          result = Unit.new
          
          while evaluate(cond) != falseObj
            result = evaluate(body)
          end
          
          result
        when Begin
          each_linear_list(program.body) { |child|
            evaluate(child)
          }
        when Unit
          @dot
        else
          raise "EVALUATE: argument is not a program: #{program}"
        end
      end

      def show(p)
        case p
        when Num
          p.num.to_s
        when Bool
          p.value.to_s
        when String
          p.value.inspect
        when Store
          p.table.to_s
        when Add
          "(#{show(p.left)} + #{show(p.right)})"
        when Mult
          "(#{show(p.left)} * #{show(p.right)})"
        when Equal
          "(#{show(p.left)} == #{show(p.right)})"
        when NotEqual
          "(#{show(p.left)} != #{show(p.right)})"
        when Print
          "print(#{show(p.value)})"
        when Set
          "#{show(p.object)}.#{show(p.key)} = #{show(p.value)}"
        when Get
          "#{show(p.object)}.#{show(p.key)}"
        when While
          "while #{show(p.condition)} #{show(p.body)}"
        when Begin
          "{\n" + show(p.body).gsub(/^/, '  ') + "}"
        when Unit
          "()"
        else
          raise "SHOW: argument is not a repr: #{p}"
        end
      end
    end
  end


  module Rule
    # 構文。つまり、名前をつけたルールの集合を持つもの。
    class Grammar
      attr_accessor :rules
      attr_accessor :start_rule
      
      def initialize(rules = {}, start = :sentence)
        @rules = rules
        @start_rule = start
      end

      def start
        return rules[start_rule]
      end
    end
    
    # 構文解析に失敗した時は、例外を投げて伝えることにする。
    class ParseError < StandardError; end

    # ルール、パーサコンビネータで言う所のParser
    class Rule
      def to_rule
        return self
      end

      def >>(other)
        Sequence.new(self, other.to_rule)
      end

      def |(other)
        Choice.new(self, other.to_rule)
      end
    end

    # 無条件に成功するパーサ
    class Success
      attr_accessor :value

      def initialize(value)
        @value = value        
      end
    end

    # 無条件に失敗するパーサ
    class Fail
      attr_accessor :message

      def initialize(message = "failure")
        @message = message
      end
    end
    
    # 任意の文字にマッチするパーサ
    class Any
    end
    
    # 連続
    class Sequence < Rule
      attr_accessor :children
      attr_accessor :func

      def initialize(*children, &func)
        @children = children
        @func     = func
      end
    end

    # 選択
    class Choice < Rule
      attr_accessor :children

      def initialize(*children)
        @children = children        
      end
    end
    
    # 終端記号。ある文字列。
    class String < Rule
      attr_accessor :string

      def initialize(string)
        @string = string
      end
    end

    # 他のルールを呼び出す
    class Call < Rule
      attr_accessor :rule_name
      
      def initialize(rule_name)
        @rule_name = rule_name
      end
    end

    # ルールを結合する
    class Bind < Rule
      attr_accessor :rule
      attr_accessor :func

      def initialize(rule, &func)
        @rule = rule
        @func = func        
      end
    end
    
    # 関数で処理する。
    class Function < Rule
      attr_accessor :function

      def initialize(&function)
        @function = function
      end
    end

    # オプショナル
    class Optional < Rule
      attr_accessor :rule
      attr_accessor :default

      def initialize(rule, default = nil)
        @rule = rule
        @default = default
      end
    end

    # オープンクラス。クラスのみんなには、内緒だよ！
    class ::Array
      def sequence(&func); Sequence.new(*self.map(&:to_rule), &func); end
      def choice(&func);   Choice.new(*self.map(&:to_rule), &func); end
      def to_rule; raise "Array#to_rule is ambiguous operation"; end
    end

    class ::String
      def to_rule; Garbanzo::Rule::String.new(self); end
    end

    class ::Symbol
      def to_rule; Garbanzo::Rule::Call.new(self); end
    end
    
    class ::Proc
      def to_rule; Garbanzo::Rule::Function.new(&self); end
    end
  end

  
  # 構文解析を行い、意味を持ったオブジェクトを返す。
  class Parser
    attr_accessor :grammar

    def initialize(grammar = Rule::Grammar.new)
      @grammar = grammar
      install_grammar_extension
    end
    
    # 文字列を読み込み、ひとつの単位で実行する。
    def parse(source)
      self.parse_rule(grammar.start, source)
    end

    def parse_rule(rule, source)
      case rule
      when Rule::Sequence
        es, rest = rule.children.reduce([[], source]) do |accum, c|
          e1, r1 = parse_rule(c, accum[1])
          [accum[0] << e1, r1]
        end

        es = rule.func.call(*es) if rule.func != nil
        return es, rest
      when Rule::Choice
        for c in rule.children[0..-2]
          begin
            return parse_rule(c, source)
          rescue Rule::ParseError
          end
        end

        parse_rule(rule.children[-1], source)
      when Rule::String
        if source.start_with?(rule.string)
          return Repr::String.new(rule.string), source[rule.string.length .. -1]                       
        else
          raise Rule::ParseError, "expected #{rule.string}, source = #{source}"
        end
      when Rule::Function
        rule.function.call(source)
      when Rule::Call
        if r = grammar.rules[rule.rule_name]
          parse_rule(r, source)
        else
          raise "rule: #{rule.rule_name} not found"
        end
      when Rule::Optional
        begin
          parse_rule(rule.rule, source)
        rescue Rule::ParseError
          [rule.default, source]
        end
      when Rule::Bind
        x, rest = parse_rule(rule.rule, source)
        parse_rule(rule.func.call(x), rest)
      else
        raise "PARSE_RULE: error, not a rule #{rule}"
      end      
    end

    # 構文拡張のやつです。
    def install_grammar_extension
      grammar.rules[:sentence] = Rule::Choice.new(
        ["%{",
         Rule::Function.new { |source|
           idx = source.index('%}')
           if idx
             to_eval = source[0..idx-1]
             self.instance_eval(to_eval, "(grammar_extension)")
             [Repr::Unit.new, source[idx..-1]]
           else
             raise Rule::ParseError, "closing `%}' not found"
           end
         },
         "%}"].sequence { Repr::Unit.new })
    end
  end
  
  # EvaluatorとParserをカプセルしたもの。
  class Interpreter
    def initialize
      @evaluator = Repr::Evaluator.new
      @parser    = Parser.new
    end

    def execute(src)
      while src != ""
        prog, src = @parser.parse(src)
        puts "program: #{@evaluator.show(prog)}"
        @evaluator.evaluate(prog)
      end
    end
  end
end


if __FILE__ == $0
  include Garbanzo
  int = Interpreter.new

  File.open("source.garb", "rb") { |f|
    int.execute(f.read)
  }
end
