# coding: utf-8
# ストリームを定義する。
# ストリームは，単なるデータストアオブジェクトに幾つかのキーをもたせたものとして扱う．

require './repr'
require './rule'

module Garbanzo
  module Repr
    class Store
      def self.create_source(str)
        lines = Repr::store({})
        str.split("\n").each_with_index { |x, i|
          lines[i + 1] = x.to_repr
        }
          
        Repr::store({ "source".to_repr => str.to_repr,
                      "line".to_repr => 1.to_repr,
                      "column".to_repr => 1.to_repr,
                      "index".to_repr => 0.to_repr,
                      "token_called".to_repr => 0.to_repr,
                      "whole_lines".to_repr => lines })
      end

      def is_source
      end
      
      def source_vars
        if exist('source') and exist('line') and exist('column') and exist('index')
          return self['source'].value, self['index'].num,
                 self['line'].num, self['column'].num
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
          self['line']   = l.to_repr
          self['column'] = c.to_repr

          debug_log("ADVANCE")
        
          tok.to_repr
        end
      end

      def fail(msg)
        raise Rule::ParseError.new(msg.value, self['line'].num, self['column'].num)
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

      def regex_match
      end

      
      def copy_state
        s, i, l, c = source_vars
        return [s.to_repr, i.to_repr, l.to_repr, c.to_repr]
      end

      def set_state(array)
        debug_log("BACKTRACK")
        self['source'], self['index'], self['line'], self['column'] = array
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
