require 'ffi'

class File
  extend FFI::Library
  ffi_lib 'shlwapi'

  attach_function :PathCanonicalize, :PathCanonicalizeA, [:pointer, :string], :bool
  attach_function :PathIsRelative, :PathIsRelativeA, [:string], :bool

  ffi_lib 'api-ms-win-core-path-l1-1-0'

  typedef :ulong, :dword

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

  attach_function :PathAllocCanonicalize, [:string, :dword, :buffer_in], :int

  def self.expand_path2(path, dir=nil)
    flags = PATHCCH_ENSURE_IS_EXTENDED_LENGTH_PATH | PATHCCH_CANONICALIZE_SLASHES

    if ['', '.'].include?(path) && dir.nil?
      return Dir.pwd
    end

    if !PathIsRelative(path)
      return path
    end

    #buffer = FFI::MemoryPointer.new(MAX_PATH)
    buffer = 0.chr * MAX_PATH
    #result = PathAllocCanonicalize(path, flags, buffer)

    bool = PathCanonicalize(buffer, path)

    #if result != S_OK
    if !bool
      #raise SystemCallError.new('PathAllocCanonicalize')
      raise SystemCallError.new('PathCanonicalize')
    end

    #result = buffer.read_pointer.read_string.tr('\\', '/').encode('UTF-8')
    #result = buffer.read_pointer.read_string.tr('\\', '/').encode('UTF-8')
    result = buffer.strip

    if PathIsRelative(path)
      result = File.join(Dir.pwd, result)
    end

    result
  end
end

if $0 == __FILE__
  p File.expand_path('foo')
  p File.expand_path('.')
  p File.expand_path('.')
end
