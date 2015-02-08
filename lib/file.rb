require 'ffi'

class File
  class << self
    extend FFI::Library
    typedef :ulong, :dword

    WCHAR = Encoding::UTF_16LE

    ffi_lib :kernel32
    attach_function :GetFullPathName, :GetFullPathNameW, [:buffer_in, :dword, :pointer, :pointer], :dword

    ffi_lib :shlwapi
    attach_function :PathIsRoot, :PathIsRootW, [:buffer_in], :bool
    attach_function :PathIsRelative, :PathIsRelativeW, [:buffer_in], :bool

    def xpath(path, dir=nil)
      raise TypeError unless path.is_a?(String)

      if dir
        raise TypeError unless dir.is_a?(String)
      end

      return Dir.pwd if path.empty?

      npath = (path + 0.chr).tr('/', '\\').encode(WCHAR)

      return path unless PathIsRelative(npath)

      buf = (0.chr * 1024).encode(WCHAR)

      rv = GetFullPathName(npath, buf.size, buf, nil)

      if rv > buf.size
        npath = (0.chr * rv).encode(WCHAR)
        rv = GetFullPathName(npath, buf.size, buf, nil)
      end

      if rv == 0
        raise SystemCallError.new('GetFullPathName', FFI.errno)
      end

      #if dir
      #  if PathIsRelative(dir)
      #  else
      #  end
      #end

      result = buf.strip.encode(Encoding::UTF_8).tr('\\', '/')

      result.taint
    end
  end
end

if $0 == __FILE__
  p File.xpath("C:/foo").tainted?
  p File.xpath("foo").tainted?
end
