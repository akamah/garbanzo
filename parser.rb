# coding: utf-8

require './rule.rb'


module Garbanzo
# 構文解析を行い、意味を持ったオブジェクトを返す。
  class Parser
    include Rule
    
    attr_accessor :grammar

    def initialize(grammar = Grammar.new)
      @grammar = grammar
    end
    
    # 文字列を読み込み、ひとつの単位で実行する。
    def parse(source)
      self.parse_rule(grammar.start, source)
    end

    def parse_rule(rule, source)
      case rule
      when Success
        [rule.value, source]
      when Fail
        raise ParseError, rule.message
      when Any
        if source.size > 0
          [source[0], source[1, -1]]
        else
          raise ParseError, "any: empty input string"
        end
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
          return Repr::String.new(rule.string), source[rule.string.length .. -1]                       
        else
          raise ParseError, "expected #{rule.string}, source = #{source}"
        end
      when Function
        rule.function.call(source)
      when Call
        if r = grammar.rules[rule.rule_name]
          parse_rule(r, source)
        else
          raise "rule: #{rule.rule_name} not found"
        end
      when Bind
        x, rest = parse_rule(rule.rule, source)
        parse_rule(rule.func.call(x), rest)
      else
        raise "PARSE_RULE: error, not a rule #{rule}"
      end      
    end
  end
end
