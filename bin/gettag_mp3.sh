#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# ova-gettag_mp3: get ID3 tag from a MP3 file

. "@sysconfdir@/global.conf"
. "@datadir@/global"
load_config music.conf

usage()
{
  {
    echo "Usage: $(basename $0) file.mp3"
    echo
    echo "Generates the tag file for the given MP3 file, containing the"
    echo "information read from the ID3v1/v2 tags."
    general_help
  } >&4
  exit 2
}

test $# -eq 0 && usage

end_options=
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
    --)
      end_options=yes
    ;;
    -*)
      echo "unrecognized option \"$1\"" >&4
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

old_IFS="$IFS"
IFS=$'\n'
for tag_line in $(mp3id3 "$file" 2>/dev/null); do
  tag_line=$(echo "$tag_line" | dd conv=lcase 2>/dev/null | sed 's/!//g')
  tag_name=$(echo "$tag_line" | sed 's/\([^:]*\):.*/\1/')
  tag_value=$(echo "$tag_line" | sed -e 's/[^:]*: *\(.*\)/\1/' -e "s/'/'\\\\''/g")
  test "$tag_name" && eval tag_"$tag_name"='$tag_value'
done
IFS="$old_IFS"

tag_title="$tag_songname"
tag_date="$tag_year"
tag_tracknumber="$tag_track"

if test -z "$tag_tracknumber"; then
  tag_tracknumber=$(echo "$tag_title" | sed 's/^[[(]*\([0-9]*\)[])]*[ _]*-.*\|.*/\1/')
  tag_title=$(echo "$tag_title" | sed 's/^[[(]*[0-9]*[])]*[ _]*-[ _]*//')
fi
isint "$tag_tracknumber" && test $tag_tracknumber -lt 10 && \
  test "${tag_tracknumber:0:1}" -ne 0 && tag_tracknumber=0$tag_tracknumber
conv_uscores2spaces tag_{title,artist,album,date,genre,comment,tracknumber}
stripspaces tag_{title,artist,album,date,genre,comment,tracknumber}

tag_file=$(echo "$file" | sed 's/\.[^.]*$/.tag~/')
outputvars "$tag_file" \' tag_{title,artist,album,date,genre,comment,tracknumber}
echo "format=mp3" >>"$tag_file"
echo "bitrate=$(mp3info "$file" | grep "^Bitrate:" | sed 's/^Bitrate: *\(.*\) */\1/')" >>"$tag_file"
cleanup_errorlog
