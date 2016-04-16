#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# install/uninstall: ova install/uninstall script.

overwrite_config=no

cc=${CC:-gcc}
strip=${STRIP:-strip}
command -v ginstall &>/dev/null && install=${INSTALL:-ginstall} || install=${INSTALL:-install}

project=ova
version=1.3.0
prefix=/usr/local
bindir=$prefix/bin
sysconfdir=$prefix/etc/$project
datadir=$prefix/share/$project

bin_scripts='
        cddb_ibuild
        cddb_isearch
        cddb_match
        cddb_query
        cddb_read
        cddb_number
        conv
        cue2offsets
        gettag
        gettag_mp3
        gettag_ogg
        hardlink
        lint
        main
        sed'
bin_programs='
        cdbgetall
        cr2lf
        gettimeofday
        isatty
        lf0
        nanosleep
        tracksplit
        readdef'
sysconf_data='
        conv
        cddb
        global
        hardlink
        main
        music'
data_scripts='
        global'
data_data='
        cddb_cache/
        cddb_dtitle/
        cddb_submit/
        log/
        log/error/
        genre_id3v1_list
        genre_transform'

# choose the right cflags and ldflags depending on the name of the program to be compiled
# args: $1 - program
set_compiler_flags()
{
  case $1 in
    readdef)
			cflags=
      ldflags='-lreadline -lncurses'
    ;;
    tracksplit)
			cflags=
      ldflags='-lm'
    ;;
    *)
      cflags=
      ldflags=
    ;;
  esac
  test -z "$cflags" && cflags="$CFLAGS" || cflags="$cflags $CFLAGS"
  test -z "$ldflags" && ldflags="$LDFLAGS" || ldflags="$ldflags $LDFLAGS"
}

if ! cd "$(dirname "$0")"; then
  echo "Failed to cd to '$(dirname "$0")'." >&4
  exit 1
fi

. share/global

mode=$(basename "$0" .sh)
if test "$mode" != install -a "$mode" != uninstall; then
  echo "Must be called either as install or as uninstall." >&4
  exit 1
fi

usage()
{
  {
    echo "Usage: $(basename $0) [options]"
    echo
    echo "${mode}s $project $version."
    general_help '\t'
    echo -e "      --prefix=DIR\t\tinstallation prefix     [$prefix]"
    echo -e "      --bindir=DIR\t\tuser executables        [$prefix/bin]"
    echo -e "      --sysconfdir=DIR\t\tconfiguration files     [$prefix/etc/$project]"
    echo -e "      --datadir=DIR\t\tread-only data          [$prefix/share/$project]"
    echo -e "      --disable-strip\t\tdon't strip executables"
    echo -e "  -n, --dry-run\t\t\tdon't run any commands, just print them"
  } >&4
  exit 2
}

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
    --prefix=*)
      prefix="$optarg"
      bindir="$prefix/bin"
      sysconfdir="$prefix/etc/$project"
      datadir="$prefix/share/$project"
    ;;
    --bindir=*)
      bindir="$optarg"
    ;;
    --sysconfdir=*)
      sysconfdir="$optarg"
    ;;
    --datadir=*)
      datadir="$optarg"
    ;;
    --disable-strip)
      strip=
    ;;
    -n|--dry-run)
      dry_run=yes
    ;;
    --help)
      usage
    ;;
    --version)
      echo "$project $version" >&4
      exit 2
    ;;
    *)
      echo "unrecognized option \"$1\"" >&4
      exit 1
    ;;
  esac

  shift
done

test "$mode" = install &&
  echo "installing $project $version to:" ||
  echo "uninstalling $project $version from:"
echo
echo "  prefix=$prefix"
echo "  bindir=$bindir"
echo "  sysconfdir=$sysconfdir"
echo "  datadir=$datadir"
kbd_confirm
echo

bs_bindir=$(echo $bindir | sed 's/\//\\\//g')
bs_sysconfdir=$(echo $sysconfdir | sed 's/\//\\\//g')
bs_datadir=$(echo $datadir | sed 's/\//\\\//g')

run()
{
  test "${1:0:3}" != "sed" && eval echo "$1"
  test "$dry_run" = yes || eval $1 || { echo -e '\nFailed.' >&2; exit 1; }
}

symlink_do()
{
  pos=$(strstr "$2" '->') || return 0
  symlink_dest="$bindir/$project-${2:0:$pos}"
  if test "$1" = install; then
    symlink_src="$project-${2:$((pos+2))}"
    run 'ln -sf $symlink_src $symlink_dest'
  elif test "$1" = uninstall; then
    run 'rm -f $symlink_dest'
  fi
  continue
}

if test "$mode" = install; then
  run '$install -d -m 755 "$bindir"'
  for i in $bin_scripts; do
    symlink_do install $i
    test "$i" = main && instname=$project || instname=$project-$i
    run '$install -m 755 bin/$i.sh "$bindir/$instname"'
    run 'sed -i -e "s/@project@/$project/g" -e "s/@version@/$version/g"
      -e "s/@bindir@/$bs_bindir/g" -e "s/@sysconfdir@/$bs_sysconfdir/g"
      -e "s/@datadir@/$bs_datadir/g" "$bindir/$instname"'
  done
  for i in $bin_programs; do
    symlink_do install $i
    if test -f bin/$i; then
      run '$install -m 755 bin/$i "$bindir/$i"'
    else
			if test -d src/$i; then
				run 'make -C src/$i $i'
				test -f src/$i/$i.exe &&
					run '$install -m 755 src/$i/$i.exe "$bindir/$i.exe"' ||
					run '$install -m 755 src/$i/$i "$bindir/$i"'
				run 'make -C src/$i clean'
			else
				set_compiler_flags $i
				run '$cc $cflags src/$i.c $ldflags -o "$bindir/$i"'
			fi
			test "$strip" && run '$strip "$bindir/$i"'
    fi
  done
else
  for i in $bin_scripts; do
    symlink_do uninstall $i
    test "$i" = main && instname=$project || instname=$project-$i
    run 'rm -f "$bindir/$instname"'
  done
  for i in $bin_programs; do
    symlink_do uninstall $i
    run 'rm -f "$bindir/$i"'
  done
  run 'rmdir "$bindir" 2>/dev/null'
fi

if test "$mode" = install; then
  run '$install -d -m 755 "$sysconfdir"'
  for i in $sysconf_data; do
    if test "$overwrite_config" != yes -a -f "$sysconfdir/$i.conf"; then
      oldconf_version=$(cat "$sysconfdir/$i.conf" | grep '^# '"$project"' [0-9a-z.]*$' | sed 's/^# '"$project"' //')
      if test "$oldconf_version" -a "$oldconf_version" = $version; then
        echo "not overwriting $sysconfdir/$i.conf from $project-$version"
        continue
      fi
      grep -v '^[[:blank:]]*#' "$sysconfdir/$i.conf" >/tmp/ova-install.conf.old.$$
      grep -v '^[[:blank:]]*#' etc/$i.conf >/tmp/ova-install.conf.new.$$
      run 'sed -i -e "s/@project@/$project/g" -e "s/@version@/$version/g"
        -e "s/@bindir@/$bs_bindir/g" -e "s/@sysconfdir@/$bs_sysconfdir/g"
        -e "s/@datadir@/$bs_datadir/g" '"/tmp/ova-install.conf.new.$$"
      if cmp /tmp/ova-install.conf.{old,new}.$$ &>/dev/null; then
        echo no major changes to "$sysconfdir/$i.conf"
        instname=$i.conf
      else
        instname=$i.conf.new
      fi
      rm -f /tmp/ova-install.conf.{old,new}.$$
    else
      instname=$i.conf
    fi
    run '$install -m 644 etc/$i.conf "$sysconfdir/$instname"'
    run 'sed -i -e "s/@project@/$project/g" -e "s/@version@/$version/g"
      -e "s/@bindir@/$bs_bindir/g" -e "s/@sysconfdir@/$bs_sysconfdir/g"
      -e "s/@datadir@/$bs_datadir/g" "$sysconfdir/$instname"'
  done
else
  for i in $sysconf_data; do
    run 'rm -f "$sysconfdir/$i.conf"'
  done
  run 'rmdir "$sysconfdir" 2>/dev/null'
fi

if test "$mode" = install; then
  run '$install -d -m 755 "$datadir"'
  for i in $data_scripts; do
    run '$install -m 644 share/$i "$datadir"'
    run 'sed -i -e "s/@project@/$project/g" -e "s/@version@/$version/g"
      -e "s/@bindir@/$bs_bindir/g" -e "s/@sysconfdir@/$bs_sysconfdir/g"
      -e "s/@datadir@/$bs_datadir/g" "$datadir/$i"'
  done
  for i in $data_data; do
    if test "${i:$((${#i}-1))}" = '/'; then
      i="${i:0:$((${#i}-1))}"
      run '$install -d -m 755 $datadir/$i'
    else
      run '$install -m 644 share/$i "$datadir"'
    fi
  done
else
  run 'rm -rf "$datadir"'
fi

test "$mode" = uninstall && run 'rmdir "$prefix" 2>/dev/null'
