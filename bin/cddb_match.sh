#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# ova-cddb_match: match CDDB entries from list read from stdin

. "@sysconfdir@/global.conf"
. "@datadir@/global"
load_config cddb.conf

usage()
{
  {
    echo "Usage: $(basename $0) [options] [directory]"
    echo
    echo "Match CDDB entries from the list read from standard input."
    echo "If no options for matching are specified, all entries are printed."
    echo "If a directory is given, track count and length are matched"
    echo "using the track count and the total length of all tracks in it."
    echo "However, if '--tracks' and/or '--length' are specified without"
    echo "an argument, track count and/or length will not be matched."
    echo "Track title(s) can also be matched, using '--ttitle'."
    general_help '\t'
    echo -e "      --tracks=COUNT\t\tmatch track count"
    echo -e "      --length=LENGTH\t\tmatch disc length with default deviation"
    echo -e "      --length=LENGTH:DEV\tmatch disc length with deviation DEV"
    echo -e "      --length=:DEV\t\tset deviation to DEV"
    echo -e "      --ttitle=REGEXP\t\tmatch track title"
    echo -e "  -p, --print-info\t\tprint disc information"
  } >&4
  exit 2
}

mtitle_count=0
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
    --tracks*)
      match_tracks="$optarg"
      test -z "$optarg" && nomatch_tracks=yes
    ;;
    --length*)
      if pos=$(strstr "$optarg" :); then
        test $pos -gt 0 && match_length="${optarg:0:$pos}"
        length_deviation="${optarg:$((pos+1))}"
      else
        match_length="$optarg"
      fi
      test -z "$optarg" && nomatch_length=yes
    ;;
    --ttitle=*)
      if test -z "$optarg"; then
        echo "Option '--ttitle' requires a non-empty argument." >&4
        exit 1
      fi
      mtitle[$mtitle_count]="$optarg"
      let ++mtitle_count
    ;;
    -p|--print-info)
      print_info=yes
    ;;
    --)
      end_options=yes
    ;;
    -*)
      echo "unrecognized option \"$1\"" >&4
      exit 1
    ;;
    *)
      if test "$dir"; then
        echo "Directory has already been specified." >&4
        exit 1
      else
        dir="$1"
      fi
    ;;
  esac

  shift
  test "$end_options" = yes && break
done

if test "$end_options" = yes -a "$1"; then
  if test "$dir"; then
    echo "Directory has already been specified." >&4
    exit 1
  else
    dir="$1"
  fi
fi

if test "$dir"; then
  discid=$(find "$dir" -maxdepth 1 -regex ".*\.\(ogg\|mp3\|wav\)" |
    "@bindir@/ova-cddb_query" --print-discid --filelist=-)
  if test "$discid"; then
    match_tracks=$(echo "$discid" | cut -d' ' -f2)
    match_length=$(echo "$discid" | cut -d' ' -f$((match_tracks+3)))
    isint "$match_tracks" || match_tracks=
    isint "$match_length" || match_length=
  fi
fi
test "$nomatch_tracks" = yes && match_tracks=
test "$nomatch_length" = yes && match_length=
echo -e "matching track count: $CL1${match_tracks:--}$RST"
test "$match_length" &&
  echo -e "matching disc length: $CL1${match_length:--}$RST[+-$CL1$length_deviation$RST]" ||
  echo -e "matching disc length: $CL1-$RST"
echo -e "matching track title: $CL1$mtitle_count$RST"
echo
count=0
tcount=0
while read line; do
  cddb_entry=$(echo "$line" | cut -d' ' -f1-2)
  cddb_remainder=$(echo "$line" | cut -d' ' -f3-)
  track_count=$("@bindir@/ova-cddb_read" --print-tracks $cddb_entry 2>/dev/null)
  disc_length=$("@bindir@/ova-cddb_read" --print-length $cddb_entry 2>/dev/null)
  isint "$track_count" "$disc_length" || continue
  let ++tcount
  test "$match_tracks" && test $match_tracks -ne $track_count && continue
  test "$match_length" && test $(abs $((match_length-disc_length))) -gt $length_deviation && continue
  if test $mtitle_count -ne 0; then
    if ! cddb_read_process "$cddb_entry" /tmp/ova-cddb_match.read_raw.$$ \
      /tmp/ova-cddb_match.read.$$ >/dev/null 4>/dev/null; then
    :
      rm -f /tmp/ova-cddb_match.*.$$
      continue
    fi
    ttitle_count=0
    cat /tmp/ova-cddb_match.read.$$ | grep "^ttitle" |
      dd conv=lcase 2>/dev/null >/tmp/ova-cddb_match.ttitle.$$
    while read rline; do
      pos=$(strstr "$rline" '=') || continue
      ttitle[$ttitle_count]="${rline:$((pos+1))}"
      let ++ttitle_count
    done </tmp/ova-cddb_match.ttitle.$$
    for ((i=0; i<mtitle_count; ++i)); do
      match=no
      for ((j=0; j<ttitle_count; ++j)); do
        if echo "${ttitle[$j]}" | grep "${mtitle[$i]}" &>/dev/null; then
          match=yes
          break
        fi
      done
      test "$match" = no && continue 2
    done
  fi
  echo -e "$CL2$cddb_entry$RST $cddb_remainder"
  test "$match_tracks" || echo -e "  track count: $CL1$track_count$RST"
  if test "$match_length"; then
    deviation=$((disc_length-match_length))
    test $deviation -ge 0 &&
      deviation="[+$CL1$deviation$RST]" ||
      deviation="[-$CL1$((-deviation))$RST]"
  else
    deviation=
  fi
  echo -e "  disc length: $CL1$disc_length$RST$deviation"
  let ++count
  if test "$print_info" = yes; then
    if test $mtitle_count -eq 0; then
      if ! cddb_read_process "$cddb_entry" /tmp/ova-cddb_match.read_raw.$$ \
        /tmp/ova-cddb_match.read.$$ >/dev/null 4>/dev/null; then
      :
        rm -f /tmp/ova-cddb_match.*.$$
        continue
      fi
    fi
    i=1
    cat /tmp/ova-cddb_match.read.$$ | while read rline; do
      pos=$(strstr "$rline" '=') || continue
      left="${rline:0:$pos}"
      right="${rline:$((pos+1))}"
      case $left in
        dyear)
          year="${right:-''}"
        ;;
        dgenre)
          genre="${right:-''}"
        ;;
        ttitle*)
          if test $i -eq 1; then
            echo "  disc genre:  $genre"
            echo "  disc year:   $year"
          fi
          echo -e "  track $CL1$(zeropad $i 2)$RST: ${right:-''}"
          let ++i
        ;;
      esac
    done
  fi
  rm -f /tmp/ova-cddb_match.*.$$
done
test $count -ne 0 && echo >&4
echo -e "CDDB entries matched: $CL1$count$RST/$CL1$tcount$RST" >&4
cleanup_errorlog
