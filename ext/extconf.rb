require 'mkmf'

have_library('shlwapi')
have_library('advapi32')

# Windows 8 or later
if have_library('pathcch')
  if have_header('pathcch.h')
    have_func('PathCchAppendEx', 'pathcch.h')
  end
end

create_makefile('win32/xpath', 'win32')
