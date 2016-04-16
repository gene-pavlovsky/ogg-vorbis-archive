1.3.0 on Mon, 26 Sep 2005 15:16:29 +0400
  NEW: bin/hardlink.sh
  bin/hardlink.sh: Makes hard links for an album / all albums.
  ova: Support for user configuration files ($HOME/.ova/*.conf), as
    requested by my SO.
  bin/sed.sh: Added "-a|--add=STRING" option (allows to add STRING
    to file's comments.
  bin/sed.sh: Added support for processing multiple files.
  bin/sed.sh: When output is a tty, mark changed files with '*'.
  bin/sed.sh: When output is a tty, apply sed script(s) to filename,
    if it's changed, move the old file to the new filename.
  bin/main.sh: Log splitted tracks in @datadir@/log/ova.tracksplit.
  bin/*.sh: Delete empty error log files on clean exit.
  share/global: Removed sed + utf-8 locale workaround (it caused
    more troubles than good).
  bin/*.sh, share/global: Use stat instead of "ls|..." to determine
    files' size.
  bin/main.sh: Fixed some minor bugs (with 'misc' detection).
  README: Updated docs.

1.2.0 on Mon, 29 Aug 2005 12:27:36 +0400
  ova: Support for CDDB protocol level 6 (database entries
    are now in UTF-8)
  ova: use MPlayer-1.0pre7 option "-ao pcm:file=FILENAME"
  ova: use "-n" option together with head and tail
  install: don't overwrite existing configuration files: instead,
    install new files (if changed) to $name.conf.new.
  INSTALL: vorbis-tools >= 1.1.1 is required; patching is no
    longer necessary.
  INSTALL: audiofile >= 0.2.5 is required; patching is no
    longer necessary.
  INSTALL: mp3tools >= 1.5 is required; patching is no
    longer necessary.
  INSTALL: Requirement for djb's cdb.
  NEW: src/cdbgetall.tar.gz/README
  bin/gettag_ogg.sh, bin/main.sh: Use existing REPLAYGAIN
    tags from Ogg Vorbis files if present.
  bin/main.sh: Consequently, the vorbisgain action applies
    to files in 'incoming' as well (it was pruned before
    because the tags would have been deleted on tag&relocate).
  bin/main.sh: Sort dirlisting in identify, reverse-sort
    dirlisting in tag&relocate (reverse because deep-to-shallow
    directory order is needed), sort dirlisting in replaygain.
  NEW: bin/sed.sh
  bin/sed.sh: Processes a given .ogg file's comments with sed.
  NEW: bin/lint.sh
  bin/lint.sh: Checks for files with missing tags and for
    missing tracks in the middle of albums.
  NEW: bin/cue2offsets.sh
  bin/cue2offsets.sh: Converts a cue sheet to offsets file
    readable by tracksplit.
  src/tracksplit.c: Seek to the first offset in the input
    file instead of the beginning of this file.
  src/tracksplit.c: Added '--seek=FRAMES' option. If it's
    given, it's argument is used instead of the first offset
    for seeking in the input file.
  bin/main.sh: Use tracksplit with '--seek=0' option.
  README: Added description for ova-lint. Compound actions
    ending with 'v' documented. Added descriptions for
    ova-cue2offsets, ova-sed.
  etc/main.conf: Automatically disable use_eject if the
    'eject' command is not found in PATH.

1.1.6 on Wed, 24 Dec 2003 22:59:05 +0300
  bin/main.sh: identify: Don't output short GPL notice when
    editing info in the EDITOR (it's irrelevant there).
  etc/global.conf: enable_debug is set to no by default for
    I believe that ova is stable enough for this.
  bin/main.sh: encode: Handle QUIT as abort when current
    jobs finish. Also, do nothing if queue is already empty.
  bin/main.sh: encode: Display total decoded/encoded
    playlength progress.
  bin/main.sh: rip: Correct detecting of already ripped,
    encoded, identified and tagged&relocated tracks.
  bin/main.sh: Added compound actions ending with 'v'.
  bin/main.sh: Change CD discid list in tag&relocate. This
    feature is very important, but was forgotten until now.
  bin/main.sh: identify: EDITOR editing: don't output
    copyright information and single quote example.
  bin/main.sh: tag_relocate: Change leading dots to 'dot-'.
  bin/main.sh: Added '4v' compound action.

1.1.5 on Sat, 20 Dec 2003 15:59:13 +0300
  bin/main.sh: encode: Delete '.decoding', '.encoding' and
    '.error' files on user abort.
  bin/main.sh: encode: Finish current jobs and quit upon
    receiving the QUIT signal.
  bin/conv.sh, bin/main.sh: Validate only decoding (assume
    encoding can't fail).
  bin/main.sh: identify: leave only track_artist, track_title
    and (if present) genre for 'misc' directories.
  etc/music.conf: track_path_pattern: Pattern for misc.
    Slightly changed other patterns (allow for empty artist).
  bin/main.sh: encode: Fixed multiple enqueueing.
  bin/main.sh, bin/cddb_number.sh: Better tracknumber matching.

1.1.4 on Tue, 16 Dec 2003 01:22:26 +0300
  bin/main.sh: encode: Continue on errors; report them in
    the error log file and barf at encoding completion.
  bin/main.sh: encode: Fixed total progress overflowing when
    encoding a large number of tracks (will still overflow
    if the number is sufficiently large, but it's unlikely
    that your HDD is big enough for this to happen ;).
  bin/main.sh: encode: Skip MP3s for which playlength
    couldn't be determined (probably broken headers).
  bin/conv.sh: Do sync after decoding and encoding.
  share/global: Fixed stripspaces.
  bin/main.sh: encode: Don't use '.status' and '.progress'
    files, use '.decoding' and '.encoding' instead.

1.1.3 on Sun, 14 Dec 2003 03:35:56 +0300
  bin/main.sh: split_tracks: Create output directory right
    after reading the CDDB category and discid.
  src/tracksplit.c: Fixed bug with improper rounding of the
    file size fractional part when displaying information.
  NEWS: Edited comment regarding bin/gettag_ogg.sh in 1.1.2.
  README: Cosmetic changes, synced main features from webpage.

1.1.2 on Sat, 13 Dec 2003 15:37:50 +0300
  bin/cddb_ibuild.sh: Workaround for one kind of CDDB entries
    that clearly violate CDDB entry format specification, but
    nevertheless are present in the latest freedb.
  bin/gettag_ogg.sh: Get average bitrate instead of nominal.
    I'm still not absolutely sure which one should be taken.
    It's not used anywhere currently, so it's no big deal.
  src/cr2lf.c, src/lf0.c: Workaround for getchar returning EOF
    when it encounters non-ASCII symbols.

1.1.1 on Fri, 12 Dec 2003 02:57:44 +0300
  bin/main.sh, bin/conv.sh: Fixed bugs introduced lately by the
    playlength caching feature.
  bin/main.sh: identify: Fixed bug that forcing 'various' to
    'no' wasn't working.
  src/cr2lf.c, src/lf0.c: Speed improvements.

1.1.0 on Wed, 10 Dec 2003 21:03:33 +0300
  bin/main.sh: Added 'calculate replay gain' action. In other
    words, vorbisgain support.
  bin/main.sh: Fixed bugs with arithmetic evaluation of constants
    with leading '0' (shell interprets them as octal). Probably
    there're more places where this can happen; please report.
  bin/main.sh, src/tracksplit.c: A couple of cosmetic changes
    to the display of progress information.

1.0.2 on Mon, 08 Dec 2003 00:23:17 +0300
  NOTE: The first public release.
  bin/main.sh: identify, tag_relocate: Handle 'misc' directories.
  bin/main.sh: rip: Cache the list of ripped CDs (discid list).
  bin/main.sh: New action: 'cd' - cleanup discid list.
  bin/gettag_mp3.sh, bin/gettag_ogg.sh: Fixed a bug with shell
    misinterpreting '!' when reading tags.

1.0.1 on Sun, 07 Dec 2003 15:25:37 +0300
  bin/main.sh: re/encode: Files disappeared after start-up will not
    yield an error. The progress/eta will become wrong, though.
  bin/main.sh: re/encode: More accurate eta calculation.
  bin/main.sh: re/encode: Display progress information when
    calculating total playlength.
  bin/cddb_number.sh: Also prepend numbers to '.tag~' files.
  bin/main.sh: identify: Allow for arbitrary disc# (non-integer).
  bin/main.sh: tag_relocate: Fixed a very nasty bug when yet
    unidentified albums were moved to stale destination directory.

1.0.0 on Sat, 07 Dec 2003 02:21:53 +0300
  NEW: dist
  README: Proper documentation.
  INSTALL: Required software list.

0.13.3 on Sat, 06 Dec 2003 02:43:00 +0300
  bin/main.sh: Separate action for 'split tracks'.

0.13.2 on Fri, 05 Dec 2003 17:20:00 +0300
  bin/main.sh: identify_cddb: Improved separation of CDDB TTITLEs
    in 'various artists' albums to track_artist and track_title.
  bin/main.sh: Better support for tracks with non-consecutive
    track numbers in partial albums.

0.13.1 on Fri, 05 Dec 2003 15:05:37 +0300
  bin/main.sh: Detect errors in interpreting the edited info
    file when using 'edit the info in the editor'.
  bin/main.sh: Cleanup error log files in 'cleanup stale files'.
  NEW: src/lf0.c

0.13.0 on Thu, 04 Dec 2003 23:19:10 +0300
  bin/main.sh: Submission of the CDDB entries, with deferral.
  bin/cddb_query.sh: Fixed a little disc length miscalculation
    that occured when using '--offsets'.

0.12.1 on Wed, 03 Dec 2003 22:49:40 +0300
  bin/cddb_query.sh: Printing of various information using
    '--print-offsets', '--print-length', '--print-tracks'.
    These options are the same as bin/cddb_read.sh has.
  bin/cddb_query.sh: Track frame offsets can be specified
    instead of a list of audio files using '--offsets'.
  bin/main.sh: identify_cddb: Action to force 'various artists'
    to 'yes' or 'no' (as well as the default 'auto').

0.12.0 on Sun, 30 Nov 2003 03:05:24 +0300
  bin/cddb_match.sh: Track title matching using '--ttitle'.
  bin/cddb_match.sh: Disc info displaying using '--print-info'.
  bin/cddb_isearch.sh: Searching in the dtitle database using '--dtitle'.
    This search just greps the database, which is painfully slow.

0.11.3 on Fri, 28 Nov 2003 02:16:06 +0300
  bin/cddb_isearch.sh: Secondary matching album for artist searches,
    artist for album searches using '--with-artist', '--with-album'.

0.11.2 on Wed, 26 Nov 2003 00:47:19 +0300
  bin/cddb_ibuild.sh: Made artist entries inexact like albums.
  bin/cddb_isearch.sh: Use the new format of artist index.
  NEW: src/isatty.c
  bin/cddb_isearch.sh: Colorize output if stdin is a terminal.

0.11.1 on Tue, 25 Nov 2003 05:05:59 +0300
  bin/cddb_read.sh: '--print-length' option: account for CDDB entries with
    'Disc length: [0-9]* secs' (though they don't conform to CDDB format).

0.11.0 on Tue, 25 Nov 2003 02:57:06 +0300
  NEW: bin/cddb_match.sh
  NEW: bin/cddb_number.sh
  bin/cddb_read.sh: Added '--print-length' option.

0.10.8 on Mon, 24 Nov 2003 16:38:59 +0300
  NEW: NEWS
  NEWS: At last I've decided to create the NEWS file. From
    now on I'll be logging all the important changes here.
