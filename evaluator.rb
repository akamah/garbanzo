# coding: utf-8
require './repr.rb'
require './lib.rb'
require './rule.rb'


module Garbanzo
  # 評価するやつ。変数とか文脈とか何も考えていないので単純
  class Evaluator
    include Repr

    attr_accessor :dot
    
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
          # oldenv = @dot
          # args[".."] = func.env # 環境を拡張
          
          # unless args.exist("/".to_repr).value
          #   args["/"] = oldenv["/"]
          # end
          
          # @dot = args
          # begin
          #   result = evaluate(func.body)
          # ensure
          #   @dot = oldenv            
          # end

        # result
          extend_scope(args, func.env) do
            evaluate(func.body)
          end
        when Procedure
          func.proc.call(args)
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
        s = @dot["/"]["source"]["source"]

        if s.value.size > 0
          c = Repr::string(s.value[0]) # 一文字切り出して
          @dot["/"]["source"]["source"] = Repr::string(s.value[1..-1]) # 更新して
          c # 返す
        else
          raise Rule::ParseError, "end of source".to_repr
        end
      end

      operator("fail", "message", Object) do |message|
        raise Rule::ParseError, message
      end

      command("choice", "children") do |children|
        -> { # local jump errorを解消するために、ここにlambdaを入れた。
          source_orig = @dot["/"]["source"]["source"].copy
          errors = []

          children.each_key { |k|
            begin
              @dot["/"]["source"]["source"] = source_orig.copy
              return self.evaluate(children[k])
            rescue Rule::ParseError => e
              rest = @dot["/"]["source"]["source"].value.length
              errors << "'#{e.message} rest: #{rest}'"
            end
          }

          raise Rule::ParseError, errors.join(', ')
        }.call
      end

      operator("terminal", "string", String) do |string|
        source = @dot["/"]["source"]["source"]
        if source.value.start_with?(string.value)
          @dot["/"]["source"]["source"] = source.value[string.value.length .. -1].to_repr
          string.copy
        else
          raise Rule::ParseError, string.value
        end
      end

      operator("many", "parser", Object) do |parser|
        i = 0
        result = Repr::store({})
        string = @dot['/']['source']['source']
        
        while true
          begin
            result[i.to_repr] = self.evaluate(parser)
            string = @dot['/']['source']['source']
            i += 1
          rescue Rule::ParseError
            @dot['/']['source']['source'] = string
            break
          end
        end

        result
      end

      command("parsestring") do
        source = @dot["/"]["source"]["source"]
        if source.value =~ /^"((?:[a-z\/@.$' ]|\n)*)"(.*)$/m
          @dot['/']['source']['source'] = $2.to_repr
          p $1
          $1.to_repr
        else
          raise Rule::ParseError, "string"
        end
      end
    end

    
    def eval_store(s)
      if s.exist("@").value
        feature = evaluate(s["@"])

        unless @commands.include?(feature.value)
          raise "EVALUATE2: #{feature.inspect} is not a valid feature name"
        end

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
      
      case p
      when Num
        p.num.to_s
      when Bool
        p.value.to_s
      when String
        p.value
      when Store
        "{" + p.table.map {|k, v|
          show(k)
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

