
require 'fileutils'

class Stimming
  def self.prepare_dir *path
    path = File.expand_path File.join(*path)
    if File.exist? path
      if File.directory? path
        if File.writable? path
          # ok
        else
          raise "not writable => '#{path}'"
        end
      else
        raise "not directory => '#{path}'"
      end
    else
      FileUtils.mkpath path
    end
    return path
  end

  def self.ejpath *p
    File.expand_path File.join(*p)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  DoubleBracket = %r`\(\( ( (?~\)\)) ) \)\)`x

  def self.tokenize string
    string.split('|').map(&:strip).sort.freeze
  end

  def self.scan_tokens string
    return [ ] if string.nil?
    string.scan(DoubleBracket).flatten.map(&method(:tokenize)).uniq
  end

  def self.tidyup_path command
    command = command.strip
    if command =~ %r`\A~`
      File.expand_path command
    elsif command =~ %r`\A[.#{File::SEPARATOR}]`
      command
    else
      '.' + File::SEPARATOR + command
    end
  end

  def self.raise_if_invalid_directory dir
    raise InvalidDirectory, dir unless File.directory? dir
  end

  def self.raise_if_invalid_command dir, cmd
    fp = if cmd =~ %r`\A\s*#{File::SEPARATOR}`
           cmd
         else
           File.join dir, cmd
         end
    unless File.file? fp and File.executable? fp
      raise InvalidCommand, fp
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  class Error < StandardError
    CLICHE = 'something wrong at Stimming'
    def message
      "#{self.class.const_get :CLICHE}: `#{super}`"
    end
  end

  class SlightError < Error
    CLICHE = 'slite error'
  end

  class InvalidDirectory < Error
    CLICHE = 'invalid directory'
  end

  class InvalidCommand < Error
    CLICHE = 'invalid command'
  end

  class InvalidTrigger < Error
    CLICHE = 'invalid trigger'
  end

  class TriggerDuplicated < Error
    CLICHE = 'trigger duplicated'
  end

  class NoSuchNode < Error
    CLICHE = 'no such node'
  end
end
