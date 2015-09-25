# coding: utf-8
=begin rdoc
言語処理系の開発：拡張可能な構文を持つ言語のプロトタイプその1
1. ちょっとしたASTを評価するものと
2. パーサコンビネータっぽい構文解析装置と
3. デフォルトでは構文の拡張しかできない構文を持つ
=end

require './repr.rb'
require './lib.rb'
require './rule.rb'
require './evaluator.rb'
require './parser.rb'

module Garbanzo
  # EvaluatorとParserをカプセルしたもの。
  class Interpreter
    def initialize
      @evaluator = Evaluator.new(construct_root)
      @parser    = Parser.new

      install_grammar_extension
    end

    def evaluate(prog)
      @evaluator.evaluate(prog)
    end

    def parse(src)
      @parser.parse(src)
    end
    
    def execute(src)
      while src != ""
        prog, src = parse(src)
#        puts "program: #{@evaluator.show(prog)}"
        evaluate(prog)
      end
    end
    
    # 構文拡張のやつです。
    def install_grammar_extension
      @nth ||= 0
      @parser.grammar.rules[:sentence] = Rule::choice(
        ['#{', 
         Rule::many(!'#}'.to_rule >> Rule::any).map {|cs|
           @nth += 1
           to_eval = cs.map(&:value).join
           @parser.instance_eval(to_eval, "(grammar_extension: #{@nth})")
           Repr::Bool.new(false)
         },
         '#}'].sequence >> Rule::success(false.to_repr))
    end

    def construct_root
      root = Repr::store({})
      root['add'] = Lib::add
      root['/']   = root
      root
    end
  end
end


if __FILE__ == $0
  include Garbanzo
  int = Interpreter.new

  File.open(ARGV[0] || "calc.garb", "rb") { |f|
    int.execute(f.read)
  }
end
