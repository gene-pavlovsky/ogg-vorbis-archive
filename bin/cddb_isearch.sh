#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# ova-cddb_isearch: search the artist/album database indices

. "@sysconfdir@/global.conf"
. "@datadir@/global"
load_config cddb.conf

usage()
{
  {
    echo "Usage: $(basename $0) --artist=ARTIST [--with-album=REGEXP]"
    echo "       $(basename $0) --album=ALBUM [--with-artist=REGEXP]"
    echo "       $(basename $0) --dtitle=REGEXP"
    echo
    echo "Searches the artist/album database indices. Also allows"
    echo "to search the database itself, which is painfully slow."
    general_help '\t'
    echo -e "      --artist=ARTIST\t\tsearch the artist index for ARTIST"
    echo -e "        --with-album=REGEXP\twith album matching REGEXP"
    echo -e "      --album=ALBUM\t\tsearch the album index for ALBUM"
    echo -e "        --with-artist=REGEXP\twith artist matching REGEXP"
    echo -e "      --dtitle=REGEXP\t\tsearch the dtitle database for REGEXP"
  } >&4
  exit 2
}

end_options=
file_list=
print=
match_count=0
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
    --artist=*)
      artist="$optarg"
      let ++match_count
      if test -z "$optarg"; then
        echo "Option '--artist' requires a non-empty argument." >&4
        exit 1
      fi
    ;;
    --album=*)
      album="$optarg"
      let ++match_count
      if test -z "$optarg"; then
        echo "Option '--album' requires a non-empty argument." >&4
        exit 1
      fi
    ;;
    --with-artist=*)
      with_artist="$optarg"
    ;;
    --with-album=*)
      with_album="$optarg"
    ;;
    --dtitle=*)
      dtitle="$optarg"
      let ++match_count
      if test -z "$optarg"; then
        echo "Option '--dtitle' requires a non-empty argument." >&4
        exit 1
      fi
    ;;
    --)
      end_options=yes
    ;;
    *)
      echo "unrecognized option \"$1\"" >&4
      exit 1
    ;;
  esac

  shift
  test "$end_options" = yes && break
done

if test $match_count -ne 1; then
  echo "Must specify exactly one '--artist', '--album' or '--dtitle' option." >&4
  exit 1
fi
if test "$with_artist" -a -z "$album"; then
  echo "Option '--with-artist' can only be used in conjunction with '--album'." >&4
  exit 1
fi
if test "$with_album" -a -z "$artist"; then
  echo "Option '--with-album' can only be used in conjunction with '--artist'." >&4
  exit 1
fi

if isatty 1; then
  E_CL2="$CL2"
  E_RST="$RST"
fi
if test "$artist"; then
  if test ! -f "@datadir@/cddb_dtitle/index_artist.cdb"; then
    echo "File '@datadir@/cddb_dtitle/index_artist.cdb' is not readable." >&4
    echo "You have to run 'ova-cddb_ibuild' first." >&4
    exit 1
  fi
  key_length=$(cdbget "key_length" <"@datadir@/cddb_dtitle/index_artist.cdb" 2>&4)
  if ! isint "$key_length"; then
    echo "Artist index format error (key_length not found inside)." >&4
    exit 1
  fi
  artist=$(echo "$artist" | dd conv=lcase 2>/dev/null |
    sed -e 's/_\{1,\}/ /g' -e 's/\(^\| \)\([][/\<>!@#$%^&*()+={};:,.?~-]*\)\($\| \)/\2/g')
  artist_search="${artist:0:key_length}"
  while test ${#artist_search} -lt $key_length; do
    artist_search="$artist_search "
  done
  cdbgetall "$artist_search" <"@datadir@/cddb_dtitle/index_artist.cdb" 2>&4 | while read result; do
    pos1=$(strstr "$result" ' ' 1)
    pos2=$(strstr "$result" '')
    artistf="${result:$((pos1+1)):$((pos2-pos1-1))}"
    if test "$artist" = "${artistf:0:${#artist}}"; then
      album="${result:$((pos2+1))}"
      if test "$with_album"; then
        echo "$album" | grep "$with_album" &>/dev/null || continue
      fi
      echo -e "$E_CL2${result:0:$pos1}$E_RST $artistf $CL1/$RST $album"
    fi
  done
elif test "$album"; then
  if test ! -f "@datadir@/cddb_dtitle/index_album.cdb"; then
    echo "File '@datadir@/cddb_dtitle/index_album.cdb' is not readable." >&4
    echo "You have to run 'ova-cddb_ibuild' first." >&4
    exit 1
  fi
  key_length=$(cdbget "key_length" <"@datadir@/cddb_dtitle/index_album.cdb" 2>&4)
  if ! isint "$key_length"; then
    echo "Album index format error (key_length not found inside)." >&4
    exit 1
  fi
  album=$(echo "$album" | dd conv=lcase 2>/dev/null |
    sed -e 's/_\{1,\}/ /g' -e 's/\(^\| \)\([][/\<>!@#$%^&*()+={};:,.?~-]*\)\($\| \)/\2/g')
  album_search="${album:0:key_length}"
  while test ${#album_search} -lt $key_length; do
    album_search="$album_search "
  done
  cdbgetall "$album_search" <"@datadir@/cddb_dtitle/index_album.cdb" 2>&4 | while read result; do
    pos2=$(strstr "$result" '')
    albumf="${result:$((pos2+1))}"
    if test "$album" = "${albumf:0:${#album}}"; then
      pos1=$(strstr "$result" ' ' 1)
      artist="${result:$((pos1+1)):$((pos2-pos1-1))}"
      if test "$with_artist"; then
        echo "$artist" | grep "$with_artist" &>/dev/null || continue
      fi
      echo -e "$E_CL2${result:0:$pos1}$E_RST $artist $CL1/$RST $albumf"
    fi
  done
else
  if test ! -f "@datadir@/cddb_dtitle/database"; then
    echo "File '@datadir@/cddb_dtitle/database' is not readable." >&4
    echo "You have to run 'ova-cddb_ibuild --save-db --no-indices' first." >&4
    exit 1
  fi
  cat "@datadir@/cddb_dtitle/database" | sed 's// \/ /' | grep "$dtitle" | while read result; do
    pos1=$(strstr "$result" ':')
    pos2=$(strstr "$result" ' / ')
    echo -e "$E_CL2${result:0:$pos1}$E_RST ${result:$((pos1+1)):$((pos2-pos1-1))} $CL1/$RST ${result:$((pos2+3))}"
  done
fi
cleanup_errorlog
