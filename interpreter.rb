# coding: utf-8
=begin
幾つかのプロトタイプに共通する事項をまとめる．

* コマンドライン引数の処理
* デバッグ/プロファイリングなどのサポート

=end


require 'optparse'
require 'readline'
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
      $stderr.puts e.backtrace.map{|x| "\tfrom #{x}" }
    end

    def show_general_error(e)
      $stderr.puts "some error, #{e.message}"
      $stderr.puts e.backtrace.map{|x| "\tfrom #{x}" }
    end
    
    def start(args)
      inter = false
      
      opt = OptionParser.new
      opt.on('-i', '--interactive') {|v| inter = true }

      opt.parse!(args)
      
      
      source = File.open(args[0], "rb").read

      begin
        StackProf.run(mode: :cpu, out: "#{self.name}.dump") do
          execute(source)
        end
      rescue Rule::ParseError => e
        show_parse_error(e)
        raise
      rescue => e
        show_general_error(e)
        raise
      end


      if inter
        self.interactive()
      else
        evaluator.debug_print
      end
    end

    def with_readline
      tty_save = `stty -g`.chomp

      begin
        yield
      rescue Interrupt
        system('stty', tty_save)
        exit
      end
    end
    
    def interactive
      with_readline do
        while s = Readline.readline("> ", true)
          begin
            s.chomp!

            result = self.execute(s)
            puts result.inspect

          rescue Rule::ParseError => e
            show_parse_error(e)
          rescue => e
            show_general_error(e)
          end
        end
      end
    end
  end
end
