#include <ruby.h>
#include <tchar.h>
#include <windows.h>
#include <shlwapi.h>

static VALUE rb_xpath(int argc, VALUE* argv, VALUE self){
  VALUE v_path, v_path_orig, v_dir_orig;
  TCHAR* path = NULL;
  TCHAR* buffer = NULL;
  TCHAR* ptr;
  int length;

  rb_scan_args(argc, argv, "11", &v_path_orig, &v_dir_orig);

  if (rb_respond_to(v_path_orig, rb_intern("to_path")))
    v_path_orig = rb_funcall(v_path_orig, rb_intern("to_path"), 0, NULL);

  SafeStringValue(v_path_orig);

  if (!NIL_P(v_dir_orig))
    SafeStringValue(v_dir_orig);

  v_path = rb_str_dup(v_path_orig);
  rb_str_modify_expand(v_path, MAX_PATH);
  path = StringValuePtr(v_path);

  // Convert all forward slashes to backslashes to Windows API functions work properly
  while(strstr(path, "/"))
    path[strcspn(path, "/")] = '\\';

  // Handle ~ expansion
  if (ptr = strchr(path, '~')){
    TCHAR* home = getenv("HOME");

    if (!home)
      home = getenv("USERPROFILE");

    if(!home)
      rb_raise(rb_eArgError, "couldn't find HOME environment -- expanding '~'");

    while(strstr(home, "/"))
      home[strcspn(home, "/")] = '\\';

    if (PathIsRelative(home))
      rb_raise(rb_eArgError, "non-absolute home");

    if (ptr[1] && ptr[1] != '\\'){
      ptr[strcspn(ptr, "\\")] = 0; // Only read up to slash
      rb_raise(rb_eArgError, "can't find user %s", ++ptr);
    }

    if (!PathAppend(home, ++ptr))
      rb_sys_fail("PathAppend");

    path = home;
  }

  // Directory argument is present
  if (!NIL_P(v_dir_orig)){
    if (!strlen(path))
      return v_dir_orig;

    if (PathIsRelative(path)){
      TCHAR* dir;
      VALUE v_dir = rb_str_dup(v_dir_orig);

      rb_str_modify_expand(v_dir, MAX_PATH);
      dir = StringValuePtr(v_dir);

      while(strstr(dir, "/"))
        dir[strcspn(dir, "/")] = '\\';

      if(!PathAppend(dir, path))
        rb_sys_fail("PathAppend");

      // Remove leading slashes from relative paths
      if (dir[0] == '\\')
        ++dir;

      path = dir;
    }
  }
  else{
    if (!strlen(path)){
      TCHAR* pwd = NULL;

      // First call, get the length
      length = GetCurrentDirectory(0, NULL);
      pwd = (TCHAR*)ruby_xmalloc(length);

      length = GetCurrentDirectory(length, pwd);

      if(!length)
        rb_sys_fail("GetCurrentDirectory");

      // Convert backslashes into forward slashes
      while(strstr(pwd, "\\"))
        pwd[strcspn(pwd, "\\")] = '/';

      return rb_str_new2(pwd);
    }
  }

  // Strip all trailing backslashes
  while (!*PathRemoveBackslash(path));

  // First call, get the length
  length = GetFullPathName(path, 0, buffer, NULL);
  buffer = (TCHAR*)ruby_xmalloc(length);

  // Now get the path
  length = GetFullPathName(path, length, buffer, NULL);

  if (!length)
    rb_sys_fail("GetFullPathName");

  // Convert backslashes into forward slashes
  while(strstr(buffer, "\\"))
    buffer[strcspn(buffer, "\\")] = '/';

  v_path = rb_str_new(buffer, length);

  if (OBJ_TAINTED(v_path_orig) || rb_equal(v_path, v_path_orig) == Qfalse)
    OBJ_TAINT(v_path);

  return v_path;
}

void Init_xpath(){
  rb_define_singleton_method(rb_cFile, "xpath", rb_xpath, -1);
}
