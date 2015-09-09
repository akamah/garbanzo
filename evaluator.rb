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

    def evaluate(program)
      case program
      when Num, Bool, String
        program
      when Store
        program
      when Add
        Num.new(evaluate(program.left).num + evaluate(program.right).num)
      when Mult
        Num.new(evaluate(program.left).num * evaluate(program.right).num)
      when Equal
        Bool.new(evaluate(program.left).eql?(evaluate(program.right)))
      when NotEqual
        Bool.new(!evaluate(program.left).eql?(evaluate(program.right)))
      when Print
        result = evaluate(program.value)
        puts show(result)
        result
      when Set
        obj = evaluate(program.object)
        key = evaluate(program.key)
        val = evaluate(program.value)

        raise "SET: object is not a store #{obj}" unless obj.is_a? Store
        obj.table[key] = val
      when Get
        obj = evaluate(program.object)
        key = evaluate(program.key)
        
        raise "GET: object #{obj.inspect} is not a store #{program.inspect}" unless obj.is_a? Store
        obj.table[key]
      when While
        cond, body = [program.condition, program.body]
        falseObj   = Bool.new(false)
        result = Bool.new(true)
        
        while evaluate(cond) != falseObj
          result = evaluate(body)
        end
        
        result
      when Begin
        Lib::each_list(program.body) { |child|
          evaluate(child)
        }
      when Dot
        @dot
      when SetEnv
        @dot = evaluate(program.env)
      when Function
        program
      when Call
        f = evaluate(program.func)
        a = evaluate(program.args)
        
        raise "EVALUATE: callee is not a function: #{program.func}" unless f.is_a? Function
        raise "EVALUATE: arguments is not a data store: #{program.args}" unless a.is_a? Store

        oldenv = @dot
        a.table["..".to_repr] = f.env # 環境を拡張

        @dot = a
        result = evaluate(f.body)
        @dot = oldenv

        result
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
      when Add
        "(#{show(p.left)} + #{show(p.right)})"
      when Mult
        "(#{show(p.left)} * #{show(p.right)})"
      when Equal
        "(#{show(p.left)} == #{show(p.right)})"
      when NotEqual
        "(#{show(p.left)} != #{show(p.right)})"
      when Print
        "print(#{show(p.value)})"
      when Set
        "#{show(p.object)}/#{show(p.key)} = #{show(p.value)}"
      when Get
        "#{show(p.object)}/#{show(p.key)}"
      when While
        "while #{show(p.condition)} #{show(p.body)}"
      when Begin
        "{\n" + show(p.body).gsub(/^/, '  ') + "}"
      when Dot
        "."
      when SetEnv
        "setenv #{show(p.env)}"
      when Function
        "^{ #{show(p.body)} }"
      when Call
        "#{show(p.func)}(#{p.env})"
      else
        raise "SHOW: argument is not a repr: #{p}"
      end
    end
  end
end
