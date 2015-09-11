# coding: utf-8
require './repr.rb'
require './lib.rb'


module Garbanzo
    # 評価するやつ。変数とか文脈とか何も考えていないので単純
  class Evaluator
    include Repr
    
    def initialize
      @dot = Store.new({})
    end

    def eval_add(left, right)
      Repr::num(evaluate(left).num + evaluate(right).num)
    end

    def eval_mult(left, right)
      Repr::num(evaluate(left).num * evaluate(right).num)      
    end

    def eval_equal(left, right)
      Repr::bool(evaluate(left).eql?(evaluate(right)))
    end

    def eval_notequal(left, right)
      Repr::bool(!evaluate(left).eql?(evaluate(right)))
    end
    
    def eval_print(value)
      result = evaluate(value)
      puts show(result)
      result
    end

    def eval_set(object, key, value)
      obj = evaluate(object)
      key = evaluate(key)
      val = evaluate(value)

      raise "SET: object is not a store #{obj}" unless obj.is_a? Store
      obj.table[key] = val
    end

    def eval_get(object, key)
      obj = evaluate(object)
      key = evaluate(key)
      
      raise "GET: object #{obj.inspect} is not a store #{inspect}" unless obj.is_a? Store
      result = obj.table[key]
      raise "GET: undefined key #{obj.inspect} for #{key.inspect}" unless result
      result
    end

    def eval_while(condition, body)
        cond, body = [condition, body]
        falseObj   = Bool.new(false)
        result = Bool.new(true)
        
        while evaluate(cond) != falseObj
          result = evaluate(body)
        end
        
        result
    end

    def eval_begin(body)
        Lib::each_list(body) { |child|
          evaluate(child)
        }
    end

    def eval_getenv
      @dot
    end

    def eval_setenv(env)
      @dot = evaluate(env)
    end

    def eval_call(func, args)
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
    
    def eval_store(s)
      puts "***: evaluating store object"
      feature = s["@"]

      return s if feature == nil

      feature = evaluate(feature)
      case feature.value
      when "add";      eval_add(s['left'], s['right'])
      when "mult";     eval_mult(s['left'], s['right'])
      when "equal";    eval_equal(s['left'], s['right'])
      when "notequal"; eval_notequal(s['left'], s['right'])
      when "print";    eval_print(s['value'])
      when "set";      eval_set(s['object'], s['key'], s['value'])
      when "get";      eval_get(s['object'], s['key'])
      when "while";    eval_while(s['condition'], s['body'])
      when "begin";    eval_begin(s['body'])
      when "getenv";   eval_getenv()
      when "setenv";   eval_setenv(s['env'])
      when "call";     eval_call(s['func'], s['args'])
      else
        raise "EVALUATE2: #{feature} is not a valid feature name"
      end
    end
    
    def evaluate(program)
      case program
      when Num, Bool, String, Function
        program
      when Store;    program # evaluate_store(program)
      when Add;      eval_add(program.left, program.right)
      when Mult;     eval_mult(program.left, program.right)
      when Equal;    eval_equal(program.left, program.right)
      when NotEqual; eval_notequal(program.left, program.right)
      when Print;    eval_print(program.value)
      when Set;      eval_set(program.object, program.key, program.value)
      when Get;      eval_get(program.object, program.key)
      when While;    eval_while(program.condition, program.body)
      when Begin;    eval_begin(program.body)
      when Dot;      eval_getenv()
      when SetEnv;   eval_setenv(program.env)
      when Call;     eval_call(program.func, program.args)
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
      # when Add
      #   "(#{show(p.left)} + #{show(p.right)})"
      # when Mult
      #   "(#{show(p.left)} * #{show(p.right)})"
      # when Equal
      #   "(#{show(p.left)} == #{show(p.right)})"
      # when NotEqual
      #   "(#{show(p.left)} != #{show(p.right)})"
      # when Print
      #   "print(#{show(p.value)})"
      # when Set
      #   "#{show(p.object)}/#{show(p.key)} = #{show(p.value)}"
      # when Get
      #   "#{show(p.object)}/#{show(p.key)}"
      # when While
      #   "while #{show(p.condition)} #{show(p.body)}"
      # when Begin
      #   "{\n" + show(p.body).gsub(/^/, '  ') + "}"
      # when Dot
      #   "."
      # when SetEnv
      #   "setenv #{show(p.env)}"
      # when Function
      #   "^{ #{show(p.body)} }"
      # when Call
      #   "#{show(p.func)}(#{show(p.args)})"
      else
        raise "SHOW: argument is not a repr: #{p.inspect}"
      end
    end
  end
end
