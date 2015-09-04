# coding: utf-8

require './rule.rb'


module Garbanzo
# 構文解析を行い、意味を持ったオブジェクトを返す。
  class Parser
    attr_accessor :grammar

    def initialize(grammar = Rule::Grammar.new)
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
        raise Rule::ParseError, rule.message
      when Any
        if source.size > 0
          [source[0], source[1, -1]]
        else
          raise Rule::ParseError, "any: empty input string"
        end
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
  end
end
