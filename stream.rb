# coding: utf-8
# ストリームを定義する。
# 入力はSource, 出力はSinkと名付ける。

require './repr'
require './rule'

module Garbanzo
  module Repr
    class Store
      def self.create_source(str)
        Repr::store({ "source".to_repr => str.to_repr,
                      "line".to_repr => 1.to_repr,
                      "column".to_repr => 1.to_repr,
                      "index".to_repr => 0.to_repr })
      end

      def is_source
      end
      
      def source_vars
        if exist('source') and exist('line') and exist('column')
          return self['source'].value, self['index'].num,
                 self['line'].num, self['column'].num
        else
          raise "this is not a source"
        end
      end
      
      def parse_token
        s, i, l, c = source_vars

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
        
        self.fail("beginning of string") if t.value != '"'

        while true
          t = parse_token
          return s.to_repr  if t.value == '"'

          s += t.value
        end
      end

      def copy_state
        s, i, l, c = source_vars
        return [s.to_repr, i.to_repr, l.to_repr, c.to_repr]
      end

      def set_state(array)
        puts array
        
        self['source'], self['index'], self['line'], self['column'] = array
      end
    end
  end
end
