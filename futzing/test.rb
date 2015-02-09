require 'ffi'

class Windows
  extend FFI::Library
  typedef :ulong, :dword

  ffi_lib :shlwapi

  attach_function :PathCanonicalizeA, [:buffer_out, :string], :bool
  attach_function :PathStripToRootA, [:pointer], :bool
  attach_function :PathIsRelativeA, [:string], :bool
  attach_function :PathAppendA, [:buffer_out, :string], :bool

  ffi_lib :kernel32
  attach_function :GetFullPathNameA, [:string, :dword, :buffer_out, :pointer], :dword

  def xpath(path)
    path = path.tr("/", "\\")
    buf = 0.chr * 1024

    if GetFullPathNameA(path, buf.size, buf, nil) == 0
      raise SystemCallError.new('GetFullPathName', FFI.errno)
    end

    p buf.strip

=begin
    ptr = FFI::MemoryPointer.from_string(path)

    p PathIsRelativeA(path)

    unless PathStripToRootA(ptr)
      raise SystemCallError.new('PathStripToRoot', FFI.errno)
    end

    p ptr.read_string
=end

=begin
    unless PathCanonicalizeA(buf, path)
      raise SystemCallError.new('PathCanonicalize', FFI.errno)
    end

    buf.strip
=end
  end
end

if $0 == __FILE__
  #p Windows.new.xpath("C:/foo/../bar")
  #p Windows.new.xpath("C:foo")
  Windows.new.xpath("C:foo")
  #Windows.new.xpath("foo")
end
