#include <ruby.h>
#include <ruby/encoding.h>
#include <windows.h>
#include <shlwapi.h>
#include <sddl.h>

#define MAX_WPATH MAX_PATH * sizeof(wchar_t)

// Helper function to find user's home directory
wchar_t* find_user(wchar_t* str){
  SID* sid;
  DWORD cbSid, cbDom;
  SID_NAME_USE peUse;
  LPWSTR str_sid;
  wchar_t* dom;
  wchar_t* subkey;
  wchar_t* kvalue;
  LONG lpcbValue;
  HKEY phkResult = 0;
  const wchar_t* key_base = L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\ProfileList\\";

  sid = (SID*)ruby_xmalloc(MAX_PATH);
  dom = (wchar_t*)ruby_xmalloc(MAX_PATH);

  cbSid = MAX_PATH;
  cbDom = MAX_PATH;

  if (!LookupAccountNameW(NULL, str, sid, &cbSid, dom, &cbDom, &peUse))
    rb_raise(rb_eArgError, "can't find user %ls", str);
    
  if (!ConvertSidToStringSidW(sid, &str_sid))
    rb_sys_fail("ConvertSidToStringSid");

  subkey = (wchar_t*)malloc(MAX_WPATH);
  kvalue = (wchar_t*)malloc(MAX_WPATH);

  // Is there a better way?
  wcscat(subkey, key_base);
  wcscat(subkey, str_sid);

  if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, subkey, 0, KEY_QUERY_VALUE, &phkResult))
    rb_sys_fail("RegOpenKeyEx");

  lpcbValue = MAX_PATH * sizeof(wchar_t);

  if (RegQueryValueW(phkResult, subkey, kvalue, &lpcbValue))
    rb_sys_fail("RegQueryValue");

  return kvalue;
}

// Helper function to expand tilde into full path
wchar_t* expand_tilde(){
  DWORD size = 0;
  wchar_t* home = NULL;
  const wchar_t* env = L"HOME";

  // First, try to get HOME environment variable
  size = GetEnvironmentVariableW(env, NULL, 0);

  // If that isn't found then try USERPROFILE
  if(!size){
    env = L"USERPROFILE"; 
    size = GetEnvironmentVariableW(env, home, size);
  }

  // If that still isn't found then raise an error
  if(!size){
    if (GetLastError() != ERROR_ENVVAR_NOT_FOUND)
      rb_sys_fail("GetEnvironmentVariable");
    else
      rb_raise(rb_eArgError, "couldn't find HOME environment -- expanding '~'");
  }

  home = (wchar_t*)ruby_xmalloc(MAX_PATH * sizeof(wchar_t));
  size = GetEnvironmentVariableW(env, home, size);

  if(!size){
    ruby_xfree(home);
    rb_sys_fail("GetEnvironmentVariable");
  }

  while(wcsstr(home, L"/"))
    home[wcscspn(home, L"/")] = L'\\';

  if (PathIsRelativeW(home))
    rb_raise(rb_eArgError, "non-absolute home");

  return home;
}

// My version of File.expand_path
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
    v_path_orig = rb_funcall(v_path_orig, rb_intern("to_path"), 0, NULL);

  SafeStringValue(v_path_orig);

  if (!NIL_P(v_dir_orig))
    SafeStringValue(v_dir_orig);

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
  
  rb_str_modify_expand(v_path, MAX_PATH);

  // Make our path a wide string for later functions
  length = MultiByteToWideChar(CP_UTF8, 0, RSTRING_PTR(v_path), -1, NULL, 0);
  path = (wchar_t*)ruby_xmalloc(MAX_PATH * sizeof(wchar_t));

  if(!MultiByteToWideChar(CP_UTF8, 0, RSTRING_PTR(v_path), -1, path, length)){
    ruby_xfree(path);
    rb_sys_fail("MultiByteToWideChar");
  }

  // Convert all forward slashes to backslashes to Windows API functions work properly
  while(wcsstr(path, L"/"))
    path[wcscspn(path, L"/")] = L'\\';

  // Handle ~ expansion.
  if (ptr = wcschr(path, L'~')){
    wchar_t* home;

    // Handle both ~/user and ~user syntax
    if (ptr[1] && ptr[1] != L'\\'){
      home = find_user(++ptr);
    }
    else{
      home = expand_tilde(path);

      if (!PathAppendW(home, ++ptr)){
        ruby_xfree(home);
        rb_sys_fail("PathAppend");
      }
    }

    path = home;
  }

  // Directory argument is present
  if (!NIL_P(v_dir_orig)){
    wchar_t* dir;
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

    rb_str_modify_expand(v_dir, MAX_PATH);

    length = MultiByteToWideChar(CP_UTF8, 0, RSTRING_PTR(v_dir), -1, NULL, 0);
    dir = (wchar_t*)ruby_xmalloc(MAX_PATH * sizeof(wchar_t));

    if (!MultiByteToWideChar(CP_UTF8, 0, RSTRING_PTR(v_dir), -1, dir, length)){
      ruby_xfree(dir);
      rb_sys_fail("MultiByteToWideChar");
    }

    while (wcsstr(dir, L"/"))
      dir[wcscspn(dir, L"/")] = L'\\';

    if (ptr = wcschr(dir, L'~')){
      if (ptr[1] && ptr[1] != L'\\'){
        ptr[wcscspn(ptr, L"\\")] = 0; // Only read up to slash
        rb_raise(rb_eArgError, "can't find user %ls", ++ptr);
      }

      dir = expand_tilde();

      if (!PathAppendW(dir, ++ptr)){
        ruby_xfree(dir);
        rb_sys_fail("PathAppend");
      }
    }

    if (!wcslen(path))
      path = dir;

    if (PathIsRelativeW(path)){ 
      if(!PathAppendW(dir, path)){
        ruby_xfree(dir);
        rb_sys_fail("PathAppend");
      }

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
        rb_sys_fail("GetCurrentDirectory");
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
        rb_sys_fail("WideCharToMultiByte");
      }

      return rb_str_new2(pwd);
    }
  }

  // Strip all trailing backslashes
  while (!*PathRemoveBackslashW(path));

  // First call, get the length
  length = GetFullPathNameW(path, 0, buffer, NULL);
  buffer = (wchar_t*)ruby_xmalloc(length * sizeof(wchar_t));

  // Now get the path
  length = GetFullPathNameW(path, length, buffer, NULL);

  if (!length){
    ruby_xfree(buffer);
    rb_sys_fail("GetFullPathName");
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
    rb_sys_fail("WideCharToMultiByte");
  }

  v_path = rb_str_new(final_path, length - 1); // Don't count null terminator

  if (rb_enc_to_index(path_encoding) != rb_utf8_encindex()){
    ec = rb_econv_open("UTF-8", rb_enc_name(path_encoding), replaceflags);
    v_path = rb_econv_str_convert(ec, v_path, ECONV_PARTIAL_INPUT);
    rb_econv_close(ec);    
  }

  rb_enc_associate(v_path, path_encoding);
  
  if (OBJ_TAINTED(v_path_orig) || rb_equal(v_path, v_path_orig) == Qfalse)
    OBJ_TAINT(v_path);

  return v_path;
}

void Init_xpath(){
  rb_define_singleton_method(rb_cFile, "xpath", rb_xpath, -1);
}
