# coding: utf-8
=begin rdoc
言語処理系の開発：拡張可能な構文を持つ言語のプロトタイプその1
1. ちょっとしたASTを評価するものと
2. パーサコンビネータっぽい構文解析装置と
3. デフォルトでは構文の拡張しかできない構文を持つ
=end


module Garbanzo
  # 内部表現
  def self.define_record_class(mod, classname, *attrs, **opts)
    attr_list = attrs.map {|x| ":" + x.to_s }.join(', ')
    attr_def = attrs.length > 0 ? "attr_accessor " + attr_list : ""
    arguments = attrs.join(', ')
    assignment = attrs.map {|x| "@" + x + " = " + x }.join('; ')

    hash_def = attrs.map {|x| x + ".hash" }.join(' ^ ')
    eql_def  = attrs.map {|x| x + ".eql?(other)" }.join(' && ')
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
end
EOS
    if $DEBUG
      puts str
      p opts
    end
    
    mod.module_eval(str, classname)
  end
  
  module Repr
    Garbanzo.define_record_class(self, "Num", "num") # 言語の内部表現としての整数
    Garbanzo.define_record_class(self, "String", "value")  # 内部表現としての文字列
    Garbanzo.define_record_class(self, "Bool", "value")  # 内部表現としての文字列

    Garbanzo.define_record_class(self, "Add", "left", "right") # 言語の内部表現としての足し算
    Garbanzo.define_record_class(self, "Mult", "left", "right") # 言語の内部表現としての掛け算
    Garbanzo.define_record_class(self, "Equal", "left", "right") # 同じかどうかを判定
    
    Garbanzo.define_record_class(self, "Print", "value") # print式を意味する内部表現
    Garbanzo.define_record_class(self, "Unit")  # いわゆるNOP
    Garbanzo.define_record_class(self, "Store", "table")  # データストアオブジェクト

    Garbanzo.define_record_class(self, "Set", "object", "key", "value")  # データストアへの代入を表す
    Garbanzo.define_record_class(self, "Get", "object", "key")  # データストアからの読み出しを表す

    
    # 評価するやつ。変数とか文脈とか何も考えていないので単純
    class Evaluator
      def evaluate(program)
        case program
        when Num, Unit, Store, Bool
          program
        when Add
          Num.new(evaluate(program.left).num + evaluate(program.right).num)
        when Mult
          Num.new(evaluate(program.left).num * evaluate(program.right).num)
        when Equal
          Bool.new(program.left.eql?(program.right))
        when Print
          result = evaluate(program.value)
          p result
          result
        when Set
          obj, key, value = [program.object, program.key, program.value]

          raise "SET: object is not a store #{obj}" if obj.is_a? Store
          obj.table[key] = value
        when Get
          obj, key = [program.object, program.key]
          obj.table[key]
        else
          raise "EVALUATE: argument is not a program"
        end
      end
    end
  end

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

  module Rule
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

    # 構文解析に失敗した時は、例外を投げて伝えることにする。
    class ParseError < StandardError; end

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

    # 関数で処理する。
    class Function < Rule
      attr_accessor :function

      def initialize(&function)
        @function = function
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

    def initialize(grammar = Grammar.new)
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
          return Repr::Unit.new, source[rule.string.length .. -1]                       
        else
          raise Rule::ParseError, "expected #{rule.string}"
        end
      when Rule::Function
        rule.function.call(source)
      when Rule::Call
        if r = grammar.rules[rule.rule_name]
          parse_rule(r, source)
        else
          raise "rule: #{rule.rule_name} not found"
        end
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
             raise ParseError, "closing `%}' not found"
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
        puts "program: #{prog}"
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
