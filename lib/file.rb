require 'ffi'

class File
  class << self
    extend FFI::Library
    typedef :ulong, :dword

    ffi_lib :kernel32
    attach_function :GetFullPathName, :GetFullPathNameA, [:string, :dword, :pointer, :pointer], :dword

    ffi_lib :shlwapi
    attach_function :PathIsRelative, :PathIsRelativeA, [:string], :bool
    attach_function :PathRemoveBackslash, :PathRemoveBackslashA, [:pointer], :string
    attach_function :PathStripPath, :PathStripPathA, [:pointer], :void

    def xpath(path, dir=nil)
      path = path.to_path if path.respond_to?(:to_path)

      raise TypeError unless path.is_a?(String)

      path = path.tr("/", "\\")

      if path.include?('~')
        raise ArgumentError unless ENV['HOME']
        home = ENV['HOME'].tr("/", "\\")
        raise ArgumentError if PathIsRelative(home)
        raise ArgumentError if path =~ /\A\~\w+$/
        path = path.sub('~', ENV['HOME']) unless path =~ /\w+\~/i
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

      buf = 0.chr * 1024

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
  p "="

  p File.xpath('~')
  p File.expand_path('~')
  p "="

  p File.xpath('foo~bar')
  p File.expand_path('foo~bar')
end
