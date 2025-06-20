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

// Helper function to find user's home directory
wchar_t* find_user(wchar_t* str){
  SID* sid = NULL;
  DWORD cbSid, cbDom, cbData, lpType;
  SID_NAME_USE peUse;
  LPWSTR str_sid = NULL;
  LONG rv;
  HKEY phkResult = NULL;
  wchar_t subkey[MAX_WPATH];
  wchar_t* lpData = NULL;
  wchar_t* dom = NULL;
  wchar_t* ptr;
  const wchar_t* key_base = L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\ProfileList\\";

  // Read up until first backslash, and preserve the rest for later
  ptr = wcschr(str, L'\\');

  if(ptr){
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
  if(swprintf(subkey, MAX_WPATH, L"%s%s", key_base, str_sid) < 0)
    rb_raise_syserr("swprintf", GetLastError());

  // Get the key handle we need
  rv = RegOpenKeyExW(HKEY_LOCAL_MACHINE, subkey, 0, KEY_QUERY_VALUE, &phkResult);

  if (rv != ERROR_SUCCESS)
    rb_raise_syserr("RegOpenKeyEx", rv);

  lpData = (wchar_t*)malloc(MAX_WPATH);
  cbData = MAX_WPATH;
  lpType = REG_EXPAND_SZ;

  // Finally, get the user's home directory
  rv = RegQueryValueExW(phkResult, L"ProfileImagePath", NULL, &lpType, (LPBYTE)lpData, &cbData);

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
    size = GetEnvironmentVariableW(env, home, 0);
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
    // Skip reallocation, we're already at max size.
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

#endif
    ruby_xfree(temp);
  }
  else{
    home = (wchar_t*)ruby_xmalloc(MAX_WPATH);
    size = GetEnvironmentVariableW(env, home, size);

    if(!size){
      ruby_xfree(home);
      rb_raise_syserr("GetEnvironmentVariable", GetLastError());
    }
  }

  while(wcsstr(home, L"/"))
    home[wcscspn(home, L"/")] = L'\\';

  if (PathIsRelativeW(home))
    rb_raise(rb_eArgError, "non-absolute home");

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
  int length;
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
  length = MultiByteToWideChar(CP_UTF8, 0, StringValueCStr(v_path), -1, NULL, 0);
  path = (wchar_t*)ruby_xmalloc(length * sizeof(wchar_t));

  if(!MultiByteToWideChar(CP_UTF8, 0, StringValueCStr(v_path), -1, path, length)){
    ruby_xfree(path);
    rb_raise_syserr("MultibyteToWideChar", GetLastError());
  }

  // Convert all forward slashes to backslashes to Windows API functions work properly
  while(wcsstr(path, L"/"))
    path[wcscspn(path, L"/")] = L'\\';

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

    while (wcsstr(dir, L"/"))
      dir[wcscspn(dir, L"/")] = L'\\';

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
      while(wcsstr(wpwd, L"\\"))
        wpwd[wcscspn(wpwd, L"\\")] = L'/';

      // Convert string back to multibyte string before returning Ruby object
      length = WideCharToMultiByte(CP_UTF8, 0, wpwd, -1, NULL, 0, NULL, NULL);
      pwd = (char*)ruby_xmalloc(length);
      length = WideCharToMultiByte(CP_UTF8, 0, wpwd, -1, pwd, length, NULL, NULL);

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
  while(wcsstr(buffer, L"\\"))
    buffer[wcscspn(buffer, L"\\")] = L'/';

  length = WideCharToMultiByte(CP_UTF8, 0, buffer, -1, NULL, 0, NULL, NULL);
  final_path = (char*)ruby_xmalloc(length);
  length = WideCharToMultiByte(CP_UTF8, 0, buffer, -1, final_path, length, NULL, NULL);

  ruby_xfree(buffer);

  if (!length){
    ruby_xfree(final_path);
    rb_raise_syserr("WideCharToMultiByte", GetLastError());
  }

  v_path = rb_str_new(final_path, length - 1); // Don't count null terminator

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
