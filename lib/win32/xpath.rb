require 'ffi'

class File
  extend FFI::Library

  typedef :ulong, :dword

  ffi_lib 'shlwapi'

  attach_function :PathCanonicalize, :PathCanonicalizeA, [:pointer, :string], :bool
  attach_function :PathIsRelative, :PathIsRelativeA, [:string], :bool
  attach_function :PathIsRoot, :PathIsRootA, [:string], :bool
  attach_function :PathRemoveBackslash, :PathRemoveBackslashA, [:string], :string

  ffi_lib 'api-ms-win-core-path-l1-1-0'

  attach_function :PathAllocCanonicalize, [:string, :dword, :buffer_in], :int

  S_OK = 0

  PATHCCH_NONE = 0x0000000
  PATHCCH_ALLOW_LONG_PATHS = 0x00000001
  PATHCCH_FORCE_ENABLE_LONG_NAME_PROCESS = 0x00000002
  PATHCCH_FORCE_DISABLE_LONG_NAME_PROCESS = 0x00000004
  PATHCCH_DO_NOT_NORMALIZE_SEGMENTS = 0x00000008
  PATHCCH_ENSURE_IS_EXTENDED_LENGTH_PATH = 0x00000010
  PATHCCH_ENSURE_TRAILING_SLASH = 0x00000020
  PATHCCH_CANONICALIZE_SLASHES = 0x00000040

  MAX_PATH = 256

  def self.expand_path2(path, dir=nil)
    path = path.dup
    path = path.to_path if path.respond_to?(:to_path)

    raise TypeError unless path.is_a?(String)

    flags = PATHCCH_ENSURE_IS_EXTENDED_LENGTH_PATH | PATHCCH_CANONICALIZE_SLASHES

    if ['', '.'].include?(path) && dir.nil?
      return Dir.pwd
    end

    if path[0] == '~'
      home = ENV['HOME'] || ENV['USERPROFILE']
      home ||= ENV['HOMEDRIVE'] + ENV['HOMEPATH'] if ENV['HOMEDRIVE']
      raise ArgumentError unless home
      raise ArgumentError if PathIsRelative(home)
      path = home + path[1..-1]
    end

    path.chop! while ['/', '\\'].include?(path[-1])

    if PathIsRoot(path)
      return path
    end

    buffer = 0.chr * MAX_PATH

    bool = PathCanonicalize(buffer, path)
    raise SystemCallError.new('PathCanonicalize') unless bool

    result = buffer.strip

    if PathIsRelative(path)
      result = File.join(Dir.pwd, result)
    end

    result.encode(Encoding.default_external).tr('\\', '/')
  end
end

if $0 == __FILE__
  p File.expand_path('foo')
  p File.expand_path('.')
  p File.expand_path('.')
end
