require 'ffi'

class File
  extend FFI::Library
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

  attach_function :PathAllocCanonicalize, [:string, :dword, :pointer], :int

  def self.xpath(path, dir=nil)
    buffer = FFI::MemoryPointer.new(MAX_PATH)
    result = PathAllocCanonicalize(path, PATHCCH_NONE, buffer)

    if result != S_OK
      raise SystemCallError.new('PathAllocCanonicalize')
    end

    buffer.read_string
  end
end

if $0 == __FILE__
  p File.expand_path('foo')
  p File.expand_path('.')
  p File.expand_path('.')
end
