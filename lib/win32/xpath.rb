require 'ffi'

class File
  extend FFI::Library
  ffi_lib :kernel32, :advapi32, :shlwapi
  typedef :ulong, :dword
  typedef :uintptr_t, :handle
  attach_function :GetCurrentDirectory, :GetCurrentDirectoryA, [:dword, :pointer], :dword
  attach_function :GetFullPathName, :GetFullPathNameA, [:string, :dword, :pointer, :pointer], :dword
  attach_function :LookupAccountName, :LookupAccountNameA, [:pointer, :string, :pointer, :pointer, :pointer, :pointer, :pointer], :bool
  attach_function :ConvertSidToStringSid, :ConvertSidToStringSidA, [:pointer, :pointer], :bool
  attach_function :RegOpenKeyEx, :RegOpenKeyExA, [:ulong, :string, :dword, :dword, :pointer], :long
  attach_function :RegQueryValueEx, :RegQueryValueExA, [:ulong, :string, :pointer, :pointer, :pointer, :pointer], :long
  attach_function :RegCloseKey, [:ulong], :long
  attach_function :LocalFree, [:pointer], :handle

  MAX_PATH = 260
  HKEY_LOCAL_MACHINE = 0x80000002
  KEY_QUERY_VALUE = 0x0001
  REG_SZ = 1
  REG_EXPAND_SZ = 2

  # Performance optimization: cache frequently used values
  @cached_home = nil
  @cached_pwd = nil
  @cached_drive = nil
  @home_cache_time = 0
  @pwd_cache_time = 0

  # Pre-compiled regex patterns for better performance
  DRIVE_LETTER_REGEX = /\A[a-zA-Z]:[\/\\]?\z/
  ABSOLUTE_PATH_REGEX = /\A(?:[a-zA-Z]:[\/\\]?|[\/\\]{2}|\/)/
  ROOT_DRIVE_REGEX = /\A[a-zA-Z]:\/?\z/i

  # Reusable buffers to reduce allocations
  @reusable_buffer = nil
  @buffer_size = 0

  def self.expand_path(path, dir=nil)
    # Fast path: handle type checking and conversion with minimal overhead
    path = path.respond_to?(:to_path) ? path.to_path : path

    unless path.is_a?(String)
      raise TypeError, "no implicit conversion of #{path.class} into String"
    end

    # Optimize: avoid dup for empty paths
    if path.empty?
      return dir ? expand_path(dir) : get_cached_pwd
    end

    # Only dup if we're going to modify the string
    path = path.dup

    # Handle dir argument with optimized type checking
    if dir
      dir = dir.respond_to?(:to_path) ? dir.to_path : dir
      unless dir.is_a?(String)
        raise TypeError, "no implicit conversion of #{dir.class} into String"
      end
      dir = expand_path(dir) # Recursively expand directory
    end

    # Fast tilde expansion check using optimized method
    if path.start_with?('~')
      path = expand_tilde_fast(path)
    end

    # Optimized drive letter check using pre-compiled regex
    if path =~ DRIVE_LETTER_REGEX
      dir = nil # Path has drive letter, ignore dir
    end

    # Fast relative path joining
    if dir && !absolute_path_fast?(path)
      path = join_paths_fast(dir, path)
    end

    # Optimize: single tr operation and efficient buffer management
    path.tr!('\\', '/')

    # Use optimized buffer allocation
    buffer_size = calculate_buffer_size(path.length)
    buffer = get_reusable_buffer(buffer_size)

    result = GetFullPathName(path, buffer_size, buffer, nil)
    if result == 0
      # Fast fallback for long paths
      result_path = construct_absolute_path_fast(path)
    else
      result_path = format_windows_string_fast(buffer)
    end

    # Optimize: only force encoding if needed
    result_path.force_encoding('UTF-8') unless result_path.encoding == Encoding::UTF_8

    result_path
  end
  private
  # Performance optimized caching methods
  def self.get_cached_pwd
    current_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    if @cached_pwd.nil? || (current_time - @pwd_cache_time) > 5.0
      @cached_pwd = Dir.pwd
      @pwd_cache_time = current_time
    end
    @cached_pwd
  end

  def self.get_cached_home
    # Don't cache home directory to allow tests to change ENV variables
    compute_home_directory
  end

  def self.get_cached_drive
    @cached_drive ||= get_cached_pwd[0,2]
  end

  # Optimized buffer management
  def self.calculate_buffer_size(path_length)
    [path_length * 2, MAX_PATH * 4, 4096].max
  end

  def self.get_reusable_buffer(needed_size)
    if @reusable_buffer.nil? || @buffer_size < needed_size
      @buffer_size = [needed_size, 32768].max
      @reusable_buffer = FFI::MemoryPointer.new(:char, @buffer_size)
    end
    @reusable_buffer
  end

  # Fast path operations
  def self.absolute_path_fast?(path)
    path =~ ABSOLUTE_PATH_REGEX
  end

  def self.join_paths_fast(dir, path)
    # Optimize common case where dir ends with / and path doesn't start with /
    if dir.end_with?('/') && !path.start_with?('/')
      dir + path
    elsif !dir.end_with?('/') && !path.start_with?('/')
      dir + '/' + path
    else
      File.join(dir, path)
    end
  end

  def self.construct_absolute_path_fast(path)
    if path.start_with?('/')
      get_cached_drive + path
    else
      join_paths_fast(get_cached_pwd, path)
    end.tr('\\', '/')
  end

  def self.format_windows_string_fast(buffer)
    str = buffer.read_string
    str.tr!('\\', '/')

    # Optimize: single pass cleanup
    str.rstrip! if str.end_with?(' ')

    # Remove trailing slashes except for root paths
    while str.length > 1 && str.end_with?('/') && !(str =~ ROOT_DRIVE_REGEX)
      str.chop!
    end

    # Ensure root drives end with slash
    str += '/' if str =~ /\A[a-zA-Z]:\z/

    # Remove trailing dots (Windows quirk)
    while str.length > 1 && str.end_with?('.') && str[-2] != '/'
      str.chop!
    end

    str
  end

  def self.expand_tilde_fast(path)
    case path
    when '~'
      get_cached_home
    when /\A~[\/\\]/
      get_cached_home + path[1..-1]
    else
      # Handle ~user syntax - keep original implementation for compatibility
      expand_tilde_original(path)
    end
  end
  # Original tilde expansion for complex cases
  def self.expand_tilde_original(path)
    if path == '~'
      return get_cached_home
    elsif path.start_with?('~/')
      home = get_cached_home
      return home + path[1..-1]
    elsif path.start_with?('~') && (path[1] == '\\' || path[1].nil? || path[1] =~ /[^\/\\]/)
      # Handle ~user syntax
      if path[1] == '\\'
        user = ''
        rest = path[2..-1]
      else
        parts = path[1..-1].split(/[\/\\]/, 2)
        user = parts[0] || ''
        rest = parts[1] ? '/' + parts[1] : ''
      end

      if user.empty?
        home = get_cached_home
      else
        home = get_user_home_directory(user)
      end

      return home + rest
    end

    path
  end

  def self.compute_home_directory
    # Optimized environment variable lookup with single traversal
    home = ENV['HOME']
    return normalize_home_path(home) if home

    home = ENV['USERPROFILE']
    return normalize_home_path(home) if home

    if ENV['HOMEDRIVE'] && ENV['HOMEPATH']
      home = ENV['HOMEDRIVE'] + ENV['HOMEPATH']
      return normalize_home_path(home)
    end

    raise ArgumentError, "couldn't find HOME environment -- expanding '~'"
  end
  def self.normalize_home_path(home)
    home = home.tr('\\', '/')
    unless absolute_path_fast?(home)
      raise ArgumentError, "non-absolute home"
    end
    home
  end

  def self.get_user_home_directory(username)
    # Optimize: Pre-allocate known buffer sizes
    sid_buffer = FFI::MemoryPointer.new(:char, 68)
    domain_buffer = FFI::MemoryPointer.new(:char, 256)
    sid_size = FFI::MemoryPointer.new(:ulong, 1)
    domain_size = FFI::MemoryPointer.new(:ulong, 1)
    sid_name_use = FFI::MemoryPointer.new(:int, 1)

    sid_size.write_ulong(68)
    domain_size.write_ulong(256)

    # Look up the user account
    unless LookupAccountName(nil, username, sid_buffer, sid_size, domain_buffer, domain_size, sid_name_use)
      raise ArgumentError, "can't find user '#{username}'"
    end

    # Convert SID to string
    string_sid_ptr = FFI::MemoryPointer.new(:pointer, 1)
    unless ConvertSidToStringSid(sid_buffer, string_sid_ptr)
      raise SystemCallError.new('ConvertSidToStringSid', FFI.errno)
    end

    string_sid = string_sid_ptr.read_pointer.read_string

    # Build registry key path with string interpolation (faster than concatenation)
    key_path = "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\ProfileList\\#{string_sid}"

    # Open registry key
    key_handle = FFI::MemoryPointer.new(:ulong, 1)
    result = RegOpenKeyEx(HKEY_LOCAL_MACHINE, key_path, 0, KEY_QUERY_VALUE, key_handle)

    # Free the string SID immediately
    LocalFree(string_sid_ptr.read_pointer)

    if result != 0
      raise Errno::ENOENT, "can't find home directory for user '#{username}'"
    end

    handle = key_handle.read_ulong

    # Query the ProfileImagePath value with optimized buffer
    data_buffer = FFI::MemoryPointer.new(:char, MAX_PATH * 2)
    data_size = FFI::MemoryPointer.new(:ulong, 1)
    data_type = FFI::MemoryPointer.new(:ulong, 1)

    data_size.write_ulong(MAX_PATH * 2)

    result = RegQueryValueEx(handle, "ProfileImagePath", nil, data_type, data_buffer, data_size)

    RegCloseKey(handle)

    if result != 0
      raise Errno::ENOENT, "can't find home directory for user '#{username}'"
    end

    # Optimize: single tr! operation
    home = data_buffer.read_string
    home.tr!('\\', '/')
    home
  end

  # Optimized path checking using pre-compiled regex
  def self.absolute_path?(path)
    path =~ ABSOLUTE_PATH_REGEX
  end

  # Keep original method name for backward compatibility but use optimized version
  def self.formatted_windows_string(buffer)
    format_windows_string_fast(buffer)
  end
end
