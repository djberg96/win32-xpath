require 'mkmf'

# Link required Windows libraries
$LDFLAGS += ' -lshlwapi -ladvapi32'

# Set compilation flags for Windows
$CFLAGS += ' -DUNICODE -D_UNICODE'

# Create the makefile
create_makefile('win32/xpath')
