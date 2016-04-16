#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# ova-cddb_query: query the CDDB via HTTP

. "@sysconfdir@/global.conf"
. "@datadir@/global"
load_config cddb.conf

usage()
{
  {
    echo "Usage: $(basename $0) [options] file [file]..."
    echo "       $(basename $0) [options] discid|discid~"
    echo "       $(basename $0) [options] --filelist=FILE"
    echo "       $(basename $0) [options] --offsets=FILE"
    echo
    echo "Given a list of audio files, a discid or discid~ file, or a"
    echo "list of track frame offsets, queries the CDDB (via HTTP)."
    general_help
    echo -e "      --offsets=FILE\tread track frame offsets from FILE"
    echo -e "      --filelist=FILE\tread tracklist from FILE"
    echo -e "  -d, --print-discid\tprint full discid"
    echo -e "  -o, --print-offsets\tprint track frame offsets"
    echo -e "  -l, --print-length\tprint disc length"
    echo -e "  -t, --print-tracks\tprint track count"
  } >&4
  exit 2
}

export LC_ALL=POSIX # so it will not fail with incorrect non-ascii filenames

end_options=
file_list=
print=
files_count=0
offsets_count=0
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
    -d|--print-discid)
      print=discid
    ;;
    -o|--print-offsets)
      print=offsets
    ;;
    -l|--print-length)
      print=length
    ;;
    -t|--print-tracks)
      print=tracks
    ;;
    --offsets=*)
      offsets="$optarg"
    ;;
    --filelist=*)
      file_list="$optarg"
    ;;
    --)
      end_options=yes
    ;;
    -*)
      echo "unrecognized option \"$1\"" >&4
      exit 1
    ;;
    *)
      array_add files "$1"
    ;;
  esac

  shift
  test "$end_options" = yes && break
done

if test "$end_options" = yes; then
  while test $# -gt 0; do
    array_add files "$1"
    shift
  done
fi

array_load()
{
  declare line
  if test "$1" = -; then
    while read line; do
      array_add $2 "$line"
    done
  else
    if test ! -f "$1"; then
      echo "File '$1' is not readable." >&4
      exit 1
    fi
    while read line; do
      array_add $2 "$line"
    done <"$1"
  fi
}

if test "$file_list"; then
  array_load $file_list files
elif test "$offsets"; then
  array_load $offsets offsets
fi

test $files_count -eq 0 -a -z "$offsets" && usage

if test -z "$cddb_url"; then
  echo "CDDB usage is disabled." >&4
  exit 0
fi

total_msecs=2000
total_frames=150
track_offsets=$total_frames
index=0
total_id=0

if test $files_count -eq 1 -a "${files[0]}" && test "$(basename "${files[0]}")" = discid -o "$(basename "${files[0]}")" = discid~; then
  if test ! -f "${files[0]}"; then
    echo "File '${files[0]}' is not readable." >&4
    exit 1
  fi
  if test "$print" = discid; then
    cat "${files[0]}"
  elif test "$print" = offsets; then
    match_tracks=$(cat "${files[0]}" | cut -d' ' -f2)
    for i in $(cat "${files[0]}" | cut -d' ' -f3-$((match_tracks+2))); do
      echo $i
    done
  elif test "$print" = length; then
    match_tracks=$(cat "${files[0]}" | cut -d' ' -f2)
    cat "${files[0]}" | cut -d' ' -f$((match_tracks+3))
  elif test "$print" = tracks; then
    cat "${files[0]}" | cut -d' ' -f2
  else
    wget "$cddb_url?cmd=cddb+query+$(cat "${files[0]}" | sed 'y/ /+/')&hello=$cddb_hello&proto=6" \
      -O - 2>/dev/null | sed 's///g'
  fi
else
  if test "$print" = tracks; then
    echo $files_count
    exit 0
  fi
  test $files_count -gt 0 &&
    l_count=$files_count ||
    l_count=$((offsets_count-1))
  for ((f_i=0; f_i<l_count; ++f_i)); do
    if test $files_count -gt 0; then
      i="${files[$f_i]}"
      if test ! -f "$i"; then
        echo "File '$i' is not readable." >&4
        exit 1
      fi
    fi
    let current_id=0
    let cksum_secs=total_frames/75
    while test $cksum_secs -gt 0; do
      let current_id+=cksum_secs%10
      let cksum_secs/=10
    done
    let total_id+=current_id

    if test $files_count -gt 0; then
      if ! get_playlength "$i" use_tag; then
        echo "Failed to obtain playlength for '$i'." >&4
        exit 1
      fi
    else
      let playlength='(offsets[f_i+1]-offsets[f_i])*1000/75'
    fi
    let total_msecs+=playlength

    test $index -ne 0 && track_offsets="$track_offsets+$total_frames"
    let total_frames=total_msecs*75/1000
    let remainder=total_msecs*75%1000
    test $remainder -ge 500 && let ++total_frames

    let ++index
  done

  test $files_count -gt 0 &&
    let total_secs=total_msecs/1000 ||
    let 'total_secs=(offsets[offsets_count-1]-offsets[0])/75'
  # total_secs-2 here because the length of cd doesn't include cd_msf_offset of 2 seconds
  let 'cddbid=(((total_id%0xFF)<<24)|((total_secs-2)<<8)|index)'
  cddbid=$(printf %08x $cddbid)

  # total_secs here because the offset of leadout track includes cd_msf_offset of 2 seconds
  if test "$print" = discid; then
    echo "$cddbid $index $track_offsets $total_secs" | sed 'y/+/ /'
  elif test "$print" = offsets; then
    for i in $(echo "$track_offsets" | sed 'y/+/ /'); do
      echo $i
    done
  elif test "$print" = length; then
    echo $total_secs
  else
    wget "$cddb_url?cmd=cddb+query+$cddbid+$index+$track_offsets+$total_secs&hello=$cddb_hello&proto=6" \
      -O - 2>/dev/null | sed 's///g'
  fi
fi
cleanup_errorlog
