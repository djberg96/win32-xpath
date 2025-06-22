require 'ffi'

class File
  extend FFI::Library
  ffi_lib :kernel32
  typedef :ulong, :dword

  attach_function :GetFullPathName, :GetFullPathNameA, [:string, :dword, :pointer, :pointer], :dword
  MAX_PATH = 256

  def self.expand_path(path, dir=nil)
    buffer = FFI::MemoryPointer.new(MAX_PATH)
    file_part = FFI::MemoryPointer.new(64)

    if GetFullPathName(path, MAX_PATH, buffer, file_part) == 0
      raise SystemCallError.new('GetFullPathName')
    end

    p file_part.read_pointer.read_string

    buffer.read_string.tr('\\', '/')
  end
end

if $0 == __FILE__
  p File.expand_path('.')
  p File.expand_path('foo')
  p File.expand_path('foo/bar.txt')
end
