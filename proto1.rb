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
end


if __FILE__ == $0
  include Garbanzo
  prog = Print.new(Add.new(Num.new(4), Num.new(2)))
  ev = Evaluator.new

  ev.interpret(prog)
end
