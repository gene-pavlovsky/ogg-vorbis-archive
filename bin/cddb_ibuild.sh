#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# ova-cddb_ibuild: build the artist/album database and search indices

. "@sysconfdir@/global.conf"
. "@datadir@/global"
load_config cddb.conf

usage()
{
  {
    echo "Usage: $(basename $0) cddb_dir"
    echo "       $(basename $0) -s|--save-db [-n|--no-indices] cddb_dir"
    echo "       $(basename $0) -l|--load-db"
    echo
    echo "Builds the artist/album database and search indices."
    general_help
    echo -e "  -l, --load-db\t\tload the database from data directory"
    echo -e "  -s, --save-db\t\tsave the database to data directory"
    echo -e "  -n, --no-indices\tdon't create the search indices"
  } >&4
  exit 2
}

test $# -eq 0 && usage

cddb_dir=

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
    -l|--load-db)
      load_db=yes
    ;;
    -s|--save-db)
      save_db=yes
    ;;
    -n|--no-indices)
      no_index=yes
    ;;
    --)
      end_options=yes
    ;;
    -*)
      echo "unrecognized option \"$1\"" >&4
      exit 1
    ;;
    *)
      cddb_dir="$1"
    ;;
  esac

  shift
  test "$end_options" = yes && break
done

if test "$end_options" = yes; then
  cddb_dir="$1"
fi

if test "$load_db" = yes; then
  test "$cddb_dir" && usage
else
  test -z "$cddb_dir" && usage
fi
test "$load_db" = yes -a "$save_db" = yes && usage
if test "$no_index" = yes; then
  test "$save_db" = yes || usage
fi

if test -f "@datadir@/cddb_dtitle/lock"; then
  echo "Found lockfile '@datadir@/cddb_dtitle/lock', exiting." >&4
  exit 1
else
  echo "$$" >"@datadir@/cddb_dtitle/lock"
fi
if test "$$" != "$(< '@datadir@/cddb_dtitle/lock')"; then
  echo "Found lockfile '@datadir@/cddb_dtitle/lock', exiting." >&4
  exit 1
fi

time_global_start=$(gettimeofday -s)

test "$load_db" = yes -o "$save_db" = yes &&
  db_file="@datadir@/cddb_dtitle/database" || db_file=/tmp/ova-cddb_ibuild.index_db

die()
{
  trap '' int hup quit term
  rm -f "@datadir@/cddb_dtitle/lock"
  show_cursor
  cleanup_errorlog
  test "$1" && echo "$1" >&4
  case $die_mode in
    generate_db)
      rm -f "$db_file.tmp"
    ;;
    resume)
      rm -f "$in_db_file"
    ;;
    create_indices)
      if test -z "$should_abort"; then
        should_abort=yes
        return
      else
        test "$in_db_file" != "$db_file" && rm -f "$in_db_file"
        test "$save_db" = yes -o "$load_db" = yes || rm -f "$db_file"
      fi
    ;;
    cdb_artist)
      rm -f "@datadir@/cddb_dtitle/index_artist.cdb.tmp"
    ;;
    cdb_album)
      rm -f "@datadir@/cddb_dtitle/index_album.cdb.tmp"
    ;;
    normal)
      exit 0
    ;;
  esac
  test -z "$1" && echo >&4
  exit 1
}

print_time_took()
{
  let elapsed=$(gettimeofday -s)-$1
  printf "$2took $CL1%4.1d$RST:$CL1%.2d$RST\033[K\n" $((elapsed/60)) $((elapsed%60))
}

trap 'die' int hup quit term
hide_cursor

if test "$load_db" = yes; then
  test -f "$db_file" || die "File '$db_file' is not readable."
else
  rm -f "@datadir@/cddb_dtitle/resume"
  cd "$cddb_dir" || die "Failed to cd to '$cddb_dir'."
  echo -ne "generating $CL1[CDDB filename$RST,$CL1 artist$RST,$CL1 album]$RST database... "
  time_start=$(gettimeofday -s)
  die_mode=generate_db
  grep -Hr "^DTITLE=.*[/-].*" . | dd conv=lcase 2>/dev/null |
    sed -e 's/_\{1,\}/ /g' -e 's/\\//g' \
      -e 's/^\.\/\([^/]*\)\/\([0-9a-f]\{8\}:\)dtitle= *\(.*\) *\|.*/\1 \2\3/' -e 's/^  *$//' \
      -e 's/^\([^:]*:\)\(.*\)  *\/  *\(.*\)/\1\2\3/' \
      -e 's/^\([^:]*:\)\(.*\)  *-  *\(.*\)/\1\2\3/' \
      -e 's/^\([^:]*:\)\(\(.*\)  *\/ *\(.*\)\|\(.*\) *\/  *\(.*\)\|\(.*\) *\/ *\(.*\)\)/\1\3\5\7\4\6\8/' \
      -e 's/^\([^:]*:\)\(\(.*\)  *- *\(.*\)\|\(.*\) *-  *\(.*\)\|\(.*\) *- *\(.*\)\)/\1\3\5\7\4\6\8/' \
      -e 's/^//' -e 's/^[^:]*:\(.*\|.*\|[^]*\)$//' \
      -e 's/\(^\| \)\([][/\<>!@#$%^&*()+={};:,.?~-]*\)\($\| \)/\2/g' \
      -e 's/^\([^:]*:\)\(v\.\?a\.\?\|various\)/\1various artists/' | tr -s '\n' >"$db_file"
  die_mode=
  print_time_took $time_start
fi

if test "$no_index" != yes; then
#  if test -f "@datadir@/cddb_dtitle/resume"; then
  if false; then
    lines_count=$(wc -l "$db_file" | sed 's/^ *\([0-9]*\).*/\1/')
    lines_done=$(< "@datadir@/cddb_dtitle/resume")
    in_db_file="${db_file}.resume"
    isint "$lines_count" "$lines_done" || die
    die_mode=resume
    tail -n $((lines_count-lines_done)) "$db_file" >"$in_db_file"
    die_mode=
  else
    rm -f "@datadir@/cddb_dtitle/index_"{artist,album}.tmp
    in_db_file="$db_file"
  fi
  lines_count=$(wc -l "$in_db_file" | sed 's/^ *\([0-9]*\).*/\1/')
  lines_done=0
  echo -ne "creating indices:   ${CL1}0.0$RST% done, elapsed/eta/total:   ${CL1}0$RST:${CL1}00$RST" \
    "/  ${CL1}wait$RST  /  ${CL1}wait$RST"
  time_start=$(gettimeofday -s)
  time_start_us=$(gettimeofday -u)
  die_mode=create_indices
  rm -f "@datadir@/cddb_dtitle/resume"
  while read line; do
    pos1=$(strstr "$line" ':')
    pos2=$(strstr "$line" '')
		test -z "$pos1" -o -z "$pos2" && continue
    cddb_file="${line:0:$pos1}"
    artist="${line:$((pos1+1)):$((pos2-pos1-1))}"
    album="${line:$((pos2+1))}"
    data="$cddb_file $artist$album"
    artistk="${artist:0:$index_artist_keylen}"
    while test ${#artistk} -lt $index_artist_keylen; do
      artistk="$artistk "
    done
    albumk="${album:0:$index_album_keylen}"
    while test ${#albumk} -lt $index_album_keylen; do
      albumk="$albumk "
    done
    echo "+${#artistk},${#data}:$artistk->$data" >>"@datadir@/cddb_dtitle/index_artist.tmp"
    echo "+${#albumk},${#data}:$albumk->$data" >>"@datadir@/cddb_dtitle/index_album.tmp"
    let ++lines_done
    if test "$update_cycle" && test $((lines_done%update_cycle)) -eq 0; then
      let elapsed=$(gettimeofday -s)-time_start
      test $lines_count -ne 0 && progress=$((lines_done*1000000/lines_count)) || progress=1000000
      printf "\rcreating indices: $CL1%3.1d$RST.$CL1%.1d$RST%% done" $(((progress/1000)/10)) $(((progress/1000)%10))
      if test $elapsed -gt 0; then
        test $progress -ne 1000000 && est=$(estimated_total $progress $elapsed) || est=$elapsed
        printf ", elapsed/eta/total: $CL1%3.1d$RST:$CL1%.2d$RST / " $((elapsed/60)) $((elapsed%60))
        if test "$est"; then
          test $est -lt $elapsed && est=$elapsed
          printf "$CL1%3.1d$RST:$CL1%.2d$RST / $CL1%3.1d$RST:$CL1%.2d$RST\033[K" $(((est-elapsed)/60)) $(((est-elapsed)%60)) $((est/60)) $((est%60))
        else
          printf " ${CL1}wait$RST  /  ${CL1}wait$RST\033[K"
        fi
      fi
    elif test -z "$update_cycle" -a $((lines_done%20)) -eq 0; then
      if test $(($(gettimeofday -s)-time_start)) -gt $progress_wait; then
        let "elapsed_us=($(gettimeofday -u)-time_start_us)+($(gettimeofday -s)-time_start)*1000000"
        if test $elapsed_us -gt $(((progress_wait+1)*1000000)); then
          test $ui_update_rate -ne 0 &&
            let "update_cycle=lines_done*1000000000/(elapsed_us*ui_update_rate)" || update_cycle=1
          test $update_cycle -eq 0 && update_cycle=1
        fi
      fi
    fi
    if test "$should_abort"; then
      echo $lines_done >"@datadir@/cddb_dtitle/resume"
      die
    fi
  done <"$in_db_file"
  die_mode=
  test "$in_db_file" != "$db_file" && rm -f "$in_db_file"
  test "$save_db" = yes -o "$load_db" = yes || rm -f "$db_file"
  print_time_took $time_start "\rcreating indices: ${CL1}100.0$RST%% done, operation completed... "

  echo -n "sorting artist and album indices by artist / album... "
  time_start=$(gettimeofday -s)
  die_mode=sort_artist
  sort -k 2 -t ':' "@datadir@/cddb_dtitle/index_artist.tmp" >"@datadir@/cddb_dtitle/index_artist"
  die_mode=
  rm -f "@datadir@/cddb_dtitle/index_artist.tmp"
  die_mode=sort_album
  sort -k 2 -t '' "@datadir@/cddb_dtitle/index_album.tmp" >"@datadir@/cddb_dtitle/index_album"
  die_mode=
  rm -f "@datadir@/cddb_dtitle/index_album.tmp"
  print_time_took $time_start

  echo "+10,${#index_artist_keylen}:key_length->$index_artist_keylen" >>"@datadir@/cddb_dtitle/index_artist"
  echo "+10,${#index_album_keylen}:key_length->$index_album_keylen" >>"@datadir@/cddb_dtitle/index_album"
  echo >>"@datadir@/cddb_dtitle/index_artist"
  echo >>"@datadir@/cddb_dtitle/index_album"
  echo -n "converting indices to the constant database format... "
  time_start=$(gettimeofday -s)
  die_mode=cdb_artist
  cdbmake "@datadir@/cddb_dtitle/index_artist.cdb" "@datadir@/cddb_dtitle/index_artist.cdb.tmp" <"@datadir@/cddb_dtitle/index_artist" 2>&4 || die
  die_mode=
  rm -f "@datadir@/cddb_dtitle/index_artist"
  die_mode=cdb_album
  cdbmake "@datadir@/cddb_dtitle/index_album.cdb" "@datadir@/cddb_dtitle/index_album.cdb.tmp" <"@datadir@/cddb_dtitle/index_album" 2>&4 || die
  die_mode=
  rm -f "@datadir@/cddb_dtitle/index_album"
  die_mode=
  print_time_took $time_start
fi

print_time_took $time_global_start "\n\033[38Gentire operation "
die_mode=normal
die
