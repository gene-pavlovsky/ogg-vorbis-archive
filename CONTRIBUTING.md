Notes for people wanting to take a look at the source

1. Debugging shell errors

All ova scripts execute the 'global' file from ova's datadir at
startup. Apart from many useful functions used everywhere through
ova scripts, it contains some important initialization:

  - fd 3 is redirected from standard input
  - fd 4 is redirected to standard error
  - fd 2 (standard error) is redirected to error log file if 'use_debug'
    in 'global.conf' is set to 'yes', and to /dev/null otherwise.

Error log files are kept in ova's datadir under log/error/ subdirectory.
Should there be any errors interpreting ova scripts or running the
commands they call, they'll be logged.

When the standard error output should appear on tty, it is redirected to
fd 4 (otherwise it would end up in log error file or /dev/null).
When the standard input should come from tty, it is redirected from
fd 3 (useful inside 'while ... done <some_file').
