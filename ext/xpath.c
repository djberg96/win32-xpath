#include <ruby.h>
#include <windows.h>
#include <shlwapi.h>

#define BUFSIZE 4096

static VALUE rb_xpath(int argc, VALUE* argv, VALUE self){
  VALUE v_path, v_dir;
  char* path;
  char buffer[BUFSIZE] = "";
  int length;

  rb_scan_args(argc, argv, "11", &v_path, &v_dir);

  if (rb_respond_to(v_path, rb_intern("to_path")))
    v_path = rb_funcall(v_path, rb_intern("to_path"), 0, NULL);

  Check_Type(v_path, T_STRING);

  if (!NIL_P(v_dir))
    Check_Type(v_dir, T_STRING);

  v_path = rb_funcall(v_path, rb_intern("tr"), 2, rb_str_new2("/"), rb_str_new2("\\"));

  path = StringValuePtr(v_path);

  while (!*PathRemoveBackslash(path));

  length = GetFullPathName(path, BUFSIZE, buffer, NULL);

  if (length > sizeof(buffer)){
    realloc(buffer, length);
    length = GetFullPathName(path, sizeof(buffer), buffer, NULL);
  }

  if (!length)
    rb_sys_fail("GetFullPathName");

  v_path = rb_str_new2(buffer);

  return v_path;
}

void Init_xpath(){
  rb_define_singleton_method(rb_cFile, "xpath", rb_xpath, -1);
}
