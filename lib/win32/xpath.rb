require 'ffi'

class File
  extend FFI::Library

  typedef :ulong, :dword

  ffi_lib 'kernel32'

  attach_function :GetFullPathNameW, [:pointer, :ulong, :pointer, :pointer], :ulong

  ffi_lib 'shlwapi'

  attach_function :PathIsRelativeW, [:buffer_in], :bool

  MAX_PATH = 260

  def self.expand_path2(path, dir=nil)
    path = path.dup
    path = path.to_path if path.respond_to?(:to_path)

    raise TypeError unless path.is_a?(String)

    if path.empty?
      if dir
        path = dir
      else
        return Dir.pwd
      end
    else
      if dir
        path = File.join(dir, path)
      end
    end

    wide_path = (path + "\0").encode('UTF-16LE')
    path_ptr = FFI::MemoryPointer.new(:char, wide_path.bytesize)
    path_ptr.put_bytes(0, wide_path)

    buffer = FFI::MemoryPointer.new(:char, MAX_PATH * 2)  # Wide chars are 2 bytes
    file_part = FFI::MemoryPointer.new(:pointer)

    result = GetFullPathNameW(path_ptr, MAX_PATH, buffer, file_part)

    if result == 0
      raise SystemCallError.new('GetFullPathNameW failed')
    end

    if result > MAX_PATH
      # Buffer was too small, need larger buffer
      buffer = FFI::MemoryPointer.new(:char, result * 2)
      result = GetFullPathNameW(path_ptr, result, buffer, file_part)
      raise SystemCallError.new('GetFullPathNameW failed on retry') if result == 0
    end

    # Read as UTF-16LE and convert back
    result_bytes = buffer.read_bytes(result * 2)
    result_bytes.force_encoding('UTF-16LE').encode('UTF-8').tr('\\', '/')
  end
end

if $0 == __FILE__
  p File.expand_path('.')
  p File.expand_path('~')
  p File.expand_path('foo')
end
