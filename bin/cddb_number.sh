#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# ova-cddb_number: number tracks that match CDDB entry

. "@sysconfdir@/global.conf"
. "@datadir@/global"
load_config cddb.conf

usage()
{
  {
    echo "Usage: $(basename $0) [options] category discid directory"
    echo
    echo "Retrieves the disc data from the CDDB server, and adds tracknumbers"
    echo "to the tracks found in the given directory (if unambiguous)."
    general_help
    echo -e "  -n, --dry-run\t\tdon't add any tracknumbers, just print them"
  } >&4
  exit 2
}

test $# -eq 0 && usage

category=
discid=

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
    -n|--dry-run)
      dry_run=yes
    ;;
    --)
      end_options=yes
    ;;
    -*)
      echo "unrecognized option \"$1\"" >&4
      exit 1
    ;;
    *)
      if test -z "$category"; then
        category="$1"
      else
        if test -z "$discid"; then
          discid="$1"
        else
          if test -z "$dir"; then
            dir="$1"
          else
            echo "Directory has already been specified." >&4
            exit 1
          fi
        fi
      fi
    ;;
  esac

  shift
  test "$end_options" = yes && break
done

if test "$end_options" = yes; then
  while test $# -gt 0; do
    if test -z "$category"; then
      category="$1"
    else
      if test -z "$discid"; then
        discid="$1"
      else
        if test -z "$dir"; then
          dir="$1"
        else
          echo "Directory has already been specified." >&4
          exit 1
        fi
      fi
    fi
    shift
  done
fi

test -z "$dir" && usage

trap 'show_cursor; exit 1' int hup quit term
hide_cursor
if ! cddb_read_process "$category $discid" /tmp/ova-cddb_number.read_raw.$$ \
  /tmp/ova-cddb_number.read.$$ >&4; then
:
  rm -f /tmp/ova-cddb_number.*.$$
  show_cursor
  exit 1
fi
echo done >&4

echo -n "reading track title list: " >&4
heartbeat_init
track_count=0
while read line; do
  heartbeat
  echo "$line" | grep '^ttitle' >/dev/null || continue
  left=$(echo "$line" | cut -d= -f1 | sed 's/ttitle//')
  right=$(echo "$line" | cut -d= -f2- | dd conv=lcase 2>/dev/null | sed 's/[^[:alnum:]]//g')
  isint "$left" || continue
  let ++left
  ttitle[$left]=$right
  ttitle_display[$left]=$(echo "$line" | cut -d= -f2-)
  let ++track_count
done </tmp/ova-cddb_number.read.$$
echo done >&4

echo -n "listing tracks: " >&4
find "$dir" -maxdepth 1 -regex ".*\.\(ogg\|mp3\|wav\)" >/tmp/ova-cddb_number.list.$$
file_count=0
while read file; do
  files[$file_count]="$file"
  cmp_files[$file_count]=$(basename "$file" | dd conv=lcase 2>/dev/null |
    sed -e 's/\.[^.]*$//' -e 's/^[[(]*[0-9]\{1,\}[])]*[._-]//' -e 's/[^[:alnum:]]//g')
  let ++file_count
done </tmp/ova-cddb_number.list.$$
echo -e "done\n" >&4
show_cursor
trap int hup quit term

match_count=0
for ((i=1; i<=track_count; ++i)); do
  echo -e "track $CL1$(zeropad $i 2)$RST: ${ttitle_display[$i]}"
  match=0
  for ((j=0; j<file_count; ++j)); do
    file="${files[$j]}"
    file_cmp="${cmp_files[$j]}"
    if test "$file_cmp" -a "${ttitle[$i]}" = "$file_cmp"; then
      if test "$dry_run" != yes; then
        target_file="$(zeropad $i 2)-$(basename "$file" | sed -e 's/^[[(]*[0-9]\{1,\}[])]*[._-]//')"
        mv -f "$file" "$(dirname "file")/$target_file" 2>/dev/null
        tag_file="$(echo "$file" | sed 's/\.[^.]*$/.tag~/')"
        target_tag_file="$(echo "$target_file" | sed 's/\.[^.]*$/.tag~/')"
        mv -f "$tag_file" "$(dirname "tag_file")/$target_tag_file" 2>/dev/null
      fi
      echo -e "  $CL2$(basename "$file")$RST"
      files[$j]=
      cmp_files[$j]=
      match=1
      break
    fi
  done
  test $match -eq 0 && echo "  -"
  let match_count+=match
done
if test $file_count -ne $match_count; then
  echo >&4
  echo "unmatched files:" >&4
  for ((j=0; j<file_count; ++j)); do
    test -z "${files[$j]}" && continue
    echo -e "  $CL2$(basename "${files[$j]}")$RST" >&4
  done
fi
echo -e "\n$CL1$match_count$RST/$CL1$track_count$RST $(noun_form track $track_count) from this CD $(verb_have_form $match_count) been matched" >&4
echo -e "$CL1$match_count$RST/$CL1$file_count$RST $(noun_form track $file_count) from this dir $(verb_have_form $match_count) been matched" >&4

rm -f /tmp/ova-cddb_number.*.$$
cleanup_errorlog
