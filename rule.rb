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
        Garbanzo::Rule::sequence(self, other.to_rule) { |a, b| b }
      end

      def |(other)
        Garbanzo::Rule::choice(self, other.to_rule)
      end

      def map(&f)
        Garbanzo::Rule::bind(self) { |result|
          Garbanzo::Rule::success(f.call(result))
        }
      end
    end

    module Private
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
    end

    # オープンクラス。クラスのみんなには、内緒だよ！
    class ::Array
      def sequence(&func); Garbanzo::Rule::sequence(*self.map(&:to_rule), &func); end
      def choice(&func);   Garbanzo::Rule::choice(*self.map(&:to_rule), &func); end
      def to_rule; raise "Array#to_rule is ambiguous operation"; end
    end

    class ::String
      def to_rule; Garbanzo::Rule::string(self); end
    end

    class ::Symbol
      def to_rule; Garbanzo::Rule::call(self); end
    end
    
    class ::Proc
      def to_rule; Garbanzo::Rule::function(&self); end
    end

    # リファクタリングして、Successなどのクラスを除去したい。
    # そのために、一旦既存のクラスをメソッドに置き換えることとした。
    def self.success(result)
      Private::Success.new(result)
    end

    def self.fail(message = "failure")
      Private::Fail.new(message)
    end

    def self.any
      Private::Any.new
    end

    def self.sequence(*children, &func)
      Private::Sequence.new(*children, &func)
    end

    def self.choice(*children)
      Private::Choice.new(*children)
    end

    def self.string(str)
      Private::String.new(str)
    end

    def self.call(rule_name)
      Private::Call.new(rule_name)
    end

    def self.bind(rule, &func)
      Private::Bind.new(rule, &func)
    end

    def self.function(&func)
      Private::Function.new(&func)
    end
    
    def self.optional(rule, default = nil)
      rule | success(default)
    end

    def self.many(rule)
      many_rec = lambda {|accum|
        optional(bind(rule) { |result|
                   many_rec.call(accum + [result])
                 }, accum)
      }
      many_rec.call([])
    end

    def self.many_one(rule)
      [rule, many(rule)].sequence {|r, rs|
        [r] + rs
      }
    end

    # 与えられた文字列中のある一文字にマッチする
    def self.one_of(chars)
      chars.split('').choice
    end

    def self.whitespace
      one_of(" \n\r\t")
    end

    def self.whitespaces
      many_one(whitespace).map { " ".to_repr }
    end

    def self.separate_by(rule, separator)
      optional([rule, many(separator >> rule)].sequence { |a, rest|
                 [a] + rest
               }, [])
    end
    
    def self.split_by_spaces(rule, *rules)
      rules.reduce([rule]) { | accum, r|
        accum + [whitespaces, r]
      }.sequence.map {|results|
        a = []
        results.each_with_index {|item, idx|
          a << item if idx % 2 == 0
        }
        a
      }
    end
  end
end
