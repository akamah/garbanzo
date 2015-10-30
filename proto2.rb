#!/usr/bin/ruby
# coding: utf-8


require './repr.rb'
require './lib.rb'
require './rule.rb'
require './evaluator.rb'
require './parser.rb'

module Garbanzo
  include Repr
  
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

        p @evaluator.dot['/']['source']
      end
    end

    def construct_root
      root = Repr::store({})
      root['add'] = Lib::add
      root['/']   = root
      
      parser = Repr::store({})
      parser['/'] = root
      parser['sentence'] = Repr::choice(Repr::store({}))
      parser['sentence']['children']['homu'] = Repr::begin(
        Repr::store({
          "readhomu".to_repr =>
                     Repr::set(Repr::getenv, "homu".to_repr,
                               Repr::terminal("homu".to_repr)),
          "printhomu".to_repr => Repr::print(Repr::get(Repr::getenv, "homu".to_repr))
        })
      )

      # root['foreach'] = function(
      #   root,
      #   Repr::begin(
      # { "getfirst"  => set(getenv, "first".to_repr, firstkey(get(getenv, "store".to_repr))),
          #   "setkey"    => set(getenv, "key".to_repr, get(getenv, "first".to_repr)),
          #   "callfirst" => call(get(getenv, "func".to_repr),
          #                       datastore({ "argument" => get(get(getenv, "store".to_repr),
          #                                                     get(getenv, "key".to_repr)) }.to_repr)),
          #   "loop" => Repr::while(
          #     notequal(getnextkey(get(getenv, "store".to_repr)),
          #              get(getenv, "first".to_repr)),
          #     Repr::begin(
          #       { "call" => call(get(getenv, "func".to_repr),
          #                        datastore({ "argument" => get(get(getenv, "store".to_repr),
          #                                                      getnextkey(get(getenv, "store".to_repr),
          #                                                                 "key".to_repr)) }.to_repr)),


      root['oneof'] = Repr::function(
        root,
        Repr::begin(
          { "init_i" => Repr::set(Repr::getenv, "i".to_repr, 0.to_repr),
            "init_store" => Repr::set(Repr::getenv, "store".to_repr, Repr::datastore({}.to_repr)),

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
            "print" => Repr::print(Repr::get(Repr::getenv, "store".to_repr)),
            "choice" => Repr::choice(Repr::get(Repr::getenv, "store".to_repr))
          }.to_repr))

      parser['sentence']['children']['hoge'] = Repr::begin(
        { "oneof" => Repr::call(root['oneof'], { "string" => "hoge" }.to_repr),
          "print" => Repr::print("hoge".to_repr)
        }.to_repr)
      
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

