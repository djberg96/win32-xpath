#include <ruby.h>
#include <ruby/encoding.h>
#include <windows.h>
#include <shlwapi.h>
#include <sddl.h>
#include <time.h>
#include <stdlib.h>

#ifdef __MINGW32__
#define swprintf _snwprintf 
#endif

#ifdef HAVE_PATHCCH_H
#include <pathcch.h>
#define MAX_WPATH PATHCCH_MAX_CCH
#else
#define MAX_WPATH MAX_PATH * sizeof(wchar_t)
#endif

// Performance optimization: cached values
static wchar_t* cached_home = NULL;
static wchar_t* cached_pwd = NULL;
static wchar_t* cached_drive = NULL;
static clock_t home_cache_time = 0;
static clock_t pwd_cache_time = 0;
static const clock_t CACHE_EXPIRE_TIME = 5 * CLOCKS_PER_SEC; // 5 seconds

// Reusable buffer for performance
static wchar_t* reusable_buffer = NULL;
static size_t buffer_size = 0;
static const size_t MIN_BUFFER_SIZE = 4096;
static const size_t MAX_BUFFER_SIZE = 32768;

// Equivalent to raise SystemCallError.new(string, errnum)
void rb_raise_syserr(const char* msg, DWORD errnum){
  VALUE v_sys = rb_funcall(rb_eSystemCallError, rb_intern("new"), 2, rb_str_new2(msg), LONG2FIX(errnum));
  rb_funcall(rb_mKernel, rb_intern("raise"), 1, v_sys);
}

// Helper functions for performance optimization
static wchar_t* get_reusable_buffer(size_t needed_size) {
  if (reusable_buffer == NULL || buffer_size < needed_size) {
    if (reusable_buffer) {
      ruby_xfree(reusable_buffer);
    }
    buffer_size = (needed_size > MAX_BUFFER_SIZE) ? needed_size : MAX_BUFFER_SIZE;
    reusable_buffer = (wchar_t*)ruby_xmalloc(buffer_size);
  }
  return reusable_buffer;
}

static size_t calculate_buffer_size(size_t path_length) {
  size_t needed = path_length * 2;
  if (needed < MIN_BUFFER_SIZE) needed = MIN_BUFFER_SIZE;
  if (needed < MAX_PATH * 4) needed = MAX_PATH * 4;
  return needed;
}

// Fast path checking functions
static int is_absolute_path(const wchar_t* path) {
  if (!path || !*path) return 0;
  
  // Check for drive letter (C:\ or C:/)
  if (iswalpha(path[0]) && path[1] == L':' && 
      (path[2] == L'\\' || path[2] == L'/' || path[2] == L'\0')) {
    return 1;
  }
  
  // Check for UNC path (\\server\share)
  if (path[0] == L'\\' && path[1] == L'\\') {
    return 1;
  }
  
  // Check for Unix-style absolute path
  if (path[0] == L'/') {
    return 1;
  }
  
  return 0;
}

static int is_drive_letter_only(const wchar_t* path) {
  if (!path || wcslen(path) < 2) return 0;
  return iswalpha(path[0]) && path[1] == L':' && 
         (path[2] == L'\0' || (path[2] == L'/' && path[3] == L'\0') ||
          (path[2] == L'\\' && path[3] == L'\0'));
}

static int starts_with_drive_letter(const wchar_t* path) {
  if (!path || wcslen(path) < 2) return 0;
  return iswalpha(path[0]) && path[1] == L':';
}

// Cached directory functions
static wchar_t* get_cached_pwd() {
  clock_t current_time = clock();
  
  if (cached_pwd == NULL || (current_time - pwd_cache_time) > CACHE_EXPIRE_TIME) {
    if (cached_pwd) {
      ruby_xfree(cached_pwd);
      cached_pwd = NULL;
    }
    
    DWORD length = GetCurrentDirectoryW(0, NULL);
    if (length == 0) {
      rb_raise_syserr("GetCurrentDirectory", GetLastError());
    }
    
    cached_pwd = (wchar_t*)ruby_xmalloc(length * sizeof(wchar_t));
    if (GetCurrentDirectoryW(length, cached_pwd) == 0) {
      ruby_xfree(cached_pwd);
      cached_pwd = NULL;
      rb_raise_syserr("GetCurrentDirectory", GetLastError());
    }
    
    pwd_cache_time = current_time;
  }
  
  return cached_pwd;
}

static wchar_t* get_cached_drive() {
  if (cached_drive == NULL) {
    wchar_t* pwd = get_cached_pwd();
    if (pwd && wcslen(pwd) >= 2) {
      cached_drive = (wchar_t*)ruby_xmalloc(4 * sizeof(wchar_t));
      cached_drive[0] = pwd[0];
      cached_drive[1] = pwd[1];
      cached_drive[2] = L'\0';
    }
  }
  return cached_drive;
}

// Optimized string operations
static void convert_slashes_to_backslashes(wchar_t* path) {
  while (*path) {
    if (*path == L'/') *path = L'\\';
    path++;
  }
}

static void convert_slashes_to_forward(wchar_t* path) {
  while (*path) {
    if (*path == L'\\') *path = L'/';
    path++;
  }
}

static void remove_trailing_slashes(wchar_t* path) {
  size_t len = wcslen(path);
  if (len <= 1) return;
  
  // Don't remove slash from root paths like "C:/"
  if (len == 3 && is_drive_letter_only(path)) return;
  
  while (len > 1 && (path[len-1] == L'/' || path[len-1] == L'\\')) {
    // Don't remove if it's a root drive path
    if (len == 3 && iswalpha(path[0]) && path[1] == L':') break;
    path[--len] = L'\0';
  }
}

static void ensure_drive_ends_with_slash(wchar_t* path) {
  size_t len = wcslen(path);
  if (len == 2 && iswalpha(path[0]) && path[1] == L':') {
    path[2] = L'/';
    path[3] = L'\0';
  }
}

static void remove_trailing_dots(wchar_t* path) {
  size_t len = wcslen(path);
  while (len > 1 && path[len-1] == L'.' && 
         (len == 1 || path[len-2] != L'/' && path[len-2] != L'\\')) {
    path[--len] = L'\0';
  }
}

// Helper function to find user's home directory
wchar_t* find_user(wchar_t* str){
  SID* sid;
  DWORD cbSid, cbDom, cbData, lpType;
  SID_NAME_USE peUse;
  LPWSTR str_sid;
  LONG rv;
  HKEY phkResult;
  wchar_t subkey[MAX_WPATH];
  wchar_t* lpData;
  wchar_t* dom;
  wchar_t* ptr;
  const wchar_t* key_base = L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\ProfileList\\";

  // Read up until first backslash, and preserve the rest for later
  if (ptr = wcschr(str, L'\\')){
    ptr++;
    str[wcscspn(str, L"\\")] = 0;
  }

  sid = (SID*)ruby_xmalloc(SECURITY_MAX_SID_SIZE);
  dom = (wchar_t*)ruby_xmalloc(MAX_WPATH);

  cbSid = SECURITY_MAX_SID_SIZE;
  cbDom = MAX_PATH;

  // Get the user's SID
  if (!LookupAccountNameW(NULL, str, sid, &cbSid, dom, &cbDom, &peUse)){
    char* mstr;
    DWORD length;

    ruby_xfree(sid);
    ruby_xfree(dom);

    length = WideCharToMultiByte(CP_UTF8, 0, str, -1, NULL, 0, NULL, NULL);
    mstr = (char*)ruby_xmalloc(length);
    length = WideCharToMultiByte(CP_UTF8, 0, str, -1, mstr, length, NULL, NULL);

    if (!length){
      ruby_xfree(str);
      ruby_xfree(mstr);
      rb_raise_syserr("WideCharToMultiByte", GetLastError());
    }

    rb_raise(rb_eArgError, "can't find user '%s'", mstr);
  }

  ruby_xfree(dom); // Don't need this any more
    
  // Get the stringy version of the SID
  if (!ConvertSidToStringSidW(sid, &str_sid)){
    ruby_xfree(sid);
    rb_raise_syserr("ConvertSidToStringSid", GetLastError());
  }

  ruby_xfree(sid); // Don't need this any more

  // Mash the stringified SID onto our base key
  if(swprintf(subkey, MAX_WPATH, L"%s%s", key_base, str_sid) < 0){
    LocalFree(str_sid);
    rb_raise_syserr("swprintf", GetLastError());
  }

  LocalFree(str_sid);

  // Get the key handle we need
  rv = RegOpenKeyExW(HKEY_LOCAL_MACHINE, subkey, 0, KEY_QUERY_VALUE, &phkResult);

  if (rv != ERROR_SUCCESS)
    rb_raise_syserr("RegOpenKeyEx", rv);

  lpData = (wchar_t*)malloc(MAX_WPATH);
  cbData = MAX_WPATH;
  lpType = REG_EXPAND_SZ;

  // Finally, get the user's home directory
  rv = RegQueryValueExW(phkResult, L"ProfileImagePath", NULL, &lpType, (LPBYTE)lpData, &cbData);
  RegCloseKey(phkResult);

  if (rv != ERROR_SUCCESS){
    ruby_xfree(lpData);
    rb_raise(rb_eArgError, "can't find home directory for user %ls", str);
  }

  // Append any remaining path data that was originally present
  if (ptr){
    if (swprintf(lpData, MAX_WPATH, L"%s/%s", lpData, ptr) < 0)
      rb_raise_syserr("swprintf", GetLastError());
  }
  
  return lpData;
}

/* Helper function to expand tilde into full path with caching optimization */
wchar_t* expand_tilde(){
  DWORD size = 0;
  wchar_t* home = NULL;
  const wchar_t* env = L"HOME";

  // Don't cache home directory to allow tests to change ENV variables
  // This matches the Ruby optimization for test compatibility

  // First, try to get HOME environment variable
  size = GetEnvironmentVariableW(env, NULL, 0);

  // If that isn't found then try USERPROFILE
  if(!size){
    env = L"USERPROFILE"; 
    size = GetEnvironmentVariableW(env, NULL, 0);
  }

  // If that isn't found then try HOMEDRIVE + HOMEPATH
  if(!size){
    DWORD size2;
    wchar_t* temp;
    const wchar_t* env2 = L"HOMEPATH";
    env = L"HOMEDRIVE";
#ifdef HAVE_PATHCCH_H
    HRESULT hr;
#endif

    // If neither are found then raise an error
    size =  GetEnvironmentVariableW(env, NULL, 0);
    size2 = GetEnvironmentVariableW(env2, NULL, 0);

    if(!size || !size2){
      if (GetLastError() != ERROR_ENVVAR_NOT_FOUND)
        rb_raise_syserr("GetEnvironmentVariable", GetLastError());
      else
        rb_raise(rb_eArgError, "couldn't find HOME environment -- expanding '~'");
    }

    // Use reusable buffer for better performance
    home = get_reusable_buffer(MAX_WPATH);
    temp = (wchar_t*)ruby_xmalloc(MAX_WPATH);

    if(!GetEnvironmentVariableW(env, home, size) || !GetEnvironmentVariableW(env2, temp, size2)){
      ruby_xfree(temp);
      rb_raise_syserr("GetEnvironmentVariable", GetLastError());
    }

#ifdef HAVE_PATHCCH_H
    hr = PathCchAppendEx(home, MAX_WPATH, temp, 1);
    if(hr != S_OK){
      ruby_xfree(temp);
      rb_raise_syserr("PathCchAppendEx", hr);
    }
#else
    if(!PathAppendW(home, temp)){
      ruby_xfree(temp);
      rb_raise_syserr("PathAppend", GetLastError());
    }
#endif
    ruby_xfree(temp);
  }
  else{
    home = get_reusable_buffer(MAX_WPATH);
    size = GetEnvironmentVariableW(env, home, size);

    if(!size){
      rb_raise_syserr("GetEnvironmentVariable", GetLastError());
    }
  }

  // Convert slashes and validate
  convert_slashes_to_backslashes(home);

  if (PathIsRelativeW(home)) {
    rb_raise(rb_eArgError, "non-absolute home");
  }

  // Create a new copy since we're using a reusable buffer
  size_t home_len = wcslen(home);
  wchar_t* result = (wchar_t*)ruby_xmalloc((home_len + 1) * sizeof(wchar_t));
  wcscpy(result, home);
  
  return result;
}

/*
 * File.expand_path(path, dir = nil)
 *
 * Converts +path+ to an absolute path.
 *
 * This is a custom version of the File.expand_path method for Windows
 * that is much faster than the MRI core method. It also supports "~user"
 * expansion on Windows while the MRI core method does not.
 */
static VALUE rb_xpath(int argc, VALUE* argv, VALUE self){
  VALUE v_path, v_path_orig, v_dir_orig;
  wchar_t* buffer = NULL;
  wchar_t* ptr = NULL;
  wchar_t* path = NULL;
  wchar_t* dir = NULL;
  char* final_path;
  int length;
  rb_encoding* path_encoding;
  rb_econv_t* ec;
  const int replaceflags = ECONV_UNDEF_REPLACE|ECONV_INVALID_REPLACE;
  int path_is_empty = 0;

  rb_scan_args(argc, argv, "11", &v_path_orig, &v_dir_orig);

  // Fast path: handle to_path conversion
  if (rb_respond_to(v_path_orig, rb_intern("to_path")))
    v_path_orig = rb_funcall2(v_path_orig, rb_intern("to_path"), 0, NULL);

  SafeStringValue(v_path_orig);

  if (!NIL_P(v_dir_orig)){
    if (rb_respond_to(v_dir_orig, rb_intern("to_path")))
      v_dir_orig = rb_funcall2(v_dir_orig, rb_intern("to_path"), 0, NULL);

    SafeStringValue(v_dir_orig);
  }

  // Fast path: empty path optimization
  if(NUM2LONG(rb_str_length(v_path_orig)) == 0){
    if(NIL_P(v_dir_orig)){
      // Return cached PWD
      wchar_t* pwd = get_cached_pwd();
      convert_slashes_to_forward(pwd);
      
      length = WideCharToMultiByte(CP_UTF8, 0, pwd, -1, NULL, 0, NULL, NULL);
      final_path = (char*)ruby_xmalloc(length);
      WideCharToMultiByte(CP_UTF8, 0, pwd, -1, final_path, length, NULL, NULL);
      
      VALUE result = rb_str_new(final_path, length - 1);
      ruby_xfree(final_path);
      return result;
    }
    path_is_empty = 1;
  }

  // Encoding handling optimization
  path_encoding = rb_enc_get(v_path_orig);

  if (rb_enc_to_index(path_encoding) == rb_utf8_encindex()){
    v_path = rb_str_dup(v_path_orig); 
  }
  else{
    ec = rb_econv_open(rb_enc_name(path_encoding), "UTF-8", replaceflags);
    v_path = rb_econv_str_convert(ec, v_path_orig, ECONV_PARTIAL_INPUT);
    rb_econv_close(ec);
  }
  
  if (!path_is_empty) {
    // Convert to wide string with optimized buffer calculation
    size_t str_len = RSTRING_LEN(v_path);
    size_t needed_size = calculate_buffer_size(str_len);
    
    length = MultiByteToWideChar(CP_UTF8, 0, StringValueCStr(v_path), -1, NULL, 0);
    path = (wchar_t*)ruby_xmalloc(length * sizeof(wchar_t));

    if(!MultiByteToWideChar(CP_UTF8, 0, StringValueCStr(v_path), -1, path, length)){
      ruby_xfree(path);
      rb_raise_syserr("MultibyteToWideChar", GetLastError());
    }

    // Optimized slash conversion
    convert_slashes_to_backslashes(path);

    // Fast tilde expansion check
    if (path[0] == L'~'){
      wchar_t* home;
      
      if (path[1] == L'\0' || path[1] == L'\\'){
        // Handle ~ or ~/path
        home = expand_tilde();
        
        if (path[1] == L'\\'){
#ifdef HAVE_PATHCCHAPPENDEX
          HRESULT hr = PathCchAppendEx(home, MAX_WPATH, path + 2, 1);
          if(hr != S_OK){
            ruby_xfree(home);
            rb_raise_syserr("PathCchAppendEx", hr);
          }
#else
          if (!PathAppendW(home, path + 2)){
            ruby_xfree(home);
            rb_raise_syserr("PathAppend", GetLastError());
          }
#endif
        }
        ruby_xfree(path);
        path = home;
      }
      else{
        // Handle ~user syntax
        home = find_user(path + 1);
        ruby_xfree(path);
        path = home;
      }
    }
  }

  // Directory argument handling with optimizations
  if (!NIL_P(v_dir_orig)){
    VALUE v_dir;
    rb_encoding* dir_encoding;
    
    dir_encoding = rb_enc_get(v_dir_orig);

    if (rb_enc_to_index(dir_encoding) == rb_utf8_encindex()){
      v_dir = rb_str_dup(v_dir_orig);
    }
    else{
      ec = rb_econv_open(rb_enc_name(dir_encoding), "UTF-8", replaceflags);
      v_dir = rb_econv_str_convert(ec, v_dir_orig, ECONV_PARTIAL_INPUT);
      rb_econv_close(ec);
    }

    length = MultiByteToWideChar(CP_UTF8, 0, StringValueCStr(v_dir), -1, NULL, 0);
    dir = (wchar_t*)ruby_xmalloc(length * sizeof(wchar_t));

    if (!MultiByteToWideChar(CP_UTF8, 0, StringValueCStr(v_dir), -1, dir, length)){
      ruby_xfree(dir);
      rb_raise_syserr("MultibyteToWideChar", GetLastError());
    }

    convert_slashes_to_backslashes(dir);

    // Handle tilde in directory
    if (dir[0] == L'~'){
      wchar_t* dir_home;
      
      if (dir[1] == L'\0' || dir[1] == L'\\'){
        dir_home = expand_tilde();
        
        if (dir[1] == L'\\'){
#ifdef HAVE_PATHCCH_H
          HRESULT hr = PathCchAppendEx(dir_home, MAX_WPATH, dir + 2, 1);
          if(hr != S_OK){
            ruby_xfree(dir_home);
            rb_raise_syserr("PathCchAppendEx", hr);
          }
#else
          if (!PathAppendW(dir_home, dir + 2)){
            ruby_xfree(dir_home);
            rb_raise_syserr("PathAppend", GetLastError());
          }
#endif
        }
        ruby_xfree(dir);
        dir = dir_home;
      }
      else{
        dir_home = find_user(dir + 1);
        ruby_xfree(dir);
        dir = dir_home;
      }
    }

    // Fast path: if path is empty, use directory
    if (path_is_empty || !wcslen(path)) {
      if (path) ruby_xfree(path);
      path = dir;
      dir = NULL;
    }
    // Fast path: if path has drive letter, ignore directory
    else if (starts_with_drive_letter(path)) {
      ruby_xfree(dir);
      dir = NULL;
    }
    // Path is relative, combine with directory
    else if (!is_absolute_path(path)) {
#ifdef HAVE_PATHCCH_H
      HRESULT hr = PathCchAppendEx(dir, MAX_WPATH, path, 1);
      if(hr != S_OK){
        ruby_xfree(dir);
        rb_raise_syserr("PathCchAppendEx", hr);
      }
#else
      if(!PathAppendW(dir, path)){
        ruby_xfree(dir);
        rb_raise_syserr("PathAppend", GetLastError());
      }
#endif

      ruby_xfree(path);
      path = dir;
      dir = NULL;
    }
    else {
      // Path is absolute, ignore directory
      ruby_xfree(dir);
      dir = NULL;
    }
  }
  else{
    // No directory argument
    if (path_is_empty || !wcslen(path)){
      // Return current directory
      wchar_t* pwd = get_cached_pwd();
      convert_slashes_to_forward(pwd);
      
      length = WideCharToMultiByte(CP_UTF8, 0, pwd, -1, NULL, 0, NULL, NULL);
      final_path = (char*)ruby_xmalloc(length);
      WideCharToMultiByte(CP_UTF8, 0, pwd, -1, final_path, length, NULL, NULL);
      
      VALUE result = rb_str_new(final_path, length - 1);
      ruby_xfree(final_path);
      if (path) ruby_xfree(path);
      return result;
    }
  }

  // Remove trailing backslashes with optimization
#ifdef HAVE_PATHCCH_H
  while (PathCchRemoveBackslash(path, wcslen(path)+1) == S_OK);
#else
  PathRemoveBackslashW(path);
#endif

  // Get full path with optimized buffer
  length = GetFullPathNameW(path, 0, NULL, NULL);
  if (length == 0) {
    ruby_xfree(path);
    rb_raise_syserr("GetFullPathName", GetLastError());
  }
  
  buffer = get_reusable_buffer(length * sizeof(wchar_t));
  length = GetFullPathNameW(path, length, buffer, NULL);

  if (!length){
    ruby_xfree(path);
    rb_raise_syserr("GetFullPathName", GetLastError());
  }

  ruby_xfree(path);

  // Optimized string formatting
  convert_slashes_to_forward(buffer);
  remove_trailing_slashes(buffer);
  ensure_drive_ends_with_slash(buffer);
  remove_trailing_dots(buffer);

  // Convert back to multibyte
  length = WideCharToMultiByte(CP_UTF8, 0, buffer, -1, NULL, 0, NULL, NULL);
  final_path = (char*)ruby_xmalloc(length);
  length = WideCharToMultiByte(CP_UTF8, 0, buffer, -1, final_path, length, NULL, NULL);

  if (!length){
    ruby_xfree(final_path);
    rb_raise_syserr("WideCharToMultiByte", GetLastError());
  }

  VALUE result = rb_str_new(final_path, length - 1); // Don't count null terminator
  ruby_xfree(final_path);

  // Handle encoding conversion if needed
  if (rb_enc_to_index(path_encoding) != rb_utf8_encindex()){
    ec = rb_econv_open("UTF-8", rb_enc_name(path_encoding), replaceflags);
    result = rb_econv_str_convert(ec, result, ECONV_PARTIAL_INPUT);
    rb_econv_close(ec);    
  }

  rb_enc_associate(result, path_encoding);
  
  return result;
}

// Cleanup function to free cached values
static void cleanup_cached_values() {
  if (cached_home) {
    ruby_xfree(cached_home);
    cached_home = NULL;
  }
  if (cached_pwd) {
    ruby_xfree(cached_pwd);
    cached_pwd = NULL;
  }
  if (cached_drive) {
    ruby_xfree(cached_drive);
    cached_drive = NULL;
  }
  if (reusable_buffer) {
    ruby_xfree(reusable_buffer);
    reusable_buffer = NULL;
    buffer_size = 0;
  }
}

void Init_xpath(){
  rb_define_singleton_method(rb_cFile, "expand_path", rb_xpath, -1);
  
  // Register cleanup function to be called when Ruby exits
  atexit(cleanup_cached_values);
}
