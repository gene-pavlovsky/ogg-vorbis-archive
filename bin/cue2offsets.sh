#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# ova-cue2offsets: convert a cue sheet to offsets file readable by tracksplit

. "@sysconfdir@/global.conf"
. "@datadir@/global"

if test $# -lt 1; then
  echo "Usage: cue2offsets file.cue" >&4
  exit 1
fi
cat $1 | grep ' *INDEX 01' | sed 's/ *INDEX 01 *\([0-9:]*\).*/\1/' | while read time; do
  hours=$(echo $time | cut -d: -f1)
  mins=$(echo $time | cut -d: -f2)
  frames=$(echo $time | cut -d: -f3)
  offset=$(((10#$hours*60+10#$mins)*75+10#$frames))
  echo $offset
done
cleanup_errorlog
