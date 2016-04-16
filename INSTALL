If you had already installed ova, be sure to backup the existing
ova configuration files, because they will be overwritten upon
the installation of the new version.

Installation of ova is straightforward: as ova is written mostly
in shell, there is no configure script or makefile.

To install, run ./install
To uninstall, run ./uninstall

The install/uninstall script supports several configure-like options, you
can find them out by issuing a "./install --help" command.

Unfortunately, it wasn't possible to entirely refrain from using C, so
there're several really tiny C programs that have to be compiled. Install
script compiles and installs them. You might need to manually set the CC
and/or CFLAGS environment variables to correct values.

Patching vorbis-tools-1.0.1 used to be necessary, but now you should just
upgrade to vorbis-tools >= 1.1.1 or higher in order for ova to work.
Already released even longer ago, audiofile >= 0.2.5 and mp3tools >= 1.5
no longer need patching.

The ova scripts require:
  - standard UNIX commands: cat, cut, grep, sed, ls, mv, rf, wc - you name it
  - cd-discid (look for it on <http://www.freedb.org> in downloads section)
  - cdparanoia
  - mplayer (not strictly required)
  - mp3info (not strictly required) (mp3tools >= 1.5)
  - oggenc, ogginfo, vorbiscomment (vorbis-tools >= 1.1.1)
  - sfinfo (audiofile >= 0.2.5)
  - vorbisgain (not strictly required)
  - wget
  - cdb (not strictly required)
  - eject (optional)
  * something else? if you note something's missing, send me a message.
Most of this software can be found by searching <http://www.freshmeat.net>.
Note that mplayer and mp3info are not required if you don't want to
convert MP3 files to Ogg Vorbis. Also, you only need vorbisgain if
you want to use the 'calculate replay gain' action. The djb's cdb
(and cdbgetall - see below) is only needed if you want to use
ova-cddb_ibuild with indices (allows to search for CDDB albums
by artist or album name). NB: you don't need this if you just
want to use the CDDB.

The 'cdbgetall' program is included in binary form. It's sources are
available in the src/ subdirectory. If the binary cdbgetall doesn't
work for you, or you just want to have everything compiled yourself,
extract src/cdbgetall.tar.gz, run 'make' inside and place the compiled
'cdbgetall' binary to the bin/ subdirectory before installing ova itself.

For much better CDDB performance, you might want to install freedb
at your local site. Nov 2003 database is ~260 MiB in tar.bz2 format,
1.3 GiB when uncompressed into a filesystem which doesn't align
files by blocks (such as ReiserFS): more than 4 GiB otherwise!
I've done so and is very happy because I don't need to dial my ISP
each time I want to do a couple of hundreds queries / reads.
You can download the freedb server and database at <http://www.freedb.org>.
