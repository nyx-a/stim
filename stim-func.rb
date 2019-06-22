
def prepare_dir *path
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

