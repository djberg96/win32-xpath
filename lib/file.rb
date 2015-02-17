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
      if path.respond_to?(:to_path)
        tpath = path.to_path
      else
        tpath = path.dup
      end

      raise TypeError unless tpath.is_a?(String)

      tpath.tr!("/", "\\")

      if tpath.include?('~')
        raise ArgumentError unless ENV['HOME']
        home = ENV['HOME'].tr("/", "\\")
        raise ArgumentError if PathIsRelative(home)
        raise ArgumentError if tpath =~ /\A\~\w+$/
        tpath = tpath.sub('~', ENV['HOME']) unless tpath =~ /\w+\~/i
      end

      if dir
        raise TypeError unless dir.is_a?(String)
        return dir if tpath.empty?

        if PathIsRelative(tpath)
          tpath = File.join(dir, tpath)
        end
      else
        return Dir.pwd if tpath.empty?
      end

      ptr = FFI::MemoryPointer.from_string(tpath)

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

      if result != path || path.tainted?
        result.taint
      end

      result
    end
  end
end

if $0 == __FILE__
  require 'tmpdir'
  p File.xpath("foo", "C:/bar")
  p File.expand_path("foo", "C:/bar")
  p "="

  p File.xpath("foo", "C:/bar///")
  p File.expand_path("foo", "C:/bar///")
  p "="

  p File.xpath("foo", "C://foo///bar//")
  p File.expand_path("foo", "C://foo///bar//")
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
  p "="

  p File.xpath('~/bar')
  p File.expand_path('~/bar')
  p "="
end
