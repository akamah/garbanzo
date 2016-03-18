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
        proc { |env|
          yield(*arguments.map {|aname| store.get_raw(aname) }, env)
        }
      }
    end

    def self.debug_print
      $stderr.puts @@callcount
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
              raise "operator `#{opname}' type mismatch: #{name_type}, not #{e}"
            end
            e
          }
          yield(*param, env)
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
    operator("token") do |env|
      s = env.dot["/"]["source"]

      s.parse_token
    end
    
    operator("fail", "message", Repr::GarbObject) do |message, env|
      s = env.dot['/']['source']
      line = s.line
      column = s.column
      
      ex = Rule::ParseError.new(message, line, column)
      ex.set_backtrace("fail")

      raise ex
    end

    def self.deepest_error(key_exception_table)
      key, deepest = key_exception_table.max_by {|k, e| [e.line, e.column]}

      if key
        deepest.backtrace.push key.value

        return deepest
      else
        return Rule::ParseError.new("empty choice")
      end
    end
    
    
    command("choice", "children") do |children, evaluator|
      s = evaluator.dot["/"]["source"]
      state = s.copy_state
      errors = {}

      result = nil
      #          puts "choice called"
      #          puts state
      
      children.each_key { |k, v|
        #            p k, v
        begin
          s.set_state(state)
          result = evaluator.evaluate(v)
          #              puts "result : #{res}"
          break
        rescue Rule::ParseError => e
          errors[k] = e
        end
      }

      if result
        result
      else
        raise deepest_error(errors)
      end
    end

    operator("terminal", "string", Repr::String) do |string, evaluator|
      s = evaluator.dot["/"]["source"]
      s.parse_terminal(string)
    end

    operator("many", "parser", Repr::GarbObject) do |parser, evaluator|
      i = 0
      result = Repr::store({})
      s = evaluator.dot['/']["source"]
      state = s.copy_state

      begin
        while true
          result[i.to_repr] = evaluator.evaluate(parser)
          i += 1
          state = s.copy_state # すくなくとも，ここまでは成功した，という意味でのパーサの状態
        end
      rescue Rule::ParseError # 失敗した時，直前までの成功のところまで巻き戻す．
        s.set_state(state)
      end

      result
    end

    command("parsestring") do |evaluator|
      s = evaluator.dot["/"]["source"]
      s.parse_string
    end

    operator("oneof", "string", Repr::String) do |string, evaluator|
      source = evaluator.dot["/"]["source"]
      source.one_of(string)
    end

    operator("noneof", "string", Repr::String) do |string, evaluator|
      source = evaluator.dot["/"]["source"]
      source.none_of(string)
    end

    command("regex") do |regex, evaluator|
      unless regex.is_a? Repr::String
        raise "regex command requires `regex' as String"
      end

      re = Regexp.new("^" + regex.value, Regexp::MULTILINE)

      source.regex_match(re)
    end

    def self.cached_choice(children, cache, evaluator)
      s = evaluator.dot["/"]["source"]
      pos = s.index
      state = s.copy_state
      errors = {}

      # キャッシュのテーブル自体が作られてなかったら
      cache[pos] = {}.to_repr unless cache.exist(pos).value == true
      
      children.each_key {|k, v|
#        $stderr.puts "#{children.size.inspect}, #{s.line.inspect}, #{k.inspect}"
        
        # 各自を試す．まず，キャッシュに入っているかどうか．
        if cache[pos].exist(k).value
          entry = cache[pos][k] # キャッシュデータが出てくる．

          if entry['status'].value == 'success' # 成功していた場合
            result = entry['value']
            s.set_state(entry['next'])
            return result
          elsif entry['status'].value == 'fail' # 失敗していた場合
            errors[k] = entry['value']
            next
          else
            raise "cannot reach!"
          end
        else # キャッシュに当たんなかった．仕方ないので実際に試す．
#          $stderr.puts ["miss!", k, pos.num].inspect

          begin
            s.set_state(state)
            res = evaluator.evaluate(v)

            # キャッシュに貯める
            cache[pos][k] = Repr::store({ "status".to_repr => "success".to_repr,
                                          "value".to_repr => res,
                                          "next".to_repr => s.copy_state })

#            $stderr.puts "success!"
            return res
          rescue Rule::ParseError => e
            errors[k] = e

            # 失敗情報をキャッシュに貯める
            cache[pos][k] = Repr::store({ "status".to_repr => "fail".to_repr, "value".to_repr => e })
#            $stderr.puts "failure!"
          end
        end
      }

      raise deepest_error(errors)
    end
    
    def self.precrule(table, prec, evaluator)
      rules = []
      # まず，tableから優先度がprec以下のルールを抽出
      table.each_key {|k, v|
        if k.value.start_with?("@") # 特殊エントリーなので飛ばす
          next
        end
        
        unless v.is_a?(Repr::Store) && v.exist('prec').value && v.exist('parser').value
          raise "precrule: invalid table entry: #{v}"
        end

        p = v.get_raw('prec').num
        if p <= prec.num
          rules << [k, v]
        end
      }

      # 次に，さっきのやつをソート
      rules.sort_by! {|kv|
        -kv[1].get_raw('prec').num
      }

      children = {}.to_repr

      # 最後に，データストア形式に直す
      rules.each do |kv|
        children[kv[0]] = kv[1]['parser']
      end
      
      # 順番に試す．
      cached_choice(children, table['@cache'], evaluator)
    end
    
    operator("precrule", "table", Repr::Store, "prec", Repr::Num) do |table, prec, evaluator|
      precrule(table, prec, evaluator)
    end

    operator("withcache", "table", Repr::Store) do |table, evaluator|
      cachekey = "@cache"
      needclear = table.exist(cachekey).value == false # 元々キャッシュがなかったのなら，クリアする必要がある．
      prec = 1000.to_repr
      
      if needclear
#        $stderr.puts "allocate cache"
        
        table[cachekey] = {}.to_repr
        begin
          precrule(table, prec, evaluator)
        ensure
#          $stderr.puts "dispose cache"
#          $stderr.puts table[cachekey].inspect
          
          table.remove(cachekey)
        end
      else
        precrule(table, prec, evaluator)        
      end
    end
    
    ### miscellaneous operators
    operator("print", "value", Repr::GarbObject) do |value, evaluator|
      puts evaluator.show(value)
      value
    end

    operator("isdatastore", "value", Repr::GarbObject) do |value|
      (value.is_a? Repr::Store).to_repr
    end

    operator("copy", "object", Repr::GarbObject) do |object|
      object.copy
    end

    
    ### operators cooperate with environment
    operator("call", "func", Repr::Callable, "args", Repr::Store) do |func, args, evaluator|
      case func
      when Repr::Function
        evaluator.extend_scope(args, func.env) do
          evaluator.evaluate(func.body)
        end
      when Repr::Procedure
        evaluator.extend_scope(args, {}.to_repr) do
          func.procedure.call(evaluator, args)
        end
      else
        raise "EVALUATE: callee is not a function: #{func}" unless f.is_a? Repr::Function
      end
    end

    operator("eval", "env", Repr::Store, "program", Repr::GarbObject) do |env, program, evaluator|
      prevEnv = evaluator.dot
      evaluator.dot = env
      begin
        result = evaluator.evaluate(program)
      ensure
        evaluator.dot = prevEnv
      end
      
      result
    end

    operator("getenv") do |evaluator|
      evaluator.dot
    end

    operator("setenv", "env", Repr::Store) do |env, evaluator|
      evaluator.dot = env
    end

    ## commands
    ### control flow
    command("while", "condition", "body") do |condition, body, evaluator|
      falseObj = Repr::Bool.new(false)
      result = Repr::Bool.new(true)
      
      while evaluator.evaluate(condition) != falseObj
        result = evaluator.evaluate(body)
      end
      
      result
    end

    command("if", "condition", "consequence", "alternative") do |condition, consequence, alternative, evaluator|
      if evaluator.evaluate(condition) != false.to_repr
        evaluator.evaluate(consequence)
      else
        evaluator.evaluate(alternative)
      end
    end

        
    command("begin", "body") do |body, evaluator|
      result = false.to_repr

      body.each_key do |k, v|
        result = evaluator.evaluate(v)
      end

      result
    end

    # スコープを導入するコマンド。
    command("scope", "body") do |body, evaluator|
      emptyenv = {}.to_repr
      evaluator.extend_scope(emptyenv, evaluator.dot) do
        result = false.to_repr

        body.each_key do |k, v|
          result = evaluator.evaluate(v)
        end

        result
      end
    end

    ### object allocation
    command("datastore", "object") do |object, evaluator|
      store = Repr::store({})
      
      object.each_key { |k|
        store[k] = evaluator.evaluate(object[k])
      }
      store
    end

    def self.quasiquote(evaluator, object, level)
      if object.is_a? Repr::Store
        exists = object.exist('@').value
        
        if exists && object['@'] == 'quasiquote'.to_repr
          Repr::quasiquote(self.quasiquote(evaluator, object['value'], level + 1))
        elsif exists && object['@'] == 'unquote'.to_repr
          if level == 1
            evaluator.evaluate(object['value'])
          elsif level > 1
            {"@" => "unquote",
             "value" => self.quasiquote(evaluator, object['value'], level - 1)
            }.to_repr
          else
            raise "unquote outside quasiquote"
          end
        else
          result = {}.to_repr

          object.each_key do |k, v|
            result[k] = self.quasiquote(evaluator, v, level)
          end

          result
        end
      else
        object # 単純にクオートする
      end
    end
    
    command("quasiquote", "value") do |object, evaluator|
#      $stderr.puts "quasiquote: #{object.inspect}"
      res = quasiquote(evaluator, object, 1)
#      $stderr.puts "result: #{res.inspect}"
      res
    end
    
    command("quote", "value") do |value, evaluator|
      value
    end

    command("lambda", "env", "body") do |env, body, evaluator|
      Repr::function(evaluator.evaluate(env), body)
    end
    
    def evaluate_sub_expr(key, env)
      expr = self.get_raw(key).analyzed.call(env)
      expr
    end

    private
    def analyze_non_command
      proc {|env|
        result = {}.to_repr

        self.each_key {|k, v|
          result[k] = self[k].analyzed.call(env)
        }

        result
      }
    end
    
    def analyze
      comname = self.get_raw('@')

      if comname == nil
        return analyze_non_command
      end

      unless comname.is_a? Repr::String
        raise "#{comname.inspect} is not a Repr::String, in #{self.inspect}"
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
    attr_accessor :stacktrace
    
    def initialize(root = Repr::store({}))
      @dot = root
      @stacktrace = []
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
      # トレース用に，どこをどういった順番で評価したかを保持しておく．
      # 表示するときは，これらをうまく加工する．
      @stacktrace.push program
      begin
        program.analyzed.call(self)
      ensure
        @stacktrace.pop
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

    def trace_string(prog)
      case prog
      when Repr::Store
        if prog.exists?('@').value
          prog['@'].inspect
        else
          "datastore"
        end
      else
        prog.inspect
      end
    end
    
    def get_stack_trace_array
      @stacktrace.map { |prog|
        trace_string(prog)
      }
    end
    
    def show(p)
      return p.inspect
    end

    def debug_print
      Repr::Store.debug_print
    end
  end
end

