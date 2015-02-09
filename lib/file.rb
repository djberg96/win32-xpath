require 'ffi'

class File
  class << self
    extend FFI::Library
    typedef :ulong, :dword

    WCHAR = Encoding::UTF_16LE
    FILE_ATTRIBUTE_DIRECTORY = 0x00000010

    ffi_lib :kernel32
    attach_function :GetFullPathName, :GetFullPathNameA, [:string, :dword, :pointer, :pointer], :dword

    ffi_lib :shlwapi
    attach_function :PathAppend, :PathAppendA, [:buffer_out, :string], :bool
    attach_function :PathIsRoot, :PathIsRootA, [:string], :bool
    attach_function :PathIsRelative, :PathIsRelativeA, [:string], :bool
    attach_function :PathRemoveBackslash, :PathRemoveBackslashA, [:pointer], :string
    attach_function :PathCanonicalize, :PathCanonicalizeA, [:buffer_out, :string], :bool
    attach_function :PathRelativePathTo, :PathRelativePathToA, [:buffer_out, :string, :dword, :string, :dword], :bool

    def xpath(path, dir=nil)
      path = path.to_path if path.respond_to?(:to_path)

      raise TypeError unless path.is_a?(String)

      if path.include?('~')
        raise ArgumentError unless ENV['HOME']
        raise ArgumentError if PathIsRelative(ENV['HOME'])
        #raise ArgumentError if path =~ /.*?\~\w+$/
        path = path.sub('~', ENV['HOME'])
      end

      if dir
        raise TypeError unless dir.is_a?(String)
        return dir if path.empty?
        if PathIsRelative(path)
          path = File.join(dir, path)
        end
      else
        return Dir.pwd if path.empty?
      end

      ptr = FFI::MemoryPointer.from_string(path)

      while temp = PathRemoveBackslash(ptr)
        break unless temp.empty?
      end

      npath = ptr.read_string

      buf = (0.chr * 1024)

      rv = GetFullPathName(npath, buf.size, buf, nil)

      if rv > buf.size
        npath = 0.chr * rv
        rv = GetFullPathName(npath, buf.size, buf, nil)
      end

      if rv == 0
        raise SystemCallError.new('GetFullPathName', FFI.errno)
      end

      result = buf.strip.tr('\\', '/')

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
  p "="

  p File.xpath("c:foo", "c:/bar")
  p File.expand_path("c:foo", "c:/bar")
end
