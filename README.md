## Description
A custom `File.expand_path` method for Ruby on Windows that's much faster and works better.

## Installation
`gem install win32-xpath`

## Adding the Trusted Cert
`gem cert --add <(curl -Ls https://raw.githubusercontent.com/djberg96/win32-xpath/main/certs/djberg96_pub.pem)`

## Synopsis
```ruby
require 'win32/xpath'

# That's it, you are now using this library when you call File.expand_path
```

## Features
* A 5x average performance boost over MRI's current method.
* Support for ~user expansion.

## Known Issues
* This library does not support drive-current paths for the 2nd argument.
* This library does not support alt-stream name autocorrection.
* This library does not convert short paths to long paths.

It is very unlikely you will ever be affected by any of these things.
Drive-current paths are a relic of DOS 1.0, but even so this library
will handle them in the first argument.

I don't support alt-stream mangling because I don't believe it's the
job of this method to peform autocorrection. Even in MRI it only works
for the default $DATA stream, and then only for a certain type of
syntax error. I do not know when or why it was added.

Failure to convert short paths to long paths is irrelevant since that
has nothing to do with relative versus absolute paths.

One possible "real" issue is that on Windows 7 or earlier you will be
limited to 260 character paths. This is a limitation of the shlwapi.h
functions that I use internally.

If you discover any other issues, please report them on the project
page at https://github.com/djberg96/win32-xpath.

## Mingw and Devkit
Make sure you have a recent version of the Devkit installed if you're
using the one-click installer. If you see this warning then you need
to upgrade your Devkit.

`"implicit declaration of function 'ConvertSidToStringSidW'"`

## Acknowledgements
Park Heesob for encoding advice and help.

## License
Apache-2.0

## Copyright
(C) 2003-2022 Daniel J. Berger, All Rights Reserved
    
## Warranty
This package is provided "as is" and without any express or
implied warranties, including, without limitation, the implied
warranties of merchantability and fitness for a particular purpose.

## Author
Daniel Berger
