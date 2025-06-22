require 'ffi'

class File
  extend FFI::Library
  ffi_lib :kernel32
  typedef :ulong, :dword

  attach_function :GetCurrentDirectory, :GetCurrentDirectoryA, [:dword, :pointer], :dword
  attach_function :GetFullPathName, :GetFullPathNameA, [:string, :dword, :pointer, :pointer], :dword

  MAX_PATH = 256

  def self.expand_path(path, dir=nil)
    path = path.to_path if path.respond_to?(:to_path) # Pathname objects, etc

    buffer = FFI::MemoryPointer.new(MAX_PATH)

    if path.empty?
      if GetCurrentDirectory(buffer.size, buffer) == 0
        raise SystemCallError.new('GetCurrentDirectory')
      end
      string = buffer.read_string.tr('\\', '/')
      return string
    end

    if GetFullPathName(path, MAX_PATH, buffer, nil) == 0
      raise SystemCallError.new('GetFullPathName')
    end

    buffer.read_string.tr('\\', '/')
  end
end

=begin
if $0 == __FILE__
  p File.expand_path('.')
  p File.expand_path('foo')
  p File.expand_path('foo/bar.txt')
end
=end
