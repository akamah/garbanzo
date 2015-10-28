#!/usr/bin/ruby
# coding: utf-8


require './repr.rb'
require './lib.rb'
require './rule.rb'
require './evaluator.rb'
require './parser.rb'

module Garbanzo
  # EvaluatorとParserをカプセルしたもの。
  class Interpreter2
    def initialize
      @evaluator = Evaluator.new(construct_root)
    end

    def evaluate(prog)
      @evaluator.evaluate(prog)
    end

    def parse
      evaluate(@evaluator.dot['/']['parser']['sentence'])
    end
    
    def execute(src)
      # 入力ソースコードを評価器にセットする。
      @evaluator.dot['/']['source'] = Repr::store('source'.to_repr => src.to_repr)

      # 設定したソースコードが残っている限り
      while @evaluator.dot['/']['source']['source'].value.size > 0
        sentence = parse
        program  = evaluate(sentence)
        evaluate(program)
      end
    end

    def construct_root
      root = Repr::store({})
      root['add'] = Lib::add
      root['/']   = root

      parser = Repr::store({})
      parser['sentence'] = Repr::choice(Repr::store({}))
      parser['sentence']['children']['homu'] = Repr::begin(
        Repr::store({
          "readhomu".to_repr =>
                     Repr::set(Repr::getenv, "homu".to_repr,
                               Repr::terminal("homu".to_repr)),
          "printhomu".to_repr => Repr::print(Repr::get(Repr::getenv, "homu".to_repr))
        })
      )

      root['parser'] = parser
      root
    end
  end
end


if __FILE__ == $0
  include Garbanzo
  int = Interpreter2.new

  File.open(ARGV[0] || "calc2.garb", "rb") { |f|
    begin
      int.execute(f.read)
    rescue Rule::ParseError => e
      p "parse error, expecting #{e.message}"
    end
  }
end

