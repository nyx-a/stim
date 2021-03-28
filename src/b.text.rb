
module B

  extend self

  def table matrix
    longest = matrix.transpose.map do |column|
      column.map(&:to_s).map do |cell|
        (cell.respond_to?(:uncolorize) ? cell.uncolorize : cell).size
      end.max
    end
    matrix.map do |row|
      mold = (["%-*s"] * row.size).join ' '
      mold % longest.zip(row).flatten
    end.join "\n"
  end

  def tree o
    tree_a o2a o
  end

  def o2a o
    result = [ ]
    case o
    when Array
      for i in o
        case i
        when Array
          result.push o2a i
        when Hash
          result.concat o2a i
        else
          result.push i
        end
      end
    when Hash
      for k,v in o
        result.push k
        if v.respond_to? :each
          result.push o2a v
        else
          result.push [v]
        end
      end
    end
    return result
  end

  def tree_a o
    t = o.pop
    if t.is_a? Array
      beyond = left_head(tree_a(t), "   ")
      t = o.pop
    end
    tail = left_head(t, "└─ ", "   ")

    body = o.map do |i|
      if i.is_a? Array
        left_head tree_a(i), "│  "
      else
        left_head i, "├─ "
      end
    end
    (body + [tail, beyond].compact).join "\n"
  end

  def left_head str, first, later=nil
    later = first if !later
    str.to_s.gsub(/(?=\A)^/, first).gsub(/(?!\A)^/, later)
  end
end

