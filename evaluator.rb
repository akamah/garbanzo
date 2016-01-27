# coding: utf-8
require './repr.rb'
require './lib.rb'
require './rule.rb'
require './stream.rb'

module Garbanzo
  # analyzeのためのやつ
  class Repr::GarbObject
    private
    # 環境を受け取ることができる```proc'''を返す．
    def analyze
      proc { self }
    end

    public
    def analyzed
      @analyzed ||= analyze
      return @analyzed
    end

    def refresh_analyzed
      @analyzed = nil
    end
  end

  class Repr::Store
    @@commands = {}
    @@callcount = Hash.new { 0 }
    
    def self.command(commandname, *arguments)
      @@commands[commandname] = lambda { |store|
        @@callcount[commandname] += 1
        yield(*arguments.map {|aname| store.get_raw(aname) })
      }
    end

    def self.debug_print
      p @@callcount
    end
    
    def self.operator(opname, *args)
      raise "invalid argument list" if args.length % 2 == 1

      arglist = args.each_slice(2).map {|name, type|
        [name, type]
      }
      
      @@commands[opname] = lambda { |store|
        proc { |env|
          @@callcount[opname] += 1
          param = arglist.map {|name_type|
            e = store.evaluate_sub_expr(name_type[0], env)
            unless e.is_a? name_type[1]
              raise "operator `#{opname}' type mismatch: #{name_type}, not #{e.class}"
            end
            e
          }
          yield(*param)
        }        
      }
    end

    # operator and command definiton
    ## operators
    ### arithmetic and logical operators
    operator("add", "left", Repr::Num, "right", Repr::Num) do |left, right|
      Repr::num(left.num + right.num)
    end
    
    operator("sub", "left", Repr::Num, "right", Repr::Num) do |left, right|
      Repr::num(left.num - right.num)
    end
    
    operator("mult", "left", Repr::Num, "right", Repr::Num) do |left, right|
      Repr::num(left.num * right.num)     
    end

    operator("div", "left", Repr::Num, "right", Repr::Num) do |left, right|
      Repr::num(left.num / right.num)      
    end

    operator("mod", "left", Repr::Num, "right", Repr::Num) do |left, right|
      Repr::num(left.num % right.num)     
    end

    operator("equal", "left", Repr::GarbObject, "right", Repr::GarbObject) do |left, right|
      Repr::bool(left == right)
    end

    operator("notequal", "left", Repr::GarbObject, "right", Repr::GarbObject) do |left, right|
      Repr::bool(left != right)
    end

    operator("lessthan", "left", Repr::Num, "right", Repr::Num) do |left, right|
      Repr::bool(left.num < right.num)
    end
    
    operator("and", "left", Repr::Bool, "right", Repr::Bool) do |left, right|
      Repr::bool(left.value && right.value)
    end
    
    operator("or", "left", Repr::Bool, "right", Repr::Bool) do |left, right|
      Repr::bool(left.value || right.value)
    end
    
    operator("not", "left", Repr::Bool, "right", Repr::Bool) do |value|
      Repr::bool(!value.value)
    end

    ### datastore operators
    operator("set", "object", Repr::Store, "key", Repr::GarbObject, "value", Repr::GarbObject) do |object, key, value|
      object[key] = value
    end

    operator("get", "object", Repr::Store, "key", Repr::GarbObject) do |object, key|
      result = object[key]
      raise "GET: undefined key #{object.inspect} for #{key.inspect}" unless result
      result
    end

    operator("size", "object", Repr::Store) do |object|
      object.size
    end

    operator("remove", "object", Repr::Store, "key", Repr::GarbObject) do |object, key|
      object.remove(key)
    end
    
    operator("exist", "object", Repr::Store, "key", Repr::GarbObject) do |object, key|
      object.exist(key)
    end

    operator("getprevkey", "object", Repr::Store, "origin", Repr::GarbObject) do |object, key|
      object.get_prev_key(key)
    end

    operator("getnextkey", "object", Repr::Store, "origin", Repr::GarbObject) do |object, key|
      object.get_next_key(key)
    end

    operator("insertprev", "object", Repr::Store, "origin", Repr::GarbObject,
             "key", Repr::GarbObject, "value", Repr::GarbObject) do |object, origin, key, value|
      object.insert_prev(origin, key, value)
    end

    operator("insertnext", "object", Repr::Store, "origin", Repr::GarbObject,
             "key", Repr::GarbObject, "value", Repr::GarbObject) do |object, origin, key, value|
      object.insert_next(origin, key, value)
    end

    operator("firstkey", "object", Repr::Store) do |object|
      object.first_key
    end
    
    operator("lastkey", "object", Repr::Store) do |object|
      object.last_key
    end

    ### string operators
    operator("append", "left", Repr::String, "right", Repr::String) do |left, right|
      Repr::string(left.value + right.value)
    end

    operator("charat", "string", Repr::String, "index", Repr::Num) do |string, index|
      if index.num < string.value.length
        Repr::string(string.value[index.num])
      else
        raise "CHARAT: index out of string's length"
      end
    end

    operator("length", "string", Repr::String) do |string|
      Repr::num(string.value.length)
    end

    operator("tocode", "string", Repr::String) do |string|
      if string.value.size > 0
        Repr::num(string.value.ord)
      else
        raise "TOCODE: empty string"
      end
    end

    operator("fromcode", "num", Repr::Num) do |num|
      Repr::string(num.num.chr(Encoding::UTF_8))
    end
    
    
    ### parsing operators
    operator("token") do
      s = @dot["/"]["source"]

      s.parse_token
    end
    
    operator("fail", "message", Repr::GarbObject) do |message|
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
            res = env.evaluate(v)
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

    operator("terminal", "string", Repr::String) do |string|
      s = @dot["/"]["source"]
      s.parse_terminal(string)
    end

    operator("many", "parser", Repr::GarbObject) do |parser|
      i = 0
      result = Repr::store({})
      s = @dot['/']["source"]
      state = nil
      
      while true
        state = s.copy_state
        begin
          result[i.to_repr] = env.evaluate(parser)
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

    operator("oneof", "string", Repr::String) do |string|
      source = @dot["/"]["source"]
      source.one_of(string)
    end

    ### miscellaneous operators
    operator("print", "value", Repr::GarbObject) do |value|
      puts show(value)
      value
    end

    operator("isdatastore", "value", Repr::GarbObject) do |value|
      (value.is_a? Repr::Store).to_repr
    end

    operator("copy", "object", Repr::GarbObject) do |object|
      object.copy
    end

    
    ### operators cooperate with environment
    operator("call", "func", Repr::Callable, "args", Repr::Store) do |func, args|
      case func
      when Function
        extend_scope(args, func.env) do
          env.evaluate(func.body)
        end
      when Procedure
        extend_scope(args, {}.to_repr) do
          func.proc.call(self, args)
        end
      else
        raise "EVALUATE: callee is not a function: #{func}" unless f.is_a? Function
      end
    end

    operator("eval", "env", Repr::Store, "program", Repr::GarbObject) do |env, program|
      prevEnv = @dot
      @dot = env
      begin
        result = .evaluate(program)
      ensure
        @dot = prevEnv
      end
      
      result
    end

    operator("getenv") do
      @dot
    end

    operator("setenv", "env", Repr::Store) do |env|
      @dot = env
    end

    ## commands
    ### control flow
    command("while", "condition", "body") do |condition, body|
      falseObj = Repr::Bool.new(false)
      result = Repr::Bool.new(true)
      
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

    ### object allocation
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

    command("lambda", "env", "body") do |env, body|
      Repr::function(evaluate(env), body)
    end
    
    def evaluate_sub_expr(key, env)
      self.get_raw(key).analyzed.call(env)
    end

    private
    def analyze_non_command
      proc {|env|
        result = {}.to_repr

        self.each_key {|k, v|
          result[k] = evaluate_sub_expr(k, env)
        }
      }
    end
    
    def analyze
      comname = self.get_raw('@')

      if comname == nil
        analyze_non_command
      end

      feature = @@commands[comname.value]

      if feature == nil
        raise "undefined command #{comname}"
      end

      return feature.call(self)
    end

    public
  end

  # 評価するやつ。変数とか文脈とか何も考えていないので単純
  class Evaluator
    include Repr

    attr_accessor :dot
    
    def initialize(root = Repr::store({}))
      @dot = root
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
    
    def evaluate(program)
      program.analyzed.call(self)
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
      Repr::Store.debug_print
    end
  end
end

