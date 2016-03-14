#!/usr/local/bin/ruby
# coding: utf-8

=begin
構文拡張可能な言語プロトタイプver.2
Garbanzoの文法をGarbanzoのプログラムで記述できる．

=end

require './repr.rb'
require './lib.rb'
require './rule.rb'
require './evaluator.rb'
require './parser.rb'
require './interpreter.rb'


module Garbanzo
  include Repr
  
  class Proto2 < Interpreter
    attr_accessor :evaluator
    attr_accessor :debug
    
    def initialize(debug = true)
      super('proto2')
      @debug = debug
    end

    def evaluate(prog)
      @evaluator.evaluate(prog)
    end

    def parse
      evaluate(@evaluator.dot['/']['parser']['sentence'])
    end

    def execute(src)
      # 入力ソースコードを評価器にセットする。
      @evaluator.dot['/']['source'] = Repr::Store.create_source(src)

      # 設定したソースコードが残っている限り
      while !@evaluator.dot['/']['source'].is_eof?
        sentence = parse
        puts("> #{sentence.inspect}") if debug
        res = evaluate(sentence)
        puts("=> #{res.inspect}") if debug
      end

      res
    end

    def install_string_rule(root)
      stringp = Repr::procedure(
        lambda { |e, env|
          source = env["/"]["source"]
          source.parse_string.to_repr
        })
      root['parser']['string'] = Repr::call(
        Repr::quote(stringp), {}.to_repr)
    end

    def install_whitespaces_rule(root)
      root['parser']['whitespaces'] =
        Repr::many(
          Repr::quote(
            Repr::oneof(" \t\n".to_repr)))
    end

    def install_pair_rule(root)
      pairp = Repr::Procedure.new(
        lambda { |e, env|
          keyp = env["/"]["parser"]["key"]
          exprp = env["/"]["parser"]["expression"]
          whitep = env["/"]["parser"]["whitespaces"]
          
          k = e.evaluate(keyp)
          e.evaluate(whitep)
          e.evaluate(Repr::terminal(":".to_repr))
          e.evaluate(whitep)
          v = e.evaluate(exprp)
          e.evaluate(whitep)

          Repr::store({ k => v })
        })

      root['parser']['key'] = root['parser']['string']
      root['parser']['pair'] = Repr::call(
        Repr::quote(pairp), {}.to_repr)
    end

    def install_datastore_rule(root)
      datastorep = Repr::Procedure.new(
        lambda { |e, env|
          pairp  = env['/']['parser']['pair']
          whitep = env["/"]["parser"]["whitespaces"]
          endp = Repr::terminal("}".to_repr)
          result = {}.to_repr

          e.evaluate(Repr::terminal("{".to_repr))
          e.evaluate(whitep)

          head = e.evaluate(
            Repr::choice(
              { "pair" => pairp,
                "exit" => endp }.to_repr))
          
          return result if head == "}".to_repr # {}

          result = head # { a: b 

          rest = Repr::begin(
            {
              "comma" => Repr::terminal(",".to_repr),
              "whitespaces" => Repr::eval(Repr::getenv, Repr::quote(whitep)),
              "pair" => Repr::eval(Repr::getenv, Repr::quote(pairp))
            }.to_repr)

          body = e.evaluate(Repr::many(Repr::quote(rest)))

          body.each_key do |_, entry|
            entry.each_key do |k, v|
              result[k] = v
            end
          end

          e.evaluate(Repr::terminal("}".to_repr))
          
          result
        })
      root['parser']['datastore'] = Repr::call(
        Repr::quote(datastorep), {}.to_repr)
    end
    
    def construct_root
      root = Repr::store({})
      root['add'] = Lib::add
      root['/']   = root
      
      parser = Repr::store({})
      parser['/'] = root

      root['parser'] = parser

      parser['sentence'] = Repr::choice(Repr::store({}))

      root['foreach'] = Repr::function(
        root,
        Repr::if(Repr::equal(Repr::size(Repr::get(Repr::getenv, "store".to_repr)),
                             0.to_repr),
                 true.to_repr,
                 Repr::begin(
                   { "getlast"    => Repr::set(Repr::getenv, "last".to_repr,
                                               Repr::lastkey(Repr::get(Repr::getenv, "store".to_repr))),
                     "initkey"    => Repr::set(Repr::getenv, "key".to_repr,
                                               Repr::firstkey(Repr::get(Repr::getenv, "store".to_repr))),
                     "loop" => Repr::while(
                       Repr::notequal(Repr::get(Repr::getenv, "last".to_repr),
                                      Repr::get(Repr::getenv, "key".to_repr)),
                       Repr::begin(
                         { "call" => Repr::call(
                             Repr::get(Repr::getenv, "func".to_repr),
                             Repr::datastore(
                               { "key" => Repr::get(Repr::getenv, "key".to_repr),
                                 "value" => Repr::get(Repr::get(Repr::getenv, "store".to_repr),
                                                      Repr::get(Repr::getenv, "key".to_repr))
                               }.to_repr)),
                           "updatekey" => Repr::set(Repr::getenv, "key".to_repr,
                                                    Repr::getnextkey(
                                                      Repr::get(Repr::getenv, "store".to_repr),
                                                      Repr::get(Repr::getenv, "key".to_repr)))
                         }.to_repr)),
                     "calllast" => Repr::call(
                       Repr::get(Repr::getenv, "func".to_repr),
                       Repr::datastore(
                         { "key" => Repr::get(Repr::getenv, "key".to_repr),
                           "value" => Repr::get(Repr::get(Repr::getenv, "store".to_repr),
                                                Repr::get(Repr::getenv, "key".to_repr))
                         }.to_repr)),                       
                     "return" => true.to_repr
                   }.to_repr)))

      install_string_rule(root)
      install_whitespaces_rule(root)
      install_pair_rule(root)
      install_datastore_rule(root)


      ## an expression is either a datastore or a string
      parser['expression'] = Repr::choice(
        { "datastore" => parser['datastore'],
          "string" => parser['string']
        }.to_repr)

      ## sentence ::= datastore
      parser['sentence']['children']['datastore'] = parser['datastore']
      root
    end

    def show_parse_error(e)
      puts self.evaluator.dot['/']['source']['source'].value.split("\n")[e.line - 1]
      super(e)
    end

    def show_general_error(e)
      linum = self.evaluator.dot['/']['source'].line.num
      puts self.evaluator.dot['/']['source']['source'].value.split("\n")[linum - 1]
      super(e)
    end
  end
end


if __FILE__ == $0
  include Garbanzo
  Proto2.new(false).start(ARGV)
end
