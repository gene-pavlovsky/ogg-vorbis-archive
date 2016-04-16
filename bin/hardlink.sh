#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# ova-hardlink: make hard links for an ogg file

. "@sysconfdir@/global.conf"
. "@datadir@/global"
load_config music.conf hardlink.conf

usage()
{
  {
    echo "Usage: $(basename $0) [-n|--dry-run] directory"
    echo "       $(basename $0) [-n|--dry-run] -a|--link-all"
    echo
    echo "Makes hard links for an album / all albums."
    general_help
    echo -e "  -a, --link-all\t\tfind all albums and make links for them"
    echo -e "  -n, --dry-run\t\tjust display the links"
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
    -a|--link-all)
      link_all=yes
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
      dir="$1"
    ;;
  esac

  shift
  test "$end_options" = yes && break
done

test "$end_options" = yes && dir="$1"

if test "$link_all" = yes; then
  test "$dir" && usage
else
  test -z "$dir" && usage
fi

error_find_ogg()
{
  echo "$dir" >>/tmp/ova-hardlink.errors.$$
}

find_ogg_in_dir_or_cd_subdir()
{
  declare file
  file=$(ls -1d "$1/"*.ogg 2>/dev/null | head -n 1)
  if ! test -f "$file"; then
    dir_cd=$(ls -1d "$1/"cd_* 2>/dev/null | head -n 1)
    test -d "$dir_cd" || { error_find_ogg; return 1; }
    file=$(ls -1d "$dir_cd"/*.ogg 2>/dev/null | head -n 1)
    test -f "$file" || { error_find_ogg; return 1; }
  fi
  echo $file
}

find_ogg_in_dir()
{
  declare file
  file=$(ls -1d "$1/"*.ogg 2>/dev/null | head -n 1)
  test -f "$file" || { error_find_ogg; return 1; }
  echo $file
}

read_ogg_tag()
{
  declare i want want_wo_album tag_line tag_name tag_value
  want_wo_album="title:artist:date:genre:comment:tracknumber"
  album=unknown_$(gettimeofday)
  old_IFS="$IFS"
  IFS=':'
  for i in $want_wo_album; do
    eval $i="unknown"
  done
  IFS=$'\n'
  want="$want_wo_album:album"
  for tag_line in $(vorbiscomment -l "$1" 2>/dev/null); do
    tag_line=$(echo "$tag_line" | dd conv=lcase 2>/dev/null | sed 's/!//g')
    tag_name=$(echo "$tag_line" | sed 's/\([^=]*\)=.*/\1/')
    if $(value_in_colonlist "$tag_name" "$want"); then
      tag_value=$(echo "$tag_line" | sed -e 's/[^=]*=\(.*\)/\1/')
      eval "$tag_name"='$tag_value'
    fi
  done
  IFS="$old_IFS"
}

hard_lndir()
{
  declare dir file cwd
  cwd=$(pwd)
  cd "$1"
  mkdir "$2" -p 2>/dev/null
  find . -mindepth 1 -type d | cut -c3- | while read dir; do
    mkdir "$2/$dir" -p 2>/dev/null
  done
  find . -type f | cut -c3- | while read file; do
    echo "$2/$file"
    ln -f "$file" "$2/$file"
  done
  cd "$cwd"
}

work()
{
  declare dir dir_rel
  dir=$(canonizepath "$1" "$(pwd)")
  dir_rel=$(stripprefix "$dir" "$music_root")
  hardlinks $dir $dir_rel
}

rm -f /tmp/ova-hardlink.{list_done,flag_list_all,flag_work,flag_cleanup_files,list_rm,list_rmdir}.$$
rm -f "@datadir@/log/ova-hardlink.errors" /tmp/ova-hardlink.errors.$$
touch /tmp/ova-hardlink.list_done.$$
if test "$link_all" = yes; then
  list_all | sort -u >/tmp/ova-hardlink.list_all.$$
  set | grep '^music_by_' | sed 's/^music_by_[^=]*=//' | while read dir; do
    test -d "$dir" && find "$dir" -type f
  done | sort -u >/tmp/ova-hardlink.list_files_old.$$
  touch /tmp/ova-hardlink.flag_list_all.$$
  while read dir; do
    mtime=
    mtime_date=
    work "$dir"
    echo "$dir" >>/tmp/ova-hardlink.list_done.$$
  done </tmp/ova-hardlink.list_all.$$ | sort -u >/tmp/ova-hardlink.list_files_new.$$
  touch /tmp/ova-hardlink.flag_work.$$
  diff -u /tmp/ova-hardlink.list_files_old.$$ /tmp/ova-hardlink.list_files_new.$$ | grep '^-/' | cut -c2- | while read file; do
    rm -f "$file"
    echo "$file"
  done >/tmp/ova-hardlink.list_rm.$$
  touch /tmp/ova-hardlink.flag_cleanup_files.$$
  set | grep '^music_by_' | sed 's/^music_by_[^=]*=//' | while read root_dir; do
    test -d "$root_dir" && find "$root_dir" -depth -type d | while read dir; do
      rmdir "$dir" &>/dev/null && echo "$dir"
    done
    rmdir "$root_dir" &>/dev/null && echo "$root_dir"
  done >/tmp/ova-hardlink.list_rmdir.$$
else
  work "$dir"
fi
if test -f /tmp/ova-hardlink.errors.$$; then
  mv /tmp/ova-hardlink.errors.$$ "@datadir@/log/ova-hardlink.errors"
  exit_status=1
else
  exit_status=0
fi
rm -f /tmp/ova-hardlink.*.$$
cleanup_errorlog
exit $exit_status
