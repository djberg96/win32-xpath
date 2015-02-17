#define UNICODE
#define _UNICODE

#include <ruby.h>
#include <windows.h>

static VALUE rb_xpath(int argc, VALUE* argv, VALUE self){
  VALUE v_path, v_dir;

  rb_scan_args(argc, argv, "11", &v_path, &v_dir);

  Check_Type(v_path, T_STRING);

  if(!NIL_P(v_dir))
    Check_Type(v_dir, T_STRING);

  return self;
}

void Init_xpath(){
  rb_define_singleton_method(rb_cFile, "xpath", rb_xpath, -1);
}
