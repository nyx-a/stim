
def same_as o
  -> x { x === o }
end

module B
  module_function

  def peel! s
    s.replace (s =~ /#/ ? $` : s).strip
  end

  def shrink s
    s.strip.gsub(/\s+/, ' ')
  end

  def encoding_convert src, from:, to:
    e = Encoding::Converter.new(from, to)
    dst = String.new
    begin
      ret = e.primitive_convert(src, dst)
      case ret
      when :invalid_byte_sequence
        e.insert_output(e.primitive_errinfo[3].dump[1..-2])
        redo
      when :undefined_conversion
        c = e.primitive_errinfo[3].dup.force_encoding e.primitive_errinfo[1]
        e.insert_output('\x{%X:%s}' % [c.ord, c.encoding])
        redo
      when :incomplete_input
        e.insert_output(e.primitive_errinfo[3].dump[1..-2])
      when :finished
      end
      break
    end while nil
    return dst
  end

  def bdiff a, b
    ea = a.encoding
    eb = b.encoding
    a.force_encoding 'BINARY'
    b.force_encoding 'BINARY'
    r = a == b
    a.force_encoding ea
    b.force_encoding eb
    return r
  end

  def denull text
    text.gsub("\0", ' ')
  end

  def readablize digit
    digit.to_s.reverse.chars.each_slice(3).map(&:join).join(',').reverse
  end
end
