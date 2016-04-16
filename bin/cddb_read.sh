#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# ova-cddb_read: read the CDDB entry via HTTP

. "@sysconfdir@/global.conf"
. "@datadir@/global"
load_config cddb.conf

usage()
{
  {
    echo "Usage: $(basename $0) [options] category discid"
    echo
    echo "Reads a disc entry from the CDDB (via HTTP)."
    general_help
    echo -e "  -d, --print-discid\tprint full discid"
    echo -e "  -o, --print-offsets\tprint track frame offsets"
    echo -e "  -l, --print-length\tprint disc length"
    echo -e "  -t, --print-tracks\tprint track count"
    echo -e "  -r, --print-revision\tprint revision number"
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
    -r|--print-revision)
      print=revision
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
          echo "CDDB discid has already been specified." >&4
          exit 1
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
        echo "CDDB discid has already been specified." >&4
        exit 1
      fi
    fi
    shift
  done
fi

test -z "$discid" && usage

if test -z "$cddb_url"; then
  echo "CDDB usage is disabled." >&4
  exit 0
fi

if test ! -f "@datadir@/cddb_cache/$category/$discid"; then
  mkdir -p "@datadir@/cddb_cache/$category" &>/dev/null
  wget "$cddb_url?cmd=cddb+read+$category+$discid&hello=$cddb_hello&proto=6" \
    -O - 2>/dev/null | sed 's///g' >/tmp/ova-cddb_read.data.$$
  result=$(head -n 1 /tmp/ova-cddb_read.data.$$)
  case ${result:0:3} in
    210)
      echo "cddbp: 210 $category $discid CD database entry follows" >&4
      cat /tmp/ova-cddb_read.data.$$ | grep '^\(#\|[[:alpha:]]\)' >"@datadir@/cddb_cache/$category/$discid"
    ;;
    *)
      echo "cddbp: $result" >&4
      rm -f /tmp/ova-cddb_read.data.$$
      rmdir "@datadir@/cddb_cache/$category" &>/dev/null
      exit 1
    ;;
  esac
  rm -f /tmp/ova-cddb_read.data.$$
else
  echo "cache: 210 $category $discid CD database entry follows" >&4
fi

print_offsets()
{
  cat "@datadir@/cddb_cache/$category/$discid" | grep '^#[[:blank:]]*[0-9]\{1,\}$' |
    sed 's/#[[:blank:]]*//'
}

print_disclength()
{
  cat "@datadir@/cddb_cache/$category/$discid" | grep '^#[[:blank:]]*Disc length: *[0-9]\{1,\} *\(seconds\|secs\)$' |
    sed 's/#[[:blank:]]*Disc length: *\([0-9]\{1,\}\) *\(seconds\|secs\)/\1/'
}

print_discid()
{
  echo "$discid $(print_offsets | wc -l | sed 's/^ *\([0-9]*\).*/\1/')" \
    "$(for i in $(print_offsets); do echo -n "$i "; done)$(print_disclength)"
}

print_revision()
{
  cat "@datadir@/cddb_cache/$category/$discid" | grep '^#[[:blank:]]*Revision: *[0-9]\{1,\}$' |
    sed 's/#[[:blank:]]*Revision: *//'
}

if test "$print" = offsets; then
  print_offsets
elif test "$print" = length; then
  print_disclength
elif test "$print" = tracks; then
  print_offsets | wc -l | sed 's/^ *\([0-9]*\).*/\1/'
elif test "$print" = discid; then
  print_discid
elif test "$print" = revision; then
  print_revision
else
  cat "@datadir@/cddb_cache/$category/$discid"
fi
cleanup_errorlog
