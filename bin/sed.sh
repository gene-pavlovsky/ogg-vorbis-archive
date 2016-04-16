#!/bin/sh
#
# copyright 2004 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# ova-sed: process a given .ogg file's comments with sed

. "@sysconfdir@/global.conf"
. "@datadir@/global"

usage()
{
  {
    echo "Usage: $(basename $0) [options] filename [filename]*"
    echo
    echo "Processes Ogg Vorbis files' comments with sed."
    echo "Without any options, displays the comments."
    general_help '\t'
    echo -e "  -a, --add=STRING\t\tadd STRING to the file's comments"
    echo -e "  -e, --expression=SCRIPT\tadd the SCRIPT to sed script"
    echo -e "  -f, --file=FILE\t\tadd the contents of FILE to sed script"
    echo -e "  -r, --regexp-extended\t\tuse extended regexps in sed script"
    echo -e "  -n, --dry-run\t\t\tjust display processed comments"
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
    -n|--dry-run)
      dry_run=yes
    ;;
    -a|--add=*)
      if test "$1" = "-a"; then
        shift
        if test $# -eq 0; then
          echo "option '$option' requires an argument" >&4
          exit 1
        fi
        optarg="$1"
      fi
      array_add add_lines "$optarg"
    ;;
    -e|--expression=*)
      if test "$1" = "-e"; then
        shift
        if test $# -eq 0; then
          echo "option '$option' requires an argument" >&4
          exit 1
        fi
        optarg="$1"
      fi
      sed_expr="$(echo "$optarg" | sed "s/'/'\\\\''/")"
      test -z "$sed_options" && sed_options="-e '$sed_expr'" || sed_options="$sed_options -e '$sed_expr'"
      script=yes
    ;;
    -f|--file=*)
      if test "$1" = "-f"; then
        shift
        if test $# -eq 0; then
          echo "option '$option' requires an argument" >&4
          exit 1
        fi
        optarg="$1"
      fi
      test -z "$sed_options" && sed_options="-f '$optarg'" || sed_options="$sed_options -f '$optarg'"
      script=yes
    ;;
    -r|--regexp-extended)
      test -z "$sed_options" && sed_options="-r" || sed_options="$sed_options -r"
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

test "$end_options" = yes && dir="$1"

if test -z "$script" -a -z "$add_lines_count"; then
  dry_run=yes
fi

if test -z "$files_count"; then
  echo "no file(s) have been specified" >&4
  exit 1
fi

isatty 1 && tty=1 || tty=
for ((filen=0; filen<files_count; ++filen)); do
  file=${files[filen]}
  test "$tty" && echo -e " $CL2$file$RST"
  vorbiscomment -l "$file" >/tmp/ova-sed.comment.$$ || {
    echo "failed to get Ogg Vorbis comments from '$file'" >&4
    rm -f /tmp/ova-sed.comment.$$
    exit 1
  }
  {
    if test "$script"; then
      cat /tmp/ova-sed.comment.$$ | eval "sed $sed_options"
      if test $? -ne 0; then
        echo "sed has failed; no changes made to '$file'"
        rm -f /tmp/ova-sed.comment.$$ /tmp/ova-sed.comment_out.$$ >&4
        exit 1
      fi
    else
      cat /tmp/ova-sed.comment.$$
    fi
    for ((i=0; i<add_lines_count; ++i)); do
      echo ${add_lines[i]}
    done
  } >/tmp/ova-sed.comment_out.$$ 2>&4
  equal=no
  cmp /tmp/ova-sed.comment.$$ /tmp/ova-sed.comment_out.$$ &>/dev/null && equal=yes
  test "$equal" = yes || echo -e "\033[1A\r${CL1}*$RST"
  if test "$dry_run" = yes; then
    cat /tmp/ova-sed.comment_out.$$
  elif test "$equal" != yes; then
    vorbiscomment -c /tmp/ova-sed.comment_out.$$ -w "$file" || {
      echo "failed to save Ogg Vorbis comments to '$file'" >&4
      rm -f /tmp/ova-sed.comment.$$ /tmp/ova-sed.comment_out.$$
      exit 1
    }
  fi
  test "$tty" -a "$dry_run" = yes && echo
done
if test "$tty" -a "$script"; then
  test "$tty" -a "$dry_run" != yes && echo
  echo "trying to rename files:"
  for ((filen=0; filen<files_count; ++filen)); do
    file=${files[filen]}
    base=$(basename "$file")
    dir=$(dirname "$file")
    new_base=$(echo "$base" | eval "sed $sed_options" | sed -e 'y/ /_/' -e 's/_\{2,\}/_/g' \
        -e 's/\(^\|_\)\([][/\<>!@#$%^&*()+={};:,.?~-]*\)\($\|_\)/\2/g')
    test "$base" = "$file" &&
      new_file="$new_base" ||
      new_file="$dir/$new_base"
    if test "$new_file" != "$file"; then
      test "$dry_run" != yes && mv "$file" "$new_file"
      echo -e "$CL2$file$RST -> $CL2$new_file$RST"
    fi
  done
fi
rm -f /tmp/ova-sed.comment.$$ /tmp/ova-sed.comment_out.$$
cleanup_errorlog
