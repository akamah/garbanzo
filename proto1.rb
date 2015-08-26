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


  class Rule
    attr_accessor :rules
    attr_accessor :start
    
    def initialize(rules = {}, start = :sentence)
      @rules = rules
    end

    def start
      return rules[start]
    end
  end

  class ParseError < StandardError; end
  
  # 連続
  class Sequence < Rule
    attr_accessor :children

    def initialize(children, &block)
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

    def initialize(children)
      @children = children        
    end

    def parse(string)
      for c in children

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

    def initialize(function)
      @function = function
    end
  end

  # 構文の拡張
  class Extend < Rule
  end
  
  class Evaluator
    def interpret(program)
      case program
      when Num
        program
      when Add
        Num.new(interpret(program.left).num + interpret(program.right).num)
      when Mult
        Num.new(interpret(program.left).num * interpret(program.right).num)
      when Print
        result = interpret(program.value)
        p result
        result
      else
        error "argument is not a program"
      end
    end
  end

  class Parser
    attr_accessor :grammer
    
    # 文字列を読み込み、ひとつの単位で実行する。
    def parse(source)
      self.parse_rule(grammer.start, source)
    end

    def parse_rule(rule, source)
      case rule
      when Sequence
      when Choice
      when String
      when Extend
      end
    end
  end
end


if __FILE__ == $0
  include Garbanzo
  prog = Print.new(Add.new(Num.new(4), Num.new(2)))
  ev = Evaluator.new

  ev.interpret(prog)
end
