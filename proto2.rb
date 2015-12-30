#!/usr/local/bin/ruby
# coding: utf-8

require 'stackprof'

require './repr.rb'
require './lib.rb'
require './rule.rb'
require './evaluator.rb'
require './parser.rb'


module Garbanzo
  include Repr
  
  # EvaluatorとParserをカプセルしたもの。
  class Interpreter2
    attr_accessor :evaluator
    attr_accessor :debug
    
    def initialize(debug = true)
      @evaluator = Evaluator.new(construct_root)
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
      #root['parser']['whitespaces'] = false.to_repr
      root['parser']['whitespaces'] =
        Repr::many(
          Repr::quote(
            Repr::choice(
              { "space" => Repr::terminal(" ".to_repr),
                "newline" => Repr::terminal("\n".to_repr),
                "tab" => Repr::terminal("\t".to_repr) }.to_repr)))
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
      # parser['sentence']['children']['homu'] = Repr::begin(
      #   Repr::store({
      #     "readhomu".to_repr =>
      #                Repr::set(Repr::getenv, "homu".to_repr,
      #                          Repr::terminal("homu".to_repr)),
      #     "printhomu".to_repr => Repr::print(Repr::get(Repr::getenv, "homu".to_repr))
      #   })
      # )

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

      root['oneof'] = Repr::function(
        root,
        Repr::begin(
          { "init_i" => Repr::set(Repr::getenv, "i".to_repr, 0.to_repr),
            "init_store" => Repr::set(Repr::getenv, "store".to_repr, Repr::datastore({}.to_repr)),
#            "debug" => Repr::print("debug".to_repr),
            "loop" => Repr::while(
              Repr::notequal(Repr::get(Repr::getenv, "i".to_repr),
                             Repr::length(Repr::get(Repr::getenv, "string".to_repr))),
              Repr::begin(
                { "settostore" =>  Repr::set(Repr::get(Repr::getenv, "store".to_repr), Repr::get(Repr::getenv, "i".to_repr),
                                             Repr::datastore({ "@" => "terminal",
                                                               "string" => Repr::charat(Repr::get(Repr::getenv, "string".to_repr),
                                                                                        Repr::get(Repr::getenv, "i".to_repr))
                                                             }.to_repr)),
                  "increment" => Repr::set(Repr::getenv, "i".to_repr, Repr::add(Repr::get(Repr::getenv, "i".to_repr), 1.to_repr))
                }.to_repr)),
#            "print" => Repr::print(Repr::get(Repr::getenv, "store".to_repr)),
            "choice" => Repr::datastore(
              { "@" => "choice",
                "children" => Repr::get(Repr::getenv, "store".to_repr)
              }.to_repr)
          }.to_repr))

      
      # parser['sentence']['children']['hoge'] = Repr::scope(
      #   { "readhoge" => Repr::terminal('hoge'.to_repr),
      #     "foreach"  => Repr::call(root['foreach'],
      #                              { "store" => {
      #                                  1 => "mado",
      #                                  2 => "homu",
      #                                  3 => "saya"
      #                                }.to_repr,
      #                                "func" => Repr::function(
      #                                  Repr::getenv,
      #                                  Repr::begin(
      #                                    { "printkey" => Repr::print(Repr::get(Repr::getenv, "key".to_repr)),
      #                                      "printval" => Repr::print(Repr::get(Repr::getenv, "value".to_repr))
      #                                    }.to_repr))
      #                              }.to_repr)
      #   }.to_repr)
      
      # parser['sentence']['children']['number'] = Repr::begin(
      #   { "head" => set(getenv, "head".to_repr, call(get(get(getenv, "/".to_repr), "oneof".to_repr),
      #                                                datastore({ "string" => "0123456789" }.to_repr))),
      #     "tail" => set(getenv, "many(call(get(get(getenv, "/".to_repr), "oneof".to_repr),
      #                         datastore({ "string" => "0123456789" }.to_repr))),
      #     "init" => set(getenv, "i".to_repr, 0.to_repr),
      #     "loop" => Repr::while(
      #         notequal(get(getenv, "i".to_repr),
      #                  size(getenv, "string")),
      #         Repr::begin(
      #           { "settostore" =>  set(get(getenv, "store".to_repr), get(getenv, "i".to_repr), 
      #                                  charat(get(getenv, "string"), get(getenv, "i".to_repr))),
      #             "increment" => set(getenv, "i".to_repr, add(get(getenv, "i".to_repr), 1.to_repr))
      #           }.to_repr)),

      # parser['string'] = Repr::scope(
      #   { "beginstring" => Repr::terminal('"'.to_repr),
      #     "contents"    => Repr::set(Repr::getenv, "tmp".to_repr,
      #                                Repr::many(Repr::call(root['oneof'], { "string" => " '\n.$@/abcdefghijklmnopqrstuvwxyz" }.to_repr))),
      #     "endstring"   => Repr::terminal('"'.to_repr),
      #     "result"      => Repr::set(Repr::getenv, "res".to_repr, "".to_repr),
      #     "convert"     => Repr::call(root['foreach'],
      #                                 Repr::datastore(
      #                                   { "store" => Repr::get(Repr::getenv, "tmp".to_repr),
      #                                     "func"  => Repr::lambda(
      #                                       Repr::getenv,
      #                                       Repr::set(Repr::get(Repr::getenv, "..".to_repr),
      #                                                 "res".to_repr,
      #                                                 Repr::append(
      #                                                   Repr::get(Repr::get(Repr::getenv, "..".to_repr),
      #                                                             "res".to_repr),
      #                                                   Repr::get(Repr::getenv, "value".to_repr))))
      #                                   }.to_repr)),
      #     "return"      => Repr::get(Repr::getenv, "res".to_repr)
      #   }.to_repr)

      install_string_rule(root)
      install_whitespaces_rule(root)
      install_pair_rule(root)
      install_datastore_rule(root)

      
      ## root
      # parser['datastore'] = Repr::scope(
      #   { "begindatastore" => Repr::terminal("{".to_repr),
      #     "initresult" => Repr::set(Repr::getenv, "result".to_repr, Repr::datastore({})),
      #     "readrec" => Repr::many(
      #       Repr::quote(
      #         Repr::begin(
      #           { "readstring"     => Repr::set(
      #               Repr::getenv, "key".to_repr,
      #               Repr::eval(Repr::getenv,
      #                          Repr::get(Repr::get(Repr::get(Repr::getenv, "/".to_repr),
      #                                              "parser".to_repr),
      #                                    "expression".to_repr))),
      #             "separator"      => Repr::terminal(":".to_repr),
      #             "readexpression" => Repr::set(
      #               Repr::getenv, "value".to_repr,
      #               Repr::eval(Repr::getenv,
      #                          Repr::get(Repr::get(Repr::get(Repr::getenv, "/".to_repr),
      #                                              "parser".to_repr),
      #                                    "expression".to_repr))),
      #             "readcomma" => Repr::terminal(",".to_repr),
      #             "updatevalue" => Repr::set(Repr::get(Repr::getenv, "result".to_repr),
      #                                        Repr::get(Repr::getenv, "key".to_repr),
      #                                        Repr::get(Repr::getenv, "value".to_repr)),
      #           }.to_repr))),
      #     "enddatastore" => Repr::terminal("}".to_repr),
      #     "return" => Repr::get(Repr::getenv, "result".to_repr)
      #   }.to_repr)


      ## an expression is either a datastore or a string
      parser['expression'] = Repr::choice(
        { "datastore" => parser['datastore'],
          "string" => parser['string']
        }.to_repr)

#      parser['sentence']['children']['expression'] = parser['expression']
      parser['sentence']['children']['datastore'] = parser['datastore']
      root
    end
  end
end


if __FILE__ == $0
  include Garbanzo
  int = Interpreter2.new(false)

  File.open(ARGV[0] || "calc2.garb", "rb") { |f|
    begin
      StackProf.run(mode: :cpu, out: 'proto2.dump') do
        int.execute(f.read)
      end
    rescue Rule::ParseError => e
      puts "parse error, expecting #{e.message}"
      puts int.evaluator.dot['/']['source']['source'].value.split("\n")[e.line - 1]
    rescue => e
      line = int.evaluator.dot['/']['source']['line'].num - 1
      puts "some error, on #{line}: #{e.message}"
      puts int.evaluator.dot['/']['source']['source'].value.split("\n")[line]
    end
  }

  int.evaluator.debug_print
end
