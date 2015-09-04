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


module Garbanzo
  # 評価するやつ。変数とか文脈とか何も考えていないので単純
  class Evaluator
    include Repr
    
    def initialize
      @dot = Store.new({})
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
        Lib::each_list(program.body) { |child|
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
      @evaluator = Evaluator.new
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
