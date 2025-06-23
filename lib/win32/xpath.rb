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

  def self.expand_path(path, dir=nil)
    # Handle type checking and conversion
    original_path = path
    path = path.to_path if path.respond_to?(:to_path)

    unless path.is_a?(String)
      raise TypeError, "no implicit conversion of #{path.class} into String"
    end

    path = path.dup

    # Handle dir argument
    if dir
      dir = dir.to_path if dir.respond_to?(:to_path)
      unless dir.is_a?(String)
        raise TypeError, "no implicit conversion of #{dir.class} into String"
      end
      dir = expand_path(dir) # Recursively expand directory
    end

    # Handle empty path
    if path.empty?
      return dir || Dir.pwd
    end    # Handle tilde expansion
    if path.start_with?('~')
      path = expand_tilde(path)
    end

    # Handle drive letters properly - if path has drive letter, ignore dir
    if path =~ /^[a-zA-Z]:/
      # Path has drive letter, use it as is
      dir = nil
    end

    # If we have a directory and path is relative, join them
    if dir && !absolute_path?(path)
      path = File.join(dir, path)
    end    # Normalize path separators
    path = path.tr('\\', '/')

    # Use Windows API to get full path - allocate more space for very long paths
    buffer_size = [path.length * 2, MAX_PATH * 4, 32768].max
    buffer = FFI::MemoryPointer.new(:char, buffer_size)

    result = GetFullPathName(path, buffer_size, buffer, nil)
    if result == 0
      # If GetFullPathName fails, try manual construction for very long paths
      if path.start_with?('/')
        # Absolute path starting with slash - prepend current drive
        current_drive = Dir.pwd[0,2]
        path = current_drive + path
      elsif !absolute_path?(path)
        # Relative path - prepend current directory
        path = File.join(Dir.pwd, path)
      end
      result_path = path.tr('\\', '/')
    else
      result_path = formatted_windows_string(buffer)
    end

    # Ensure UTF-8 encoding to match Ruby standards
    result_path.force_encoding('UTF-8') if result_path.respond_to?(:force_encoding)

    result_path
  end

  private

  def self.expand_tilde(path)
    if path == '~'
      return get_home_directory
    elsif path.start_with?('~/')
      home = get_home_directory
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
        home = get_home_directory
      else
        home = get_user_home_directory(user)
      end

      return home + rest
    end

    path
  end

  def self.get_home_directory
    home = ENV['HOME'] || ENV['USERPROFILE']

    if home.nil? && ENV['HOMEDRIVE'] && ENV['HOMEPATH']
      home = ENV['HOMEDRIVE'] + ENV['HOMEPATH']
    end

    if home.nil?
      raise ArgumentError, "couldn't find HOME environment -- expanding '~'"
    end

    home = home.tr('\\', '/')

    unless absolute_path?(home)
      raise ArgumentError, "non-absolute home"
    end

    home
  end
  def self.get_user_home_directory(username)
    # Allocate memory for SID and domain
    sid_buffer = FFI::MemoryPointer.new(:char, 256)
    domain_buffer = FFI::MemoryPointer.new(:char, 256)
    sid_size = FFI::MemoryPointer.new(:ulong, 1)
    domain_size = FFI::MemoryPointer.new(:ulong, 1)
    sid_name_use = FFI::MemoryPointer.new(:int, 1)

    sid_size.write_ulong(256)
    domain_size.write_ulong(256)

    # Look up the user account
    success = LookupAccountName(nil, username, sid_buffer, sid_size, domain_buffer, domain_size, sid_name_use)

    unless success
      raise ArgumentError, "can't find user '#{username}'"
    end

    # Convert SID to string
    string_sid_ptr = FFI::MemoryPointer.new(:pointer, 1)
    success = ConvertSidToStringSid(sid_buffer, string_sid_ptr)

    unless success
      raise SystemCallError.new('ConvertSidToStringSid', FFI.errno)
    end

    string_sid = string_sid_ptr.read_pointer.read_string

    # Build registry key path
    key_path = "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\ProfileList\\#{string_sid}"    # Open registry key
    key_handle = FFI::MemoryPointer.new(:ulong, 1)
    result = RegOpenKeyEx(HKEY_LOCAL_MACHINE, key_path, 0, KEY_QUERY_VALUE, key_handle)

    # Free the string SID
    LocalFree(string_sid_ptr.read_pointer)

    if result != 0
      raise Errno::ENOENT, "can't find home directory for user '#{username}'"
    end

    handle = key_handle.read_ulong
      # Query the ProfileImagePath value
    data_buffer = FFI::MemoryPointer.new(:char, MAX_PATH * 2)
    data_size = FFI::MemoryPointer.new(:ulong, 1)
    data_type = FFI::MemoryPointer.new(:ulong, 1)

    data_size.write_ulong(MAX_PATH * 2)

    result = RegQueryValueEx(handle, "ProfileImagePath", nil, data_type, data_buffer, data_size)

    RegCloseKey(handle)

    if result != 0
      raise Errno::ENOENT, "can't find home directory for user '#{username}'"
    end

    home = data_buffer.read_string.tr('\\', '/')
    home
  end
  def self.absolute_path?(path)
    # Check for drive letter (C: or C:\) or UNC path (//)
    path =~ /^[a-zA-Z]:[\/\\]?/ || path.start_with?('//') || path.start_with?('\\\\') || path.start_with?('/')
  end
  def self.formatted_windows_string(buffer)
    str = buffer.read_string.tr('\\', '/')

    # Remove trailing slashes except for root paths
    while str.length > 1 && str[-1] == '/' && !(str =~ /^[a-zA-Z]:\/$/i)
      str = str[0..-2]
    end

    # Ensure root drives end with slash
    if str =~ /^[a-zA-Z]:$/i
      str += '/'
    end

    # Handle Windows path quirks - remove trailing spaces and dots
    str = str.rstrip
    while str.length > 1 && str[-1] == '.' && str[-2] != '/'
      str = str[0..-2]
    end

    str
  end
end
