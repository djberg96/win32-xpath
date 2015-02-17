#include <ruby.h>
#include <windows.h>
#include <shlwapi.h>

#define BUFSIZE 1024

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

  // Convert all forward slashes to backslashes to Windows API functions work properly
  v_path = rb_funcall(v_path, rb_intern("tr"), 2, rb_str_new2("/"), rb_str_new2("\\"));
  path   = StringValuePtr(v_path);

  // Handle ~ expansion
  if (ptr = strchr(path, '~')){
    VALUE v_home, v_regex, v_regex_str, v_capture;

    char* home = getenv("HOME");

    if (!home)
      home = getenv("USERPROFILE");

    if(!home)
      rb_raise(rb_eArgError, "couldn't find HOME environment -- expanding '~'");

    v_home = rb_funcall(rb_str_new2(home), rb_intern("tr"), 2, rb_str_new2("/"), rb_str_new2("\\"));
    home = StringValuePtr(v_home);

    if (PathIsRelative(home))
      rb_raise(rb_eArgError, "non-absolute home");

    if (ptr[1] != '\\'){
      ptr[strcspn(ptr, "\\")] = 0; // Only read up to slash
      ptr++; // Skip '~'
      rb_raise(rb_eArgError, "can't find user %s", ptr);
    }

  }

  if (!NIL_P(v_dir)){
    if (!strlen(path))
      return v_dir;

    if (PathIsRelative(path)){
      v_path = rb_funcall(rb_cFile, rb_intern("join"), 2, v_dir, v_path);  
      path = StringValuePtr(v_path);
    }
  }
  else{
    if (!strlen(path)){
      char* pwd = NULL;
      VALUE v_pwd;

      pwd = (char*)malloc(BUFSIZE);
      length = GetCurrentDirectory(BUFSIZE, pwd);

      if (length > BUFSIZE){
        pwd = (char*)realloc(pwd, length);

        if (!pwd)
          rb_sys_fail("realloc");

        length = GetCurrentDirectory(BUFSIZE, pwd);
      }

      if (!length)
        rb_sys_fail("GetCurrentDirectory");

      v_pwd = rb_funcall(rb_str_new2(pwd), rb_intern("tr"), 2, rb_str_new2("\\"), rb_str_new2("/"));
      free(pwd);
      return v_pwd;
    }
  }

  // Strip all trailing backslashes
  while (!*PathRemoveBackslash(path));

  buffer = (char*)malloc(BUFSIZE);
  length = GetFullPathName(path, BUFSIZE, buffer, NULL);

  // If buffer is too small, try again
  if (length > sizeof(buffer)){
    buffer = (char*)realloc(buffer, length);

    if (!buffer)
      rb_sys_fail("realloc");

    length = GetFullPathName(path, length, buffer, NULL);
  }

  if (!length)
    rb_sys_fail("GetFullPathName");

  v_path = rb_str_new2(buffer);
  v_path = rb_funcall(v_path, rb_intern("tr"), 2, rb_str_new2("\\"), rb_str_new2("/"));
  free(buffer);

  OBJ_TAINT(v_path);

  return v_path;
}

void Init_xpath(){
  rb_define_singleton_method(rb_cFile, "xpath", rb_xpath, -1);
}
