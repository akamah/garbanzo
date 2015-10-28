# coding: utf-8
require './repr.rb'
require './lib.rb'


module Garbanzo
  # 評価するやつ。変数とか文脈とか何も考えていないので単純
  class Evaluator
    include Repr
    
    def initialize(root = Repr::store({}))
      @dot = root
      @commands = Hash.new
      install_commands
    end

    def command(commandname, *arguments, &func)
      @commands[commandname] = lambda { |store|
        func.call(*arguments.map {|aname| store[aname.to_repr] })
      }
    end

    # いわゆる演算子を定義する。
    # 名前と型を書いて並べると、自動的に評価したのちにブロックに渡してくれる。
    def operator(opname, *args, &func)
      raise "invalid argument list" if args.length % 2 == 1
      @commands[opname] = lambda { |store|
        param = args.each_slice(2).map {|name, type|
          e = evaluate(store[name.to_repr])
          unless e.is_a? type
            raise "operator `#{opname}' wants `#{name}' to be #{type}, not #{e.class}"
          end
          e
        }
        
        func.call(*param)
      }
    end
    
    def install_commands
      operator("add", "left", Num, "right", Num) do |left, right|
        Repr::num(left.num + right.num)
      end
      
      operator("sub", "left", Num, "right", Num) do |left, right|
        Repr::num(left.num - right.num)
      end
      
      operator("mult", "left", Num, "right", Num) do |left, right|
        Repr::num(left.num * right.num)     
      end

      operator("div", "left", Num, "right", Num) do |left, right|
        Repr::num(left.num / right.num)      
      end

      operator("mod", "left", Num, "right", Num) do |left, right|
        Repr::num(left.num % right.num)     
      end

      
      operator("equal", "left", Object, "right", Object) do |left, right|
        Repr::bool(left.eql?(right))
      end

      operator("notequal", "left", Object, "right", Object) do |left, right|
        Repr::bool(!left.eql?(right))
      end

      operator("lessthan", "left", Num, "right", Num) do |left, right|
        Repr::bool(left.num < right.num)
      end

      
      operator("and", "left", Bool, "right", Bool) do |left, right|
        Repr::bool(left.value && right.value)
      end
      
      operator("or", "left", Bool, "right", Bool) do |left, right|
        Repr::bool(left.value || right.value)
      end
      
      operator("not", "left", Bool, "right", Bool) do |value|
        Repr::bool(!evaluate(value).value)
      end
      
      operator("print", "value", Object) do |value|
        puts show(value)
        value
      end

      operator("set", "object", Store, "key", Object, "value", Object) do |object, key, value|
        object[key] = value
      end

      operator("get", "object", Store, "key", Object) do |object, key|
        result = object[key]
        raise "GET: undefined key #{object.inspect} for #{key.inspect}" unless result
        result
      end

      operator("size", "object", Store) do |object|
        object.size
      end

      operator("remove", "object", Store, "key", Object) do |object, key|
        object.remove(key)
      end
      
      operator("exist", "object", Store, "key", Object) do |object, key|
        object.exist(key)
      end

      operator("getprevkey", "object", Store, "origin", Object) do |object, key|
        object.get_prev_key(key)
      end

      operator("getnextkey", "object", Store, "origin", Object) do |object, key|
        object.get_next_key(key)
      end

      operator("insertprev", "object", Store, "origin", Object,
               "key", Object, "value", Object) do |object, origin, key, value|
        object.insert_prev(origin, key, value)
      end

      operator("insertnext", "object", Store, "origin", Object,
               "key", Object, "value", Object) do |object, origin, key, value|
        object.insert_next(origin, key, value)
      end

      operator("firstkey", "object", Store) do |object|
        object.first_key
      end
      
      operator("lastkey", "object", Store) do |object|
        object.last_key
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
        result = false.to_repr

        body.each_key do |k, v|
          result = evaluate(v)
        end
        
#        Lib::each_list(body) { |child|
#          result = evaluate(child)
#        }

        result
      end

      operator("getenv") do
        @dot
      end

      operator("setenv", "env", Store) do |env|
        @dot = env
      end

      operator("call", "func", Callable, "args", Store) do |func, args|
        case func
        when Function
          oldenv = @dot
          args[".."] = func.env # 環境を拡張

          unless args.exist("/".to_repr)
            args["/"] = oldenv["/"]
          end
          
          @dot = args
          result = evaluate(func.body)
          @dot = oldenv

          result
        when Procedure
          func.proc.call(args)
        else
          raise "EVALUATE: callee is not a function: #{func}" unless f.is_a? Function
        end
      end

      operator("eval", "env", Store, "program", Object) do |env, program|
        prevEnv = @dot
        @dot = env
        result = self.evaluate(program)
        @dot = prevEnv

        result
      end

      
      operator("append", "left", String, "right", String) do |left, right|
        Repr::string(left.value + right.value)
      end

      operator("charat", "string", String, "index", Num) do |string, index|
        if index.num < string.value.length
          Repr::string(string.value[index.num])
        else
          raise "CHARAT: index out of string's length"
        end
      end

      operator("length", "string", String) do |string|
        Repr::num(string.value.length)
      end

      operator("copy", "object", Object) do |object|
        object.copy
      end
    end

    
    def eval_store(s)
      return s unless s.exist("@").value
      feature = s["@"]

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
      when Num, Bool, String, Function, Procedure
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
        p.value
      when Store
        "{" + p.table.map {|k, v|
          show(k) + ":\n" + show(v).gsub(/^/, '  ')
        }.to_a.join("\n") + "}"
      when Function
        "^{ #{show(p.body)} }"
      when Procedure
        "<proc>"
      else
        raise "SHOW: argument is not a repr: #{p.inspect}"
      end
    end
  end
end
