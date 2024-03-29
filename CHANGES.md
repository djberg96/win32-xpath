## 1.2.0 - 9-Jul-2022
* Convert tests from test-unit to rspec, and update gemspec and Rakefile accordingly.

## 1.1.2 - 8-Aug-2021
* The relative path directory argument now accepts anything that responds
  to the to_path method.
* Now skips taint checking tests on Ruby 2.7+
* Added a .gitignore file.

## 1.1.1 - 3-Mar-2019
* Switched RSTRING_PTR to StringValueCStr internally because apparently I
  I didn't get the memo on null termination changes.
* Fixed a warning caused by rb_funcall by switching it to rb_funcall2.
* Fixed a bug where it would try to expand tildes for paths in 8.3 format.
  Now tildes are only expanded if they are the first character in the path.
* Updated the cert.
* Updated the appveyor file to include Ruby 2.3, 2.4 and 2.5.
* Added a win32-xpath.rb file for convenience.

## 1.1.0 - 11-Jun-2016
* Changed license to Apache 2.0.
* Use PathCchXXX functions wherever I could that had not already been
  put into place.
* Removed the "futzing" directory and contents.
* Added an appveyor.yml file.

## 1.0.4 - 26-Nov-2015
* This gem is now signed.

## 1.0.3 - 3-Jul-2015
* Use PathCchXXX functions where available to improve long path handling.

## 1.0.2 - 17-Jun-2015
* Deal with non-standard swprintf issues so that it works with mingw compiler.

## 1.0.1 - 2-Apr-2015
* Altered internal handling of native C function failures.

## 1.0.0 - 26-Feb-2015
* Initial release
