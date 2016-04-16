#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# ova-conv: convert a file to the Ogg Vorbis format
# Front-end to mplayer and oggenc, mostly.

. "@sysconfdir@/global.conf"
. "@datadir@/global"
load_config conv.conf

usage()
{
  {
    echo "Usage: $(basename $0) [options] file"
    echo
    echo "Converts the file to the Ogg Vorbis format."
    general_help '\t'
    echo -e "      --oggenc-flags=FLAGS\toverride configuration file flags"
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
    --oggenc-flags=*)
      oggenc_flags="$optarg"
    ;;
    --)
      end_options=yes
    ;;
    -*)
      echo "unrecognized option \"$1\"" >&4
      exit 1
    ;;
    *)
      in_file="$1"
    ;;
  esac

  shift
  test "$end_options" = yes && break
done

test "$end_options" = yes -a "$1" && in_file="$1"

base=$(echo "$in_file" | sed 's/\.[^.]*$//')
wave_file="$base.wav"
ogg_file="$base.ogg"

case $(echo "$in_file" | sed 's/.*\.\([^.]*\)\|.*/\1/') in
  wav)
    echo "$in_file" | grep '.*track[0-9][0-9]\.cdda\.wav$' &>/dev/null &&
      input_format=cd || input_format=wav
    bitrate=1378
  ;;
  *)
    input_format=other
    bitrate=unknown
  ;;
esac

rm -f "$base.decoding" "$base.encoding"

if test ! -f "$in_file"; then
  echo "File '$in_file' is not readable." >&4
  exit 1
fi

if test "$wave_file" != "$in_file"; then
  rm -f "$wave_file"
  if test ! -f "$base.tag"; then
    rm -f "$base.tag~"
    "@bindir@/ova-gettag" --tag-only "$in_file"
  fi
  if test ! -f "$wave_file"; then
    mplayer -vo null -ao pcm:file="$wave_file" "$in_file" 2>&1 </dev/null |
      cr2lf | grep --line-buffered "^A:" >>"$base.decoding"
  fi
  get_playlength "$wave_file"
  let wave_len=playlength/100
  get_playlength "$in_file" use_tag
  let in_len=playlength/100
  if test $(abs $((wave_len-in_len))) -gt $encdec_deviation; then
    echo "Wave file '$wave_file' has wrong size for the input file." >&4
    echo "Probably, the decoding process has crashed or has been killed." >&4
    echo "Maybe mp3info returned the wrong size in the first place." >&4
    exit 1
  fi
fi
wav_fsize=$(stat -c %s "$wave_file" 2>/dev/null)
wav_info=$(sfinfo "$wave_file" 2>/dev/null | grep "^Audio Data")
test "$wav_info" &&
  wav_size=$(($(echo "$wav_info" | sed 's/^Audio Data[[:blank:]]*\([0-9]*\).*/\1/')+\
    $(echo "$wav_info" | sed 's/.*offset *\([0-9]*\).*/\1/')))
if ! isint "$wav_fsize" "$wav_size" || test $((wav_size-wav_fsize)) -ne 0; then
  echo "Wave file '$wave_file' has wrong size for it's header." >&4
  test "$wave_file" != "$in_file" &&
    echo "Probably, the decoding process has crashed or has been killed." >&4 ||
    echo "Probably, the input file is corrupt (incomplete)." >&4
  exit 1
fi
if test "$wave_file" != "$in_file"; then
  rm -f "$base.decoding"
  sync
  rm -f "$in_file"
fi

if test -z "$oggenc_flags"; then
  if test -f "$base.tag~"; then
    . "$base.tag~"
    test "$format" = mp3 -o "$format" = ogg && input_format="$format"
  fi
  oggenc_set_flags
  echo "$in_file: format=$input_format bitrate=$bitrate oggenc_flags='$oggenc_flags'" >>"@datadir@/log/ova-conv"
else
  echo "$in_file: override oggenc_flags='$oggenc_flags'" >>"@datadir@/log/ova-conv"
fi
oggenc $oggenc_flags "$wave_file" 2>&1 </dev/null | cr2lf |
  grep --line-buffered "^[[:blank:]]*\[" >>"$base.encoding"
rm -f "$base.encoding"
sync
rm -f "$wave_file"
cleanup_errorlog
