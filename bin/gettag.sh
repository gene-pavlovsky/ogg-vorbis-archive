#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# ova-gettag: get info from audio file's tag and/or pathname

. "@sysconfdir@/global.conf"
. "@datadir@/global"
load_config music.conf

usage()
{
  {
    echo "Usage: $(basename $0) [options] file"
    echo
    echo "Generates the tag file for the given audio file."
    general_help
    echo -e "  -t, --tag-only\tonly extract information from file's tag"
    echo -e "  -p, --path-only\tonly guess information from file's pathname"
  } >&4
  exit 2
}

test $# -eq 0 && usage

end_options=
use_only_strat=
while test $# -gt 0; do
  case $1 in
    --*=*)
      optarg=$(echo "$1" | sed 's/[-_a-zA-Z0-9]*=//')
    ;;
    *)
      optarg=
    ;;
  esac

  case $1 in
    --help)
      usage
    ;;
    --version)
      echo "@project@ @version@" >&4
      exit 2
    ;;
    -t|--tag-only)
      use_only_strat=tag
    ;;
    -p|--path-only)
      use_only_strat=path
    ;;
    --)
      end_options=yes
    ;;
    -*)
      echo "unrecognized option \"$1\"." >&4
      exit 1
    ;;
    *)
      file="$1"
    ;;
  esac

  shift
  test "$end_options" = yes && break
done

test "$end_options" = yes && file="$1"

tag_file=$(echo "$file" | sed 's/\.[^.]*$/.tag~/')

if test -z "$use_only_strat" -o "$use_only_strat" = tag; then
  ext=$(echo "$file" | sed 's/.*\.\([^.]*\)\|.*/\1/')
  if test "$ext" = wav; then
    tag_title=
    tag_artist=
    tag_album=
    tag_date=
    tag_genre=
    tag_comment=
    tag_tracknumber=
    outputvars "$tag_file" \' tag_{title,artist,album,date,genre,comment,tracknumber}
  else
    if ! test -x "@bindir@/ova-gettag_$ext"; then
      echo "File: $file" >&4
      echo "Unsupported media file extension: ${ext:-''}" >&4
      for i in "@bindir@/ova-gettag_"*; do
        c_ext=$(echo "$i" | sed 's/.*_\([^.]*\)$/\1/')
        test -z "$supported" && supported="$c_ext" || supported="$supported $c_ext"
      done
      echo "Only the following file extensions are supported: $supported" >&4
      echo "Sorry, no content-based file type auto-detection." >&4
      exit 1
    fi
    "@bindir@/ova-gettag_$ext" "$file"
  fi
  get_playlength "$file"
  echo "playlength=$playlength" >>"$tag_file"
fi

if test -z "$use_only_strat" -o "$use_only_strat" = path; then
  path_name=$(stripprefix "$file" "$music_incoming" | sed -e 's/\.[^.]*$//' -e 'y/ /_/' \
    -e 's/_\{2,\}/_/g' -e 's/_-_/-/g' -e "s/'/'\\\\''/g" | dd conv=lcase 2>/dev/null)
  outputvars "$tag_file" \' path_name
fi
cleanup_errorlog
