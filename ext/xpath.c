#include <ruby.h>
#include <windows.h>
#include <shlwapi.h>

static VALUE rb_xpath(int argc, VALUE* argv, VALUE self){
  VALUE v_path, v_dir;
  char* path = NULL;
  char* buffer = NULL;
  int length;
  char* ptr;

  rb_scan_args(argc, argv, "11", &v_path, &v_dir);

  if (rb_respond_to(v_path, rb_intern("to_path")))
    v_path = rb_funcall(v_path, rb_intern("to_path"), 0, NULL);

  SafeStringValue(v_path);

  if (!NIL_P(v_dir))
    SafeStringValue(v_dir);

  path = StringValuePtr(v_path);

  // Convert all forward slashes to backslashes to Windows API functions work properly
  while(strstr(path, "/"))
    path[strcspn(path, "/")] = '\\';

  // Handle ~ expansion
  if (ptr = strchr(path, '~')){
    VALUE v_home, v_regex, v_regex_str, v_capture;

    char* home = getenv("HOME");

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

  if (!NIL_P(v_dir)){
    if (!strlen(path))
      return v_dir;

    if (PathIsRelative(path)){
      char* dir = StringValuePtr(v_dir);

      if(!PathAppend(dir, path))
        rb_sys_fail("PathAppend");

      path = dir;
    }
  }
  else{
    if (!strlen(path)){
      char* pwd = NULL;

      // First call, get the length
      length = GetCurrentDirectory(0, NULL);
      pwd = (char*)malloc(length);

      if (!pwd)
        rb_sys_fail("malloc");

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
  buffer = (char*)malloc(length);

  if (!buffer)
    rb_sys_fail("malloc");

  // Now get the path
  length = GetFullPathName(path, length, buffer, NULL);

  if (!length)
    rb_sys_fail("GetFullPathName");

  // Convert backslashes into forward slashes
  while(strstr(buffer, "\\"))
    buffer[strcspn(buffer, "\\")] = '/';

  v_path = rb_str_new(buffer, length);

  OBJ_TAINT(v_path);

  return v_path;
}

void Init_xpath(){
  rb_define_singleton_method(rb_cFile, "xpath", rb_xpath, -1);
}
