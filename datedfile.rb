
require_relative 'organ.rb'

module B
  # for namespace
end

class B::DatedFile < B::Organ
  PATTERN = %r{
    \A
    (?<y>\d{4}) (?<m>\d{2}) (?<d>\d{2})
    \-
    (?<hour>\d{2}) (?<min>\d{2})
    \-
    (?<n>\d+)
    \z
  }x

  def self.parse string
    if string =~ %r`(.*)/`
      dir  = $1.empty? ? '/' : $1
      file = $'
    else
      dir  = nil
      file = string
    end

    bamboo = file.split %r`(?<!\A)\.(?!\z)`
    if bamboo.size >= 2
      idx = bamboo.rindex{ |i| PATTERN.match i }
      if idx!=nil and idx!=0
        bamboo.slice! idx
        date = Time.new $~[:y], $~[:m], $~[:d], $~[:hour], $~[:min]
        serial = $~[:n]
      end
    end
    if bamboo.size >= 2
      ext = bamboo.pop
    end
    base = bamboo.join '.'

    return new(
      dir:    dir,
      name:   base,
      ext:    ext,
      date:   date,
      serial: serial,
    )
  end

  attr_accessor :dir
  attr_accessor :name
  attr_accessor :ext
  attr_accessor :date
  attr_accessor :serial

  def timestamp date:nil, serial:nil
    d = date   || @date   || Time.now
    s = serial || @serial || 0
    d.strftime "%Y%m%d-%H%M-#{s}"
  end

  def filename date:nil, serial:nil
    a = [@name, timestamp(date:date, serial:serial)]
    unless @ext.nil?
      a.push @ext
    end
    a.join '.'
  end

  def path date:nil, serial:nil
    f = filename date:date, serial:serial
    if @dir.nil?
      f
    else
      File.join @dir, f
    end
  end

  def fullpath date:nil, serial:nil
    File.expand_path path date:date, serial:serial
  end

  def exist?
    File.exists? fullpath
  end

  def delete
    File.delete fullpath
  end

  def openfile date:nil, serial:nil
    @date   = date   || Time.now
    @serial = serial || 0
    begin
      @fileout = File.open fullpath, 'wbx'
    rescue Errno::EEXIST
      @serial += 1
      retry
    end
    return @fileout
  end

  def closefile
    size = @fileout.size
    @fileout.close
    self.delete if size.zero?
  end

  def save contents, date:nil, serial:nil
    if contents.nil? or contents.empty?
      return nil
    end
    fo = openfile date:date, serial:serial
    fo << contents
    fo.close
    return fullpath
  end

  def load
    if self.exist?
      File.open(fullpath, 'rb').read
    else
      nil
    end
  end

  def inspect_h
    super.merge(
      'filename()'  => filename.inspect,
      'path()'      => path.inspect,
      'fullpath()'  => fullpath.inspect,
    )
  end
end
