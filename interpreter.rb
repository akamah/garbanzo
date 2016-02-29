# coding: utf-8
=begin
幾つかのプロトタイプに共通する事項をまとめる．

* コマンドライン引数の処理
* デバッグ/プロファイリングなどのサポート

=end


require 'stackprof'

require './repr.rb'
require './evaluator.rb'

module Garbanzo
  class Interpreter
    attr_reader :evaluator, :name
    
    def initialize(name)
      @name = name
      @evaluator = Evaluator.new(self.construct_root)
    end

    def construct_root
      puts "not implemented #construct_root"
      Repr::store({})
    end
    
    def execute(source)
      puts "not implemented #execute"
    end

    def show_parse_error(e)
      $stderr.puts "parse error, #{e.message}"
    end

    def show_general_error(e)
      $stderr.puts "some error, #{e.message}"
    end
    
    def start(args)
      source = File.open(args[0], "rb").read

      begin
        StackProf.run(mode: :cpu, out: "#{self.name}.dump") do
          execute(source)
        end
      rescue Rule::ParseError => e
        show_parse_error(e)
      rescue => e
        show_general_error(e)
      ensure
#        evaluator.debug_print
      end
    end
  end
end
