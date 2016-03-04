# coding: utf-8

# このパーサオブジェクトは，プロトタイプ1でのみ使用している．

require './repr.rb'
require './rule.rb'

module Garbanzo
# 構文解析を行い、意味を持ったオブジェクトを返す。
  class Parser
    include Rule
    include Rule::Private
    
    attr_accessor :grammar

    def initialize(grammar = Grammar.new)
      @grammar = grammar
    end
    
    # 文字列を読み込み、ひとつの単位で実行する。
    def parse(source)
      self.parse_rule(grammar.start, source)
    end

    def parse_sequence(rule, source)
      es, rest = rule.children.reduce([[], source]) do |accum, c|
        e1, r1 = parse_rule(c, accum[1])
        [accum[0] << e1, r1]
      end

      es = rule.func.call(*es) if rule.func != nil
      return es, rest
    end
    
    def parse_choice(rule, source)
#      errs = []
      for c in rule.children
        begin
          return parse_rule(c, source)
        rescue ParseError => e
#          errs << e
        end
      end

      raise ParseError, "no choice "
#      raise errs.max_by {|a| a.line}
    end

    def parse_string(rule, source)
      if source.start_with?(rule.string)
        return Repr::String.new(rule.string), source[rule.string.length .. -1]
      else
        raise ParseError.new("#{rule.message}, around #{source[0..20]}", (10000 - source.length))
      end
    end
    
    def parse_rule(rule, source)
      case rule
      when Choice
        parse_choice(rule, source)
      when String
        parse_string(rule, source)
      when Sequence
        parse_sequence(rule, source)
      when Function
        rule.function.call(source)
      when Call
        if r = grammar.rules[rule.rule_name]
          parse_rule(r, source)
        else
          raise ParseError.new("rule: #{rule.rule_name}", (10000 - source.length))
        end
      when Bind
        x, rest = parse_rule(rule.rule, source)
        parse_rule(rule.func.call(x), rest)
      when And
        x, _ = parse_rule(rule.rule, source)
        [x, source]
      when Not
        begin
          parse_rule(rule.rule, source)
        rescue ParseError
          return [Repr::store({}), source]
        end
        raise ParseError.new("not #{rule.message}", (10000 - source.length))
      else
        raise "PARSE_RULE: error, not a rule #{rule}"
      end      
    end
  end
end
