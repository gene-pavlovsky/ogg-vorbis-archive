#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# ova-lint: check for files without tags, missing tracks in the middle of albums

. "@sysconfdir@/global.conf"
. "@datadir@/global"
load_config music.conf

usage()
{
  {
    echo "Usage: $(basename $0) [options] directory"
    echo
    echo "Checks for files without tags, missing tracks in the middle of albums."
    general_help
    echo -e "  -n, --no-tags\t\tdon't check for missing tags"
  } >&4
  exit 2
}

test $# -eq 0 && usage

end_options=
no_tags=
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
    -n|--no-tags)
      no_tags=yes
    ;;
    --)
      end_options=yes
    ;;
    -*)
      echo "unrecognized option \"$1\"." >&4
      exit 1
    ;;
    *)
      dir="$1"
    ;;
  esac

  shift
  test "$end_options" = yes && break
done

test "$end_options" = yes && dir="$1"

trap 'rm -f /tmp/ova-lint.*.$$; exit 1' int hup quit term
echo -n "listing dirs... " >&4
find "$dir" -type d 2>/dev/null | sort >/tmp/ova-lint.dir_list.$$
echo 'done' >&4
dir_count=$(wc -l /tmp/ova-lint.dir_list.$$ | sed 's/^ *\([0-9]*\).*/\1/')
dir_current=1
isatty 1 && tty=1 || tty=
while read dir; do
  test $dir_current -eq 1 && echo >&4
  echo -ne "\rchecking dir: $CL1$(zeropad $dir_current ${#dir_count})$RST/$CL1$dir_count$RST" >&4
  test_dir=$(stripprefix "$(canonizepath "$dir" "$(pwd)")" "$music_root")
  if test "$test_dir" = 'misc'; then
    misc="misc"
  elif echo "$test_dir" | grep '^[^/]*/misc$' &>/dev/null; then
    misc="genre-misc"
  else
    misc=no
  fi
  find "$dir" -maxdepth 1 -type f -name "*.ogg" 2>/dev/null |
    sort >/tmp/ova-lint.file_list.$$
  dir_out=

  tracks_missing=
  if test "$misc" = no; then
    last=0
    while read file; do
      base=$(basename "$file")
      tn="${base:0:2}"
      if ! isint "$tn"; then
        tracks_missing="failed to recognize track number in '$file'"
        break
      fi
      let tn="10#$tn"
      if test $((tn-last)) -gt 2; then
        test -z "$tracks_missing" &&
          tracks_missing="$CL1$(zeropad $((last+1)) 2)$RST-$CL1$(zeropad $((tn-1)) 2)$RST" ||
          tracks_missing="$tracks_missing $CL1$(zeropad $((last+1)) 2)$RST-$CL1$(zeropad $((tn-1)) 2)$RST"
      elif test $((tn-last)) -eq 2; then
        test -z "$tracks_missing" &&
          tracks_missing="$CL1$(zeropad $((last+1)) 2)$RST" ||
          tracks_missing="$tracks_missing $CL1$(zeropad $((last+1)) 2)$RST"
      fi
      last=$tn
    done </tmp/ova-lint.file_list.$$
  fi
  if test "$tracks_missing"; then
    test "$tty" && echo -e "\r\033[K$CL2$dir$RST:" || echo "$dir"
    dir_out=1
    echo -e "  missing tracks: $tracks_missing"
  fi

  if test -z "$no_tags"; then
    if test "$misc" = "misc"; then
      tags_rq="title artist REPLAYGAIN_TRACK_GAIN REPLAYGAIN_TRACK_PEAK"
    elif test "$misc" = "genre-misc"; then
      tags_rq="title artist genre REPLAYGAIN_TRACK_GAIN REPLAYGAIN_TRACK_PEAK"
    else
      tags_rq="title artist album date genre tracknumber REPLAYGAIN_TRACK_GAIN REPLAYGAIN_TRACK_PEAK REPLAYGAIN_ALBUM_GAIN REPLAYGAIN_ALBUM_PEAK"
    fi
    while read file; do
      title=
      artist=
      album=
      date=
      genre=
      tracknumber=
      REPLAYGAIN_TRACK_GAIN=
      REPLAYGAIN_TRACK_PEAK=
      REPLAYGAIN_ALBUM_GAIN=
      REPLAYGAIN_ALBUM_PEAK=
      tags_missing=
      tag_file=$(echo "$file" | sed 's/\.[^.]*$/.tag~/')
      grep '^tag_' "$tag_file" &>/dev/null || "@bindir@/ova-gettag_ogg" "$file"
      if test ! -f "$tag_file"; then
        tags_missing="failed to get tag"
      else
        . "$tag_file"
        rm -f "$tag_file"
        for i in $tags_rq; do
          value_in_colonlist "$i" "title:artist:album:date:genre:tracknumber" &&
            j="tag_$i" || j="$i"
          if test -z "${!j}"; then
            test -z "$tags_missing" &&
              tags_missing="$i" ||
              tags_missing="$tags_missing $i"
          fi
        done
      fi
      if test "$tags_missing"; then
        if test -z "$dir_out"; then
          test "$tty" && echo -e "\r\033[K$CL2$dir$RST:" || echo "$dir"
          dir_out=1
        fi
        echo -e "  missing tags: [$tags_missing] $CL2$(basename $file)$RST"
      fi
    done </tmp/ova-lint.file_list.$$
  fi

  let ++dir_current
done </tmp/ova-lint.dir_list.$$
test $dir_count -gt 0 -a -z "$dir_out" && echo >&4
rm -f /tmp/ova-lint.*.$$
cleanup_errorlog
