# coding: utf-8
# ストリームを定義する。
# ストリームは，単なるデータストアオブジェクトに幾つかのキーをもたせたものとして扱う．

require './repr'
require './rule'
require './evaluator.rb'

module Garbanzo
  module Repr
    class Store
      def self.linum_array(str)
        arr = Array.new(str.size + 1)

        l, c = 1, 1
        0.upto(str.size) do |i|
          arr[i] = [l.to_repr, c.to_repr]

          if str[i] == "\n"
            l += 1
            c = 1
          else
            c += 1
          end
        end

        arr
      end

      def install_source(str)
        self['source'] = str.to_repr
        self['index'] = 0.to_repr
        self['token_called'] = 0.to_repr
        self['line_numbers'] = Store.linum_array(str)
        self
      end
      
      def self.create_source(str)
        store = Repr::store({})
        store.install_source(str)
        store
      end

      def is_source
      end

      def index
        self['index']        
      end
      
      def line
        linums = self['line_numbers']
        linums[index.num][0]        
      end

      def column
        linums = self['line_numbers']
        linums[index.num][1]        
      end
      
      def source_vars
        if exist('source') and exist('index')
          return self['source'].value, self.index.num,
                 self.line.num, self.column.num
        else
          raise "this is not a source"
        end
      end

      def debug_log(kind)
        return
        s, i, l, c = source_vars 

        return unless i % 100 == 0

        lines = self['source'].value.split("\n")

        if lines[l]
          printf("[%10s] %4d, %4d:%4d: %s\n", kind, i, l, c, lines[l])
          printf("[%10s] %4d, %4d:%4d:%s\n", kind, i, l, c, " " * c + "^")
          sleep 0.001
        end
      end
      
      def parse_token
        s, i, l, c = source_vars

        self['token_called'] = (self['token_called'].num + 1).to_repr
        
        if i >= s.length
          self.fail("there is no character left".to_repr)
        else
          tok = s[i]
          i += 1

          self['index']  = i.to_repr

          debug_log("ADVANCE")
        
          tok.to_repr
        end
      end

      def fail(msg)
        raise Rule::ParseError.new(msg.value, self.line.num, self.column.num)
      end

      def parse_terminal(str)
        str.value.length.times do |k|
          t = parse_token

          if t.value != str.value[k]
            fail(str.to_repr)
          end
        end

        str.to_repr
      end

      def parse_string
        t = parse_token
        s = ""
        
        self.fail("beginning of string".to_repr) if t.value != '"'

        while true
          t = parse_token
#          $stderr.puts "escape"
            
          return s.to_repr  if t.value == '"'

          if t.value == "\\"
            t2 = parse_token

            case t2.value
            when 'n'
              s += "\n"
            else
              self.fail("unknown escape sequence: #{t2.value}".to_repr)
            end
            
          else
            s += t.value
          end
        end
      end

      def regex_match(re)
        offset = self['index'].num
        str = self['source'].value

        if md = re.match(str[offset..-1])
          newoffset = offset + md.end(0) # マッチした部分の全体を表すオフセット，らしい．
          self['index'] = newoffset.to_repr

#          p md.to_a
          md[0].to_repr
        else
          self.fail(('regexp %s doesnot match' % re.to_s).to_repr)
        end
      end

      
      def copy_state
        return self.index
      end

      def set_state(state)
        debug_log("BACKTRACK")
        self['index'] = state
      end

      def is_eof?
        return self['source'].value.length == self['index'].num
      end

      def satisfy?(message = "doesn't satisfy")
        t = parse_token

        if yield t.value
          return t
        else
          self.fail(message)
        end
      end

      def one_of(string)
        self.satisfy?("expected one of #{string}".to_repr) {|c|
          string.value.index(c) != nil
        }
      end

      def none_of(string)
        self.satisfy?("expected none of #{string}".to_repr) {|c|
          string.value.index(c) == nil
        }
      end
    end
  end
end
