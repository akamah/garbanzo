# coding: utf-8
require './repr.rb'
require './lib.rb'
require './rule.rb'
require './stream.rb'


module Garbanzo
  # 評価するやつ。変数とか文脈とか何も考えていないので単純
  class Evaluator
    include Repr

    attr_accessor :dot
    
    def initialize(root = Repr::store({}))
      @dot = root
      @commands = Hash.new
      @callcount = Hash.new { 0 }
      
      install_commands
    end

    def command(commandname, *arguments, &func)
      @commands[commandname] = lambda { |store|
        @callcount[commandname] += 1
        func.call(*arguments.map {|aname| store[aname.to_repr] })
      }
    end

    # いわゆる演算子を定義する。
    # 名前と型を書いて並べると、自動的に評価したのちにブロックに渡してくれる。
    def operator(opname, *args, &func)
      raise "invalid argument list" if args.length % 2 == 1
      @commands[opname] = lambda { |store|
        @callcount[opname] += 1
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

      command("datastore", "object") do |object|
        store = Repr::store({})
        
        object.each_key { |k|
          store[k] = self.evaluate(object[k])
        }
        store
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

        result
      end

      # スコープを導入するコマンド。
      command("scope", "body") do |body|
        emptyenv = {}.to_repr
        extend_scope(emptyenv, @dot) do
          result = false.to_repr

          body.each_key do |k, v|
            result = evaluate(v)
          end

          result
        end
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
          extend_scope(args, func.env) do
            evaluate(func.body)
          end
        when Procedure
          extend_scope(args, {}.to_repr) do
            func.proc.call(self, args)
          end
        else
          raise "EVALUATE: callee is not a function: #{func}" unless f.is_a? Function
        end
      end

      operator("eval", "env", Store, "program", Object) do |env, program|
        prevEnv = @dot
        @dot = env
        begin
          result = self.evaluate(program)
        ensure
          @dot = prevEnv
        end
        
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

      operator("tocode", "string", String) do |string|
        if string.value.size > 0
          Repr::num(string.value.ord)
        else
          raise "TOCODE: empty string"
        end
      end

      operator("fromcode", "num", Num) do |num|
        Repr::string(num.num.chr(Encoding::UTF_8))
      end
      

      operator("copy", "object", Object) do |object|
        object.copy
      end

      
      ## パース関連コマンド
      operator("token") do
        s = @dot["/"]["source"]

        s.parse_token
      end
        
      operator("fail", "message", Object) do |message|
        s = @dot['/']['source']
        line = s['line']
        column = s['column']
        
        raise Rule::ParseError.new(message, line, column)
      end

      command("choice", "children") do |children|
        -> { # local jump errorを解消するために、ここにlambdaを入れた。
          s = @dot["/"]["source"]
          state = s.copy_state
          errors = []

#          puts "choice called"
#          puts state
          
          children.each_key { |k, v|
#            p k, v
            begin
              s.set_state(state)
              res = self.evaluate(v)
#              puts "result : #{res}"
              return res
            rescue Rule::ParseError => e
              errors << e
            end
          }

          deepest = errors.max_by {|a| [a.line, a.column]}
          raise (deepest || Rule::ParseError.new("empty argument in choice"))
        }.call
      end

      operator("terminal", "string", String) do |string|
        s = @dot["/"]["source"]
        s.parse_terminal(string)
      end

      operator("many", "parser", Object) do |parser|
        i = 0
        result = Repr::store({})
        s = @dot['/']["source"]
        state = nil
        
        while true
          state = s.copy_state
          begin
            result[i.to_repr] = self.evaluate(parser)
            i += 1
          rescue Rule::ParseError
            s.set_state(state)
            break
          end
        end

        result
      end

      command("parsestring") do
        s = @dot["/"]["source"]
        s.parse_string
      end
    end

    def trace_log(feature, s)
      if @dot.exist('/').value &&
         @dot['/'].exist('verbose').value &&
         @dot['/']['verbose'] == 'on'.to_repr
        puts "-[EVAL: #{feature.inspect}]--------------------"
        puts s.inspect
        #        puts "[DOT] "
        #        puts @dot.inspect
      end
    end
    
    def eval_store(s)
      if s.exist("@").value
        feature = evaluate(s["@"])

        unless @commands.include?(feature.value)
          raise "EVALUATE2: #{feature.inspect} is not a valid feature name"
        end
        
        trace_log(feature, s)

        @commands[feature.value].call(s)
      else
        # 命令が書かれていなかった場合は，内側の要素を全て評価することとした．
        result = {}.to_repr

        s.each_key { |k, v|
#          puts "key: #{k.inspect}, value: #{v.inspect}"
          result[k] = evaluate(v)
        }

        result
      end
    end
    
    def evaluate(program)
      case program
      when Num, Bool, String, Function, Procedure
        program
      when Store;
        eval_store(program)
      else
        raise "EVALUATE: argument is not a program: #{program.inspect} of #{program.class}"
      end
    end

    def extend_scope(newenv, parent)
      oldenv = @dot
      newenv[".."] = parent

      unless newenv.exist("/".to_repr).value
        newenv["/"] = oldenv["/"]
      end

      @dot = newenv
      result = nil
      begin
        result = yield
      ensure
        @dot = oldenv
      end

      result
    end

    def show(p)
      return p.inspect
    end

    def debug_print
      p @callcount
      
    end
  end
end

