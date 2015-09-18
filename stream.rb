# coding: utf-8
# ストリームを定義する。
# 入力はSource, 出力はSinkと名付ける。

require './repr'


module Garbanzo
  class Source
    def initialize(source)
      case source
      when String
        @source = StringSource.new(source)
      else
        raise "argument is not suitable for creating source"
      end
    end

    # 一文字を入力する。
    # 入力されるのは、内部表現としての文字
    def token
      @source.token
    end

    # ブロックを評価し、失敗した場合は状態を巻き戻す。
    def try
      @source.try
    end
  end

  class StringSource
    def initialize(source)
      @source  = source
      @indices = [0]
    end

    def token
      raise "STREAM INCONSISTENT: indices.length < 1" if @indices.length < 1
      
      if @indices.first < @source.length
        t = @source[@indices.first]
        @indices[0] += 1
        return Repr::String.new(t)
      else
        return Repr::Bool.new(false)
      end
    end

    def try
      a.unshift(a.first)
    end
  end
end
