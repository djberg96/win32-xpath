#include <ruby.h>
#include <ruby/encoding.h>
#include <windows.h>
#include <shlwapi.h>
#include <sddl.h>

#ifdef __MINGW32__
#define swprintf _snwprintf 
#endif

#ifdef HAVE_PATHCCH_H
#include <pathcch.h>
#define MAX_WPATH PATHCCH_MAX_CCH
#else
#define MAX_WPATH MAX_PATH * sizeof(wchar_t)
#endif

// Equivalent to raise SystemCallError.new(string, errnum)
void rb_raise_syserr(const char* msg, DWORD errnum){
  VALUE v_sys = rb_funcall(rb_eSystemCallError, rb_intern("new"), 2, rb_str_new2(msg), LONG2FIX(errnum));
  rb_funcall(rb_mKernel, rb_intern("raise"), 1, v_sys);
}


static inline void replace_char(wchar_t* str, wchar_t find, wchar_t replace) {
  if (!str) return;
  wchar_t* p = str;
  while (*p) {
    if (*p == find) *p = replace;
    p++;
  }
}

static wchar_t* convert_to_wchar(const char* str, DWORD* length_out) {
  int length = MultiByteToWideChar(CP_UTF8, 0, str, -1, NULL, 0);
  if (!length) {
    rb_raise_syserr("MultiByteToWideChar", GetLastError());
  }

  wchar_t* wstr = (wchar_t*)ruby_xmalloc(length * sizeof(wchar_t));
  if (!MultiByteToWideChar(CP_UTF8, 0, str, -1, wstr, length)) {
    ruby_xfree(wstr);
    rb_raise_syserr("MultiByteToWideChar", GetLastError());
  }

  if (length_out) *length_out = length;
  return wstr;
}

static char* convert_from_wchar(const wchar_t* wstr, DWORD* length_out) {
  int length = WideCharToMultiByte(CP_UTF8, 0, wstr, -1, NULL, 0, NULL, NULL);
  if (!length) {
    rb_raise_syserr("WideCharToMultiByte", GetLastError());
  }

  char* str = (char*)ruby_xmalloc(length);
  if (!WideCharToMultiByte(CP_UTF8, 0, wstr, -1, str, length, NULL, NULL)) {
    ruby_xfree(str);
    rb_raise_syserr("WideCharToMultiByte", GetLastError());
  }

  if (length_out) *length_out = length;
  return str;
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

    mstr = convert_from_wchar(str, &length);
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

/* Helper function to expand tilde into full path. Note that I don't use the
 * PathCchXXX functions here because it's extremely unlikely that a person's
 * home directory exceeds MAX_PATH. In the unlikely even that it does exceed
 * MAX_PATH, an error will be raised.
 */
wchar_t* expand_tilde(){
  DWORD size = 0;
  wchar_t* home = NULL;
  const wchar_t* env = L"HOME";

  // First, try to get HOME environment variable
  size = GetEnvironmentVariableW(env, NULL, 0);

  // If that isn't found then try USERPROFILE
  if(!size){
    env = L"USERPROFILE"; 
    size = GetEnvironmentVariableW(env, NULL, 0);
  }

  // If that isn't found the try HOMEDRIVE + HOMEPATH
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

    home = (wchar_t*)ruby_xmalloc(MAX_WPATH);
    temp = (wchar_t*)ruby_xmalloc(MAX_WPATH);

    if(!GetEnvironmentVariableW(env, home, size) || !GetEnvironmentVariableW(env2, temp, size2)){
      ruby_xfree(home);
      ruby_xfree(temp);
      rb_raise_syserr("GetEnvironmentVariable", GetLastError());
    }

#ifdef HAVE_PATHCCH_H
    hr = PathCchAppendEx(home, MAX_WPATH, temp, 1);
    if(hr != S_OK){
      ruby_xfree(home);
      ruby_xfree(temp);
      rb_raise_syserr("PathCchAppendEx", hr);
    }
#else
    if(!PathAppendW(home, temp)){
      ruby_xfree(home);
      ruby_xfree(temp);
      rb_raise_syserr("PathAppend", GetLastError());
    }

    ruby_xfree(temp);
#endif
  }
  else{
    home = (wchar_t*)ruby_xmalloc(MAX_WPATH);
    size = GetEnvironmentVariableW(env, home, size);

    if(!size){
      ruby_xfree(home);
      rb_raise_syserr("GetEnvironmentVariable", GetLastError());
    }
  }

  replace_char(home, L'/', L'\\');

  if (PathIsRelativeW(home)) {
    ruby_xfree(home);
    rb_raise(rb_eArgError, "non-absolute home");
  }

  return home;
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
  char* final_path;
  DWORD length;
  rb_encoding* path_encoding;
  rb_econv_t* ec;
  const int replaceflags = ECONV_UNDEF_REPLACE|ECONV_INVALID_REPLACE;

  rb_scan_args(argc, argv, "11", &v_path_orig, &v_dir_orig);

  if (rb_respond_to(v_path_orig, rb_intern("to_path")))
    v_path_orig = rb_funcall2(v_path_orig, rb_intern("to_path"), 0, NULL);

  SafeStringValue(v_path_orig);

  if (!NIL_P(v_dir_orig)){
    if (rb_respond_to(v_dir_orig, rb_intern("to_path")))
      v_dir_orig = rb_funcall2(v_dir_orig, rb_intern("to_path"), 0, NULL);

    SafeStringValue(v_dir_orig);
  }

  // Short circuit an empty first argument if there's no second argument.
  if(NUM2LONG(rb_str_length(v_path_orig)) == 0){
    if(NIL_P(v_dir_orig))
      return rb_dir_getwd();
  }

  // Dup and prep string for modification
  path_encoding = rb_enc_get(v_path_orig);

  if (rb_enc_to_index(path_encoding) == rb_utf8_encindex()){
    v_path = rb_str_dup(v_path_orig); 
  }
  else{
    ec = rb_econv_open(rb_enc_name(path_encoding), "UTF-8", replaceflags);
    v_path = rb_econv_str_convert(ec, v_path_orig, ECONV_PARTIAL_INPUT);
    rb_econv_close(ec);
  }
  
  rb_str_modify_expand(v_path, MAX_WPATH);

  // Make our path a wide string for later functions
  path = convert_to_wchar(StringValueCStr(v_path), NULL);

  // Convert all forward slashes to backslashes to Windows API functions work properly
  replace_char(path, L'/', L'\\');

  // Handle ~ expansion if first character.
  if ( (ptr = wcschr(path, L'~')) && ((int)(ptr - path) == 0) ){
    wchar_t* home;

    // Handle both ~/user and ~user syntax
    if (ptr[1] && ptr[1] != L'\\'){
      home = find_user(++ptr);
    }
    else{
#ifdef HAVE_PATHCCHAPPENDEX
      HRESULT hr;
      home = expand_tilde();

      hr = PathCchAppendEx(home, MAX_WPATH, ++ptr, 1);

      if(hr != S_OK){
        ruby_xfree(home);
        rb_raise_syserr("PathCchAppendEx", hr);
      }
#else
      home = expand_tilde();

      if (!PathAppendW(home, ++ptr)){
        ruby_xfree(home);
        rb_raise_syserr("PathAppend", GetLastError());
      }
#endif
    }

    path = home;
  }

  // Directory argument is present
  if (!NIL_P(v_dir_orig)){
    wchar_t* dir;
    VALUE v_dir;
    rb_encoding* dir_encoding;
#ifdef HAVE_PATHCCH_H
    HRESULT hr;
#endif

    dir_encoding = rb_enc_get(v_dir_orig);

    // Hooray for encodings
    if (rb_enc_to_index(dir_encoding) == rb_utf8_encindex()){
      v_dir = rb_str_dup(v_dir_orig);
    }
    else{
      ec = rb_econv_open(rb_enc_name(dir_encoding), "UTF-8", replaceflags);
      v_dir = rb_econv_str_convert(ec, v_dir_orig, ECONV_PARTIAL_INPUT);
      rb_econv_close(ec);
    }

    // Prep string for modification
    rb_str_modify_expand(v_dir, MAX_WPATH);

    length = MultiByteToWideChar(CP_UTF8, 0, StringValueCStr(v_dir), -1, NULL, 0);
    dir = (wchar_t*)ruby_xmalloc(MAX_WPATH * sizeof(wchar_t));

    if (!MultiByteToWideChar(CP_UTF8, 0, StringValueCStr(v_dir), -1, dir, length)){
      ruby_xfree(dir);
      rb_raise_syserr("MultibyteToWideChar", GetLastError());
    }

    replace_char(dir, L'/', L'\\');

    // Check for tilde in first character
    if ( (ptr = wcschr(dir, L'~')) && ((int)(ptr - dir) == 0) ){
      if (ptr[1] && ptr[1] != L'\\'){
        dir = find_user(++ptr);
      }
      else{
        dir = expand_tilde();

#ifdef HAVE_PATHCCH_H
        hr = PathCchAppendEx(dir, MAX_WPATH, ++ptr, 1);

        if(hr != S_OK){
          ruby_xfree(dir);
          rb_raise_syserr("PathCchAppendEx", hr);
        }
#else
        if (!PathAppendW(dir, ++ptr)){
          ruby_xfree(dir);
          rb_raise_syserr("PathAppend", GetLastError());
        }
#endif
      }
    }

    if (!wcslen(path))
      path = dir;

    if (PathIsRelativeW(path)){ 

#ifdef HAVE_PATHCCH_H
      hr = PathCchAppendEx(dir, MAX_WPATH, path, 1);

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

      // Remove leading slashes from relative paths
      if (dir[0] == L'\\')
        ++dir;

      path = dir;
    }
  }
  else{
    if (!wcslen(path)){
      char* pwd;
      wchar_t* wpwd;

      // First call, get the length
      length = GetCurrentDirectoryW(0, NULL);
      wpwd = (wchar_t*)ruby_xmalloc(length * sizeof(wchar_t));

      length = GetCurrentDirectoryW(length, wpwd);

      if(!length){
        ruby_xfree(wpwd);
        rb_raise_syserr("GetCurrentDirectory", GetLastError());
      }

      // Convert backslashes into forward slashes
      replace_char(wpwd, L'\\', L'/');

      // Convert string back to multibyte string before returning Ruby object
      pwd = convert_from_wchar(wpwd, NULL);

      ruby_xfree(wpwd);

      if (!length){
        ruby_xfree(pwd);
        rb_raise_syserr("WideCharToMultiByte", GetLastError());
      }

      return rb_str_new2(pwd);
    }
  }

  // Strip all trailing backslashes
#ifdef HAVE_PATHCCH_H
  while (PathCchRemoveBackslash(path, wcslen(path)+1) == S_OK);
#else
  while (!*PathRemoveBackslashW(path));
#endif

  // First call, get the length
  length = GetFullPathNameW(path, 0, buffer, NULL);
  buffer = (wchar_t*)ruby_xmalloc(length * sizeof(wchar_t));

  // Now get the path
  length = GetFullPathNameW(path, length, buffer, NULL);

  if (!length){
    ruby_xfree(buffer);
    rb_raise_syserr("GetFullPathName", GetLastError());
  }

  // Convert backslashes into forward slashes
  replace_char(buffer, L'\\', L'/');

  final_path = convert_from_wchar(buffer, &length);

  ruby_xfree(buffer);

  if (!length){
    ruby_xfree(final_path);
    rb_raise_syserr("WideCharToMultiByte", GetLastError());
  }

  v_path = rb_str_new(final_path, length - 1); // Don't count null terminator
  ruby_xfree(final_path);

  if (rb_enc_to_index(path_encoding) != rb_utf8_encindex()){
    ec = rb_econv_open("UTF-8", rb_enc_name(path_encoding), replaceflags);
    v_path = rb_econv_str_convert(ec, v_path, ECONV_PARTIAL_INPUT);
    rb_econv_close(ec);    
  }

  rb_enc_associate(v_path, path_encoding);
  
  return v_path;
}

void Init_xpath(){
  rb_define_singleton_method(rb_cFile, "expand_path", rb_xpath, -1);
}
