require 'ffi'

class File
  class << self
    extend FFI::Library
    typedef :ulong, :dword

    WCHAR = Encoding::UTF_16LE
    FILE_ATTRIBUTE_DIRECTORY = 0x00000010

    ffi_lib :kernel32
    attach_function :GetFullPathName, :GetFullPathNameW, [:buffer_in, :dword, :pointer, :pointer], :dword

    ffi_lib :shlwapi
    attach_function :PathIsRoot, :PathIsRootW, [:buffer_in], :bool
    attach_function :PathIsRelative, :PathIsRelativeW, [:buffer_in], :bool
    attach_function :PathRemoveBackslash, :PathRemoveBackslashW, [:pointer], :string
    attach_function :PathCanonicalize, :PathCanonicalizeW, [:buffer_out, :buffer_in], :bool
    attach_function :PathRelativePathTo, :PathRelativePathToW, [:buffer_out, :buffer_in, :dword, :buffer_in, :dword], :bool

    def xpath(path, dir=nil)
      path = path.to_path if path.respond_to?(:to_path)

      raise TypeError unless path.is_a?(String)

      if dir
        raise TypeError unless dir.is_a?(String)

        ndir = (dir + 0.chr).tr("/", "\\").encode(WCHAR)

        #unless PathIsRoot(ndir)
          path = File.join(dir,path) # Will be normalized automatically later
        #end
      end

      return Dir.pwd if path.empty?

      if path.include?('~')
        raise ArgumentError unless ENV['HOME']
        home = (ENV['HOME'] + 0.chr).tr('/', '\\').encode(WCHAR)
        raise ArgumentError if PathIsRelative(home)
        path = path.sub('~', ENV['HOME'])
      end

      npath = (path + 0.chr).tr('/', '\\').encode(WCHAR)

      ptr = FFI::MemoryPointer.from_string(npath)

      while temp = PathRemoveBackslash(ptr)
        break unless temp.empty?
      end

      npath = ptr.read_bytes(npath.size * 2)

      buf = (0.chr * 1024).encode(WCHAR)

      rv = GetFullPathName(npath, buf.size, buf, nil)

      if rv > buf.size
        npath = (0.chr * rv).encode(WCHAR)
        rv = GetFullPathName(npath, buf.size, buf, nil)
      end

      if rv == 0
        raise SystemCallError.new('GetFullPathName', FFI.errno)
      end

      result = buf.strip.encode('UTF-8').tr('\\', '/')

      result.taint
    end
  end
end

if $0 == __FILE__
  require 'tmpdir'
  p File.xpath("foo", "C:/bar")
  p File.expand_path("foo", "C:/bar")
  p "="

  p File.xpath("foo", "bar")
  p File.expand_path("foo", "bar")
  p "="

  p File.xpath("foo/../baz", "bar")
  p File.expand_path("foo/../baz", "bar")
  p "="

  p File.xpath("../a", Dir.tmpdir)
  p File.expand_path("../a", Dir.tmpdir)
end
