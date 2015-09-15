# coding: utf-8
require './repr.rb'
require './lib.rb'


module Garbanzo
  # 評価するやつ。変数とか文脈とか何も考えていないので単純
  class Evaluator
    include Repr
    
    def initialize
      @dot = Store.new({})
      @commands = Hash.new
      install_commands
    end

    def command(commandname, *arguments, &func)
      @commands[commandname] = lambda { |store|
        func.call(*arguments.map {|aname| store[aname.to_repr] })
      }
    end

    def install_commands
      command("add", "left", "right") do |left, right|
        Repr::num(evaluate(left).num + evaluate(right).num)
      end

      command("sub", "left", "right") do |left, right|
        Repr::num(evaluate(left).num - evaluate(right).num)
      end
      
      command("mult", "left", "right") do |left, right|
        Repr::num(evaluate(left).num * evaluate(right).num)     
      end

      command("div", "left", "right") do |left, right|
        Repr::num(evaluate(left).num / evaluate(right).num)      
      end

      command("mod", "left", "right") do |left, right|
        Repr::num(evaluate(left).num % evaluate(right).num)     
      end

      
      command("equal", "left", "right") do |left, right|
        Repr::bool(evaluate(left).eql?(evaluate(right)))
      end

      command("notequal", "left", "right") do |left, right|
        Repr::bool(!evaluate(left).eql?(evaluate(right)))
      end

      
      command("and", "left", "right") do |left, right|
        Repr::bool(evaluate(left).value && evaluate(right.value))
      end
      
      command("or", "left", "right") do |left, right|
        Repr::bool(evaluate(left).value || evaluate(right.value))
      end
      
      command("and", "left", "right") do |left, right|
        Repr::bool(!evaluate(left).value)
      end
      
      command("print", "value") do |value|
        result = evaluate(value)
        puts show(result)
        result
      end

      command("set", "object", "key", "value") do |object, key, value|
        obj = evaluate(object)
        key = evaluate(key)
        val = evaluate(value)

        raise "SET: object is not a store #{obj}" unless obj.is_a? Store
        obj.table[key] = val
      end

      command("get", "object", "key") do |object, key|
        obj = evaluate(object)
        key = evaluate(key)
        
        raise "GET: object #{obj.inspect} is not a store #{inspect}" unless obj.is_a? Store
        result = obj.table[key]
        raise "GET: undefined key #{obj.inspect} for #{key.inspect}" unless result
        result
      end

      command("size", "object") do |object|
        obj = evaluate(object)

        raise "SIZE: object #{obj.inspect} is not a store #{inspect}" unless obj.is_a? Store
        obj.table.size.to_repr
      end

      command("quote", "value") do |value|
        value
      end
      
      command("while", "condition", "body") do |condition, body|
        falseObj = Bool.new(false)
        result = Bool.new(true)
        
        while evaluate(condition) != falseObj
          result = evaluate(body)
        end
        
        result
      end

      command("if", "condition", "consequence", "alternative") do |condition, consequence, alternative|
        if evaluate(condition) != false.to_repr
          evaluate(consequence)
        else
          evaluate(alternative)
        end
      end

      command("lambda", "env", "body") do |env, body|
        Repr::function(evaluate(env), body)
      end
      
      command("begin", "body") do |body|
        Lib::each_list(body) { |child|
          evaluate(child)
        }
      end

      command("getenv") do
        @dot
      end

      command("setenv", "env") do |env|
        @dot = evaluate(env)
      end

      command("call", "func", "args") do |func, args|
        f = evaluate(func)
        a = evaluate(args)
        
        raise "EVALUATE: callee is not a function: #{func}" unless f.is_a? Function
        raise "EVALUATE: arguments is not a data store: #{args}" unless a.is_a? Store

        oldenv = @dot
        a.table["..".to_repr] = f.env # 環境を拡張

        @dot = a
        result = evaluate(f.body)
        @dot = oldenv

        result
      end

      command("append", "left", "right") do |left, right|
        Repr::string(left.value + right.value)
      end

      command("charat", "string", "index") do |string, index|
        if index.num < string.value.length
          Repr::string(string.value[index.num])
        else
          raise "CHARAT: index out of string's length"
        end
      end

      command("length", "string") do |string|
        Repr::num(string.value.length)
      end
    end

    
    def eval_store(s)
      feature = s["@"]

      return s if feature == nil

      feature = evaluate(feature)
      f = @commands[feature.value] or raise "EVALUATE2: #{feature.inspect} is not a valid feature name"
      f.call(s)
      
      # case feature.value
      # when "add";      eval_add(s['left'], s['right'])
      # when "sub";      eval_sub(s['left'], s['right'])
      # when "mult";     eval_mult(s['left'], s['right'])
      # when "div";      eval_div(s['left'], s['right'])
      # when "mod";      eval_mod(s['left'], s['right'])

      # when "equal";    eval_equal(s['left'], s['right'])
      # when "notequal"; eval_notequal(s['left'], s['right'])

      # when "and";      eval_and(s['left'], s['right'])
      # when "or";       eval_or(s['left'], s['right'])
      # when "not";      eval_not(s['value'])

      # when "print";    eval_print(s['value'])

      # when "set";      eval_set(s['object'], s['key'], s['value'])
      # when "get";      eval_get(s['object'], s['key'])
      # when "size";     eval_size(s['object'])

      # when "quote";    eval_quote(s['value'])
      # when "while";    eval_while(s['condition'], s['body'])
      # when "if";       eval_if(s['condition'], s['consequence'], s['alternative'])
      # when "lambda";   eval_lambda(s['env'], s['body'])
      # when "begin";    eval_begin(s['body'])

      # when "getenv";   eval_getenv()
      # when "setenv";   eval_setenv(s['env'])

      # when "call";     eval_call(s['func'], s['args'])
      # when "append";   eval_append(s['left'], s['right'])
      # when "charat";   eval_charat(s['string'], s['index'])
      # when "length";   eval_length(s['string'])
      # else
        
      # end
    end
    
    def evaluate(program)
      case program
      when Num, Bool, String, Function
        program
      when Store;
        eval_store(program)
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
        "{" + p.table.map {|k, v|
          show(k) + ":\n" + show(v).gsub(/^/, '  ')
        }.to_a.join("\n") + "}"
      when Function
        "^{ #{show(p.body)} }"
      else
        raise "SHOW: argument is not a repr: #{p.inspect}"
      end
    end
  end
end
