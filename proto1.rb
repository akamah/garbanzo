# coding: utf-8
=begin rdoc
言語処理系の開発：拡張可能な構文を持つ言語のプロトタイプその1
1. ちょっとしたASTを評価するものと
2. パーサコンビネータっぽい構文解析装置と
3. デフォルトでは構文の拡張しかできない構文を持つ
=end


module Garbanzo
  # 言語の内部表現としての整数
  class Num
    attr_reader :num

    def initialize(num)
      @num = num
    end
  end

  # 言語の内部表現としての足し算  
  class Add
    attr_reader :left
    attr_reader :right

    def initialize(left, right)
      @left  = left
      @right = right
    end
  end

  # 言語の内部表現としての掛け算
  class Mult
    attr_reader :left
    attr_reader :right

    def initialize(left, right)
      @left  = left
      @right = right
    end
  end

  # print式を意味する内部表現
  class Print
    attr_reader :value

    def initialize(value)
      @value = value
    end
  end

  # いわゆるNOP
  class Unit; end

  # 評価するやつ。変数とか文脈とか何も考えていないので単純
  class Evaluator
    def evaluate(program)
      case program
      when Num, Unit
        program
      when Add
        Num.new(evaluate(program.left).num + evaluate(program.right).num)
      when Mult
        Num.new(evaluate(program.left).num * evaluate(program.right).num)
      when Print
        result = evaluate(program.value)
        p result
        result
      else
        raise "argument is not a program"
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
    def sequence(&func)
      Sequence.new(*self.map(&:to_rule), &func)
    end

    def choice(&func)
      Choice.new(*self.map(&:to_rule), &func)
    end

    def to_rule
      raise "Array#to_rule is ambiguous operation"
    end
  end

  class ::String
    def to_rule
      Garbanzo::String.new(self)
    end
  end

  class ::Symbol
    def to_rule
      Garbanzo::Call.new(self)
    end
  end
  
  class ::Proc
    def to_rule
      Garbanzo::Function.new(&self)
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
      when Sequence
        es, rest = rule.children.reduce([[], source]) do |accum, c|
          e1, r1 = parse_rule(c, accum[1])
          [accum[0] << e1, r1]
        end

        es = rule.func.call(*es) if rule.func != nil
        return es, rest
      when Choice
        for c in rule.children[0..-2]
          begin
            return parse_rule(c, source)
          rescue ParseError
          end
        end

        parse_rule(rule.children[-1], source)
      when String
        if source.start_with?(rule.string)
          return Unit.new, source[rule.string.length .. -1]                       
        else
          raise ParseError, "expected #{rule.string}"
        end
      when Function
        rule.function.call(source)
      when Call
        if r = grammar[rule.rule_name]
          parse_rule(r, source)
        else
          raise "rule: #{rule.rule_name} not found"
        end
      end
    end

    # 構文拡張のやつです。
    def install_grammar_extension
      grammar.rules[:sentence] = Choice.new(
        Sequence.new(String.new("%{"),
                     Function.new { |source|
                       idx = source.index('%}')
                       if idx
                         to_eval = source[0..idx-1]
                         self.instance_eval(to_eval, "(grammar_extension)")
                         [Unit.new, source[idx..-1]]
                       else
                         raise ParseError, "closing `%}' not found"
                       end
                     },
                     String.new("%}")) {
          Unit.new
        })
    end
  end
  
  # EvaluatorとParserをカプセルしたもの。
  class Interpreter
    def initialize
      @evaluator = Evaluator.new
      @parser    = Parser.new
    end

    def execute(src)
      while src != ""
        prog, src = @parser.parse(src)
        p prog
        p src
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
