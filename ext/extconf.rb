require 'mkmf'
have_library('shlwapi')
have_library('advapi32')
create_makefile('xpath', 'win32')
