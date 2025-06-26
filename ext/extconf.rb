require 'mkmf'

have_library('shlwapi')
have_library('advapi32')
have_library('pathcch')

create_makefile('win32/xpath', 'win32')
