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
      
      def self.create_source(str)
        linum_colnum = linum_array(str)
          
        Repr::store({ "source".to_repr => str.to_repr,
                      "index".to_repr => 0.to_repr,
                      "token_called".to_repr => 0.to_repr,
                      "line_numbers".to_repr => linum_colnum })
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
        
        _, i, l, c = source_vars

        lines = self['whole_lines']

        if lines.exist(l).value
          printf("[%10s] %4d, %4d:%4d: %s\n", kind, i, l, c, lines[l])
          printf("[%10s] %4d, %4d:%4d:%s\n", kind, i, l, c, " " * c + "^")
          sleep 0.01
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
          
          if tok == "\n"
            l += 1
            c = 1
          else
            c += 1
          end

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
        s, i, l, c = source_vars
        return i.to_repr
      end

      def set_state(state)
        debug_log("BACKTRACK")
        self['index'] = state
      end

      def is_eof?
        return self['source'].value.length == self['index'].num
      end

      def one_of(string)
        t = parse_token

        string.value.each_char do |c|
          if t.value == c
            return t
          end
        end

        self.fail("expected one of #{string}".to_repr)
      end
    end
  end
end
