#include <ruby.h>
#include <windows.h>
#include <shlwapi.h>

#define BUFSIZE 1024

static VALUE rb_xpath(int argc, VALUE* argv, VALUE self){
  VALUE v_path, v_dir;
  char* path = NULL;
  char* buffer = NULL;
  int length;

  rb_scan_args(argc, argv, "11", &v_path, &v_dir);

  if (rb_respond_to(v_path, rb_intern("to_path")))
    v_path = rb_funcall(v_path, rb_intern("to_path"), 0, NULL);

  SafeStringValue(v_path);

  if (!NIL_P(v_dir))
    SafeStringValue(v_dir);

  // Convert all forward slashes to backslashes to Windows API functions work properly
  v_path = rb_funcall(v_path, rb_intern("tr"), 2, rb_str_new2("/"), rb_str_new2("\\"));
  path   = StringValuePtr(v_path);

  if (!NIL_P(v_dir)){
    if (!strlen(path))
      return v_dir;

    if (PathIsRelative(path)){
      v_path = rb_funcall(rb_cFile, rb_intern("join"), 2, v_dir, v_path);  
      path = StringValuePtr(v_path);
    }
  }
  else{
    if (!strlen(path))
      return rb_funcall(rb_cDir, rb_intern("pwd"), 0, NULL);
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
