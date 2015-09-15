# coding: utf-8

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

        begin
          parse_rule(rule.children[-1], source)
        rescue ParseError
          raise ParseError, "expected #{rule.message}"
        end
      when String
        if source.start_with?(rule.string)
          return Repr::String.new(rule.string), source[rule.string.length .. -1]                       
        else
          raise ParseError, "expected #{rule.message}"
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
      when And
        x, _ = parse_rule(rule.rule, source)
        [x, source]
      when Not
        begin
          parse_rule(rule.rule, source)
        rescue ParseError
          return [Repr::store({}), source]
        end
        raise ParseError, "expected #{rule.message}"
      else
        raise "PARSE_RULE: error, not a rule #{rule}"
      end      
    end
  end
end
