# coding: utf-8

module Garbanzo
  class Num
    attr_reader :num
    def initialize(num)
      @num = num
    end

    def traverse(visitor)
      visitor.visit_num(self)
    end
  end

  class Add
    attr_reader :left
    attr_reader :right

    def initialize(left, right)
      @left  = left
      @right = right
    end

    def traverse(visitor)
      visitor.visit_add(self)
    end
  end

  class Mult
    attr_reader :left
    attr_reader :right

    def initialize(left, right)
      @left  = left
      @right = right
    end

    def traverse(visitor)
      visitor.visit_mult(self)
    end
  end

  # print式を意味する内部表現
  class Print
    attr_reader :value

    def initialize(value)
      @value = value
    end

    def traverse(visitor)
      visitor.visit_print(self)
    end
  end

  class Nop; end


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

  class Rule; end
  
  class ParseError < StandardError; end
  
  # 連続
  class Sequence < Rule
    attr_accessor :children

    def initialize(*children)
      @children = children
    end

    def parse(string)
      children.reduce([nil, string]) do |accum, c|
        rest = accum[1]
        c.parse(rest)
      end
    end
  end

  # 選択
  class Choice < Rule
    attr_accessor :children

    def initialize(*children)
      @children = children        
    end

    def parse(string)
      for c in children[0..-2]
        begin
          return c.parse(string)
        rescue ParseError => e
        end
      end

      children[-1].parse(string)
    end
  end
  
  # 終端記号。ある文字列。
  class String < Rule
    attr_accessor :string

    def initialize(string)
      @string = string
    end

    def parse(source)
      if source.start_with?(string)
        return string, source[string.length .. -1]                       
      else
        raise ParseError, "expected #{string}"
      end
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

    def parse(source)
      function.call(source)
    end
  end

  
  class Evaluator
    def evaluate(program)
      case program
      when Num, Nop
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
        error "argument is not a program"
      end
    end
  end

  class Parser
    attr_accessor :grammar

    def initialize()
      @grammar = Grammar.new
      install_grammar_extension
    end
    
    # 文字列を読み込み、ひとつの単位で実行する。
    def parse(source)
      self.parse_rule(grammar.start, source)
    end

    def parse_rule(rule, source)
      case rule
      when Sequence, Choice, String, Function
        rule.parse(source)
      when Call
        if r = grammar[rule.rule_name]
          parse_rule(r, source)
        else
          raise "rule: #{rule.rule_name} not found"
        end
      end
    end

    def install_grammar_extension
      grammar.rules[:sentence] = Choice.new(
        Sequence.new(String.new("%{"),
                     Function.new { |source|
                       p source
                       idx = source.index('%}')
                       if idx
                         to_eval = source[0..idx-1]
                         self.instance_eval(to_eval, "(grammar_extension)")
                         [Nop.new, source[idx..-1]]
                       else
                         raise ParseError, "closing `%}' not found"
                       end
                     },
                     String.new("%}")))

    end

    class Interpreter
      def initialize
        @evaluator = Evaluator.new
        @parser    = Parser.new
      end

      def execute(src)
        while src != ""
          prog, src = @parser.parse(src)
          @evaluator.evaluate(prog)
        end
      end
    end
  end
end


if __FILE__ == $0
  include Garbanzo
  prog = Print.new(Add.new(Num.new(4), Num.new(2)))
  ev = Evaluator.new
  pa = Parser.new

  pa.parse("%{p 3%}")

  ev.evaluate(prog)
end
