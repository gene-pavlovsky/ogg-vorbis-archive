#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# ova-gettag_ogg: get Ogg Vorbis comments from an Ogg Vorbis file

. "@sysconfdir@/global.conf"
. "@datadir@/global"
load_config music.conf

usage()
{
  {
    echo "Usage: $(basename $0) file.ogg"
    echo
    echo "Generates the tag file for the given Ogg Vorbis file, containing the"
    echo "information read from the Ogg Vorbis comments."
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
for tag_line in $(vorbiscomment -l "$file" 2>/dev/null); do
  if value_in_colonlist "${tag_line:0:11}" "REPLAYGAIN_:replaygain_"; then
    tag_line=$(echo "$tag_line" | dd conv=ucase 2>/dev/null | sed 's/!//g')
    tag_name=$(echo "$tag_line" | sed 's/\([^=]*\)=.*/\1/')
    tag_value=$(echo "$tag_line" | sed -e 's/[^=]*=\(.*\)/\1/' -e "s/'/'\\\\''/g")
    test "$tag_name" && eval "$tag_name"='$tag_value'
  else
    tag_line=$(echo "$tag_line" | dd conv=lcase 2>/dev/null | sed 's/!//g')
    tag_name=$(echo "$tag_line" | sed 's/\([^=]*\)=.*/\1/')
    tag_value=$(echo "$tag_line" | sed -e 's/[^=]*=\(.*\)/\1/' -e "s/'/'\\\\''/g")
    test "$tag_name" && eval tag_"$tag_name"='$tag_value'
  fi
done
IFS="$old_IFS"

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
echo "format=ogg" >>"$tag_file"
echo "bitrate=$(ogginfo "$file" | grep "^[[:blank:]]*Average bitrate:" |
  sed 's/^[[:blank:]]*Average bitrate: *\([0-9]*\).*/\1/')" >>"$tag_file"
if test "$REPLAYGAIN_TRACK_PEAK" -a "$REPLAYGAIN_TRACK_GAIN"; then
  outputvars "$tag_file" \' REPLAYGAIN_TRACK_{PEAK,GAIN}
  test "$REPLAYGAIN_ALBUM_PEAK" -a "$REPLAYGAIN_ALBUM_GAIN" &&
    outputvars "$tag_file" \' REPLAYGAIN_ALBUM_{PEAK,GAIN}
fi
cleanup_errorlog
