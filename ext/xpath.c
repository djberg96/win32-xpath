#include <ruby.h>
#include <windows.h>
#include <shlwapi.h>

static VALUE rb_xpath(int argc, VALUE* argv, VALUE self){
  VALUE v_path, v_path_orig, v_dir_orig;
  wchar_t* buffer = NULL;
  wchar_t* ptr = NULL;
  wchar_t* path = NULL;
  char* final_path;
  int length;

  rb_scan_args(argc, argv, "11", &v_path_orig, &v_dir_orig);

  if (rb_respond_to(v_path_orig, rb_intern("to_path")))
    v_path_orig = rb_funcall(v_path_orig, rb_intern("to_path"), 0, NULL);

  SafeStringValue(v_path_orig);

  if (!NIL_P(v_dir_orig))
    SafeStringValue(v_dir_orig);

  // Dup and prep string for modification
  v_path = rb_str_dup(v_path_orig);
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

  // Handle ~ expansion
  if (ptr = wcschr(path, L'~')){
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

    // If that still isn't found then raise an errro
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

    if (ptr[1] && ptr[1] != L'\\'){
      ptr[wcscspn(ptr, L"\\")] = 0; // Only read up to slash
      rb_raise(rb_eArgError, "can't find user %ls", ++ptr);
    }

    if (!PathAppendW(home, ++ptr)){
      ruby_xfree(home);
      rb_sys_fail("PathAppend");
    }

    path = home;
  }

  // Directory argument is present
  if (!NIL_P(v_dir_orig)){
    if (!wcslen(path))
      return v_dir_orig;

    if (PathIsRelativeW(path)){
      wchar_t* dir;
      VALUE v_dir = rb_str_dup(v_dir_orig);

      rb_str_modify_expand(v_dir, MAX_PATH);
  
      length = MultiByteToWideChar(CP_UTF8, 0, RSTRING_PTR(v_dir), -1, NULL, 0);
      dir = (wchar_t*)ruby_xmalloc(MAX_PATH * sizeof(wchar_t));

      if(!MultiByteToWideChar(CP_UTF8, 0, RSTRING_PTR(v_dir), -1, dir, length)){
        ruby_xfree(dir);
        rb_sys_fail("MultiByteToWideChar");
      }

      while(wcsstr(dir, L"/"))
        dir[wcscspn(dir, L"/")] = L'\\';

      if(!PathAppendW(dir, path))
        rb_sys_fail("PathAppend");

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

  if (!length){
    ruby_xfree(final_path);
    ruby_xfree(buffer);
    rb_sys_fail("WideCharToMultiByte");
  }

  v_path = rb_str_new(final_path, length - 1); // Don't count null terminator

  ruby_xfree(buffer);

  if (OBJ_TAINTED(v_path_orig) || rb_equal(v_path, v_path_orig) == Qfalse)
    OBJ_TAINT(v_path);

  return v_path;
}

void Init_xpath(){
  rb_define_singleton_method(rb_cFile, "xpath", rb_xpath, -1);
}
