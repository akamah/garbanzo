# coding: utf-8

# コマンドが多くなってきたので分離したい。
# とりあえず、ここに書いておいて、さらに増えたらカテゴリごとに分けよう。

require 'singleton'
require './repr.rb'

# 現状、repr.rbでコマンドの定義して、evaluator.rbで動作を記述しているが、これは明らかな無駄である。
# そのため、Evaluatorに標準のコマンドをインストールする作業をここで行う。
# そもそも、evaluatorは複数存在し得るのに、コマンド生成関数は1つしか存在しないのでなんか不整合。
# 解決策：標準のコマンドを実行するクロージャをハッシュで持っておくかぁ。
# コマンドの定義と、実行方法さえ決めてやればよい。

module Garbanzo
  class Command
    include Singleton

    def initialize
      @commands = {}
    end

    def install_standard_commands(evaluator)
      @commands.each do |k, v|
        evaluator.install(k) { |*args|
          v.call(evaluator, *args)
        }
      end
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

    operator("add", "left", Num, "right", Num) do |e, left, right|
      Repr::num(left.num + right.num)      
    end
    
  end
end



