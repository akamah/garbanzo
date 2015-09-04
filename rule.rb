# coding: utf-8
module Garbanzo
  module Rule
    # 構文。つまり、名前をつけたルールの集合を持つもの。
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
    
    # 構文解析に失敗した時は、例外を投げて伝えることにする。
    class ParseError < StandardError; end

    # ルール、パーサコンビネータで言う所のParser
    class Rule
      def to_rule
        return self
      end

      def >>(other)
        Sequence.new(self, other.to_rule)
      end

      def |(other)
        Choice.new(self, other.to_rule)
      end
    end

    # 無条件に成功するパーサ
    class Success < Rule
      attr_accessor :value

      def initialize(value)
        @value = value        
      end
    end

    # 無条件に失敗するパーサ
    class Fail < Rule
      attr_accessor :message

      def initialize(message = "failure")
        @message = message
      end
    end
    
    # 任意の1文字にマッチするパーサ
    class Any < Rule
    end
    
    # 連続
    class Sequence < Rule
      attr_accessor :children
      attr_accessor :func

      def initialize(*children, &func)
        @children = children
        @func     = func
      end
    end

    # 選択
    class Choice < Rule
      attr_accessor :children

      def initialize(*children)
        @children = children        
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

    # ルールを結合する
    class Bind < Rule
      attr_accessor :rule
      attr_accessor :func

      def initialize(rule, &func)
        @rule = rule
        @func = func        
      end
    end
    
    # 関数で処理する。
    class Function < Rule
      attr_accessor :function

      def initialize(&function)
        @function = function
      end
    end

    # オープンクラス。クラスのみんなには、内緒だよ！
    class ::Array
      def sequence(&func); Sequence.new(*self.map(&:to_rule), &func); end
      def choice(&func);   Choice.new(*self.map(&:to_rule), &func); end
      def to_rule; raise "Array#to_rule is ambiguous operation"; end
    end

    class ::String
      def to_rule; Garbanzo::Rule::String.new(self); end
    end

    class ::Symbol
      def to_rule; Garbanzo::Rule::Call.new(self); end
    end
    
    class ::Proc
      def to_rule; Garbanzo::Rule::Function.new(&self); end
    end

    def self.optional(rule, default = nil)
      rule | Success.new(default)
    end

    def self.many(rule)
      many_rec = lambda {|accum|
        optional(Bind.new(rule) { |result|
                   many_rec.call(accum + [result])
                 }, accum)
      }
      many_rec.call([])
    end
  end
end
