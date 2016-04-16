#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# ova: console dialog-based interface

. "@sysconfdir@/global.conf"
. "@datadir@/global"
load_config music.conf cddb.conf main.conf

test $ui_update_rate -ne 0 &&
  ui_update_cycle=$((1000000000*1000/ui_update_rate)) || ui_update_cycle=0

usage()
{
  {
    echo "Usage: $(basename $0)"
    echo
    echo "Provides console dialog-based interface to ova functionality."
    general_help
  } >&4
  exit 2
}

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

current_relative_dir()
{
  declare current_rel_dir=$(stripprefix $dir $selected_directory)
  echo "${current_rel_dir:-''}"
}

# **********************************************************
# split_tracks {                                           *
# **********************************************************

split_tracks()
{
  declare -a playlength tlength split_list split_name
  declare dir split_echo split_count out_file dec_pid ui_starttime_s \
    elapsed ui_starttime_us time_s time_us dec_progress dec_len time_start \
    est tn out_size out_dir ext out_track_count out_track_totalsize ext \
    out_track_size track_count i j line split_tracks_choice tag_file last_progress

  while read dir; do
    echo "$dir" | grep '^various\|[^/]*/various\($\|/\)' &>/dev/null && continue
    clear_screen
    echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
    echo -n "listing files... "
    find "$dir" -maxdepth 1 -type f -name "*.mp3" 2>/dev/null |
      sort >/tmp/ova.split_tracks_file_list.$$
    track_count=$(wc -l /tmp/ova.split_tracks_file_list.$$ | sed 's/^ *\([0-9]*\).*/\1/')
    if test $track_count -eq 0; then
      find "$dir" -maxdepth 1 -type f -name "*.wav" 2>/dev/null |
        sort >/tmp/ova.split_tracks_file_list.$$
      track_count=$(wc -l /tmp/ova.split_tracks_file_list.$$ | sed 's/^ *\([0-9]*\).*/\1/')
    fi
    echo -e "done\n"
    test $track_count -eq 0 && continue
    clear_screen
    echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
    i=1
    heartbeat_init
    while read line; do
      echo -ne "\rgetting play length from file $CL1$(zeropad $i 2)$RST/$CL1$(zeropad $track_count 2)$RST: "
      get_playlength "$line"
      split_name[$i]="$(stripprefix "$line" "$dir")"
      let playlength[i]=playlength/1000
      let tlength[i]=playlength/100
      if test ${playlength[$i]} -ge $track_split_playlength; then
        split_list[$i]=1
      else
        split_list[$i]=0
      fi
      heartbeat
      let ++i
    done </tmp/ova.split_tracks_file_list.$$
    echo done
    while true; do
      clear_screen
      echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
      for ((j=1; j<i; ++j)); do
        test ${split_list[$j]} -eq 1 && split_echo="${CL1} y $RST" || split_echo=" - "
        printf "$CL1$(spacepad $j ${#i})$RST:  ${CL1}%2.1d$RST:${CL1}%.2d$RST $split_echo $CL2${split_name[$j]}$RST\n" \
          $((${playlength[$j]}/60)) $((${playlength[$j]}%60))
      done
      echo
      echo -e "${CL1}a$RST/${CL1}n$RST: select all/no tracks for splitting"
      printf "${CL1}p$RST: select only tracks longer than %2.1d:%.2d\n" $((track_split_playlength/60)) $((track_split_playlength%60))
      echo -e "${CL1}c$RST: confirm the current selection"
      echo
      echo -e "${CL1}s$RST: skip this directory"
      echo -e "${CL1}q$RST: quit to the main menu"
      echo
      ask "action" split_tracks_choice "$default_split_tracks_choice"

      if test "$split_tracks_choice" = q; then
        should_abort=yes
        last_outcome="aborted by user"
        return 0
      elif test "$split_tracks_choice" = s; then
        continue 2
      elif test "$split_tracks_choice" = c; then
        break
      elif test "$split_tracks_choice" = a; then
        for ((j=1; j<i; ++j)); do
          split_list[$j]=1
        done
        continue
      elif test "$split_tracks_choice" = n; then
        for ((j=1; j<i; ++j)); do
          split_list[$j]=0
        done
        continue
      elif test "$split_tracks_choice" = p; then
        for ((j=1; j<i; ++j)); do
          if test ${playlength[$j]} -ge $track_split_playlength; then
            split_list[$j]=1
          else
            split_list[$j]=0
          fi
        done
        continue
      elif ! isint "$split_tracks_choice" || test $split_tracks_choice -lt 1 -o $split_tracks_choice -ge $i; then
        echo
        echo "unrecognized command: $split_tracks_choice"
        kbd_confirm
        continue
      fi
      let "split_tracks_choice=10#$split_tracks_choice"
      test ${split_list[$split_tracks_choice]} -eq 1 &&
        split_list[$split_tracks_choice]=0 ||
        split_list[$split_tracks_choice]=1
    done

    split_count=0
    for ((j=1; j<i; ++j)); do
      test ${split_list[$j]} -eq 1 && let ++split_count
    done
    if test $split_count -gt 0; then
      for ((j=1; j<i; ++j)); do
        test ${split_list[$j]} -ne 1 && continue
        clear_screen
        echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
        echo -e "track: '$CL2${split_name[$j]}$RST'"
        echo
        ask "CDDB category and discid" cddb_entry
        test -z "$cddb_entry" && continue
        "@bindir@/ova-cddb_read" --print-offsets $cddb_entry >/tmp/ova.split_tracks_offsets.$$ 2>/dev/null
        if test $(stat -c %s /tmp/ova.split_tracks_offsets.$$ 2>/dev/null) -eq 0; then
          error="CDDB read for '$cddb_entry' returned no track frame offsets"
          clear_screen
          return 1
        fi
        out_dir="$dir/$(echo $cddb_entry | sed 'y/ /_/')"
        mkdir "$out_dir" &>/dev/null
        out_file="$dir/$(echo "${split_name[$j]}" | sed 's/\.[^.]*$/.raw/')"
        tag_file=$(echo "$dir/${split_name[$j]}" | sed 's/\.[^.]*$/.tag~/')
        ext=$(echo "${split_name[$j]}" | sed 's/.*\.\([^.]*\)\|.*/\1/')
        if test "$ext" != wav; then
          grep ^bitrate= "$tag_file" &>/dev/null || "@bindir@/ova-gettag" --tag-only "$dir/${split_name[$j]}"
          cat "$tag_file" | grep -e '^format=' -e '^bitrate=' >/tmp/ova.split_tracks_tagfile.$$
          mv -f /tmp/ova.split_tracks_tagfile.$$ "$tag_file"
        fi
        get_playlength "$out_file"
        if test $(abs $((tlength[j]-playlength/100))) -gt $encdec_deviation; then
          echo
          last_progress=0
          mplayer -vo null -ao pcm:nowaveheader:file="$out_file" "$dir/${split_name[$j]}" 2>&1 </dev/null |
            cr2lf | grep --line-buffered "^A:" >/tmp/ova.split_tracks_progress.$$ &
          dec_pid=$!
          time_start=$(gettimeofday -s)
          trap 'should_abort=yes' int
          while ps -p $dec_pid &>/dev/null; do
            if test "$should_abort" = yes; then
              trap '' int
              kill $dec_pid &>/dev/null
              rm -f "$out_file"
              last_outcome="aborted by user"
              return 0
            fi
            ui_starttime_s=$(gettimeofday -s)
            ui_starttime_us=$(gettimeofday -u)
            dec_len=$(encode_parse_mplayer_log /tmp/ova.split_tracks_progress.$$)
            isint "$dec_len" && let dec_progress=dec_len*1000/tlength[j] || dec_progress=$last_progress
            last_progress=$dec_progress
            let elapsed=$(gettimeofday -s)-time_start
            printf "\r$ext->raw: $CL1%3.1d.%.1d$RST%% done"  $((dec_progress/10)) $((dec_progress%10))
            test $dec_progress -ne 1000 && est=$(estimated_total $((dec_progress*1000)) $elapsed) || est=$elapsed
            printf ", elapsed/eta/total: $CL1%2.1d$RST:$CL1%.2d$RST / " $((elapsed/60)) $((elapsed%60))
            if test "$est"; then
              test $est -lt $elapsed && est=$elapsed
              printf "$CL1%2.1d$RST:$CL1%.2d$RST / $CL1%2.1d$RST:$CL1%.2d$RST\033[K" $(((est-elapsed)/60)) $(((est-elapsed)%60)) $((est/60)) $((est%60))
            else
              printf " ${CL1}wait$RST /  ${CL1}wait$RST\033[K"
            fi
            time_s=$(($(gettimeofday -s)-ui_starttime_s))
            time_us=$(($(gettimeofday -u)-ui_starttime_us))
            test $time_s -ge 1 && let time_us+=1000000
            let "time_us=ui_update_cycle-time_us*1000"
            test $time_us -gt 0 && nanosleep $((time_us/1000000000)) $((time_us%1000000000))
          done
          trap '' int
          get_playlength "$out_file"
          if test $(abs $((tlength[j]-playlength/100))) -gt $encdec_deviation; then
            error="raw file '$CL2$out_file$RST' has wrong size for the input file"
            clear_screen
            return 1
          fi
          echo -e "\r$ext->raw:\033[K done"
        fi
        echo
        out_size=$(stat -c %s "$out_file" 2>/dev/null)
        out_track_count=$(wc -l /tmp/ova.split_tracks_offsets.$$ | sed 's/^ *\([0-9]*\).*/\1/')
        if test -d "$out_dir"; then
          out_track_totalsize=0
          for ((tn=1; tn<=out_track_count; ++tn)); do
            out_track_size=$(stat -c %s "$out_dir/track$(zeropad $tn 2).wav" 2>/dev/null)
            isint "$out_track_size" && let out_track_totalsize+=out_track_size || break
          done
          if test $out_track_totalsize -eq $((out_size+44*out_track_count)); then
            rm -f "$out_file" "$dir/${split_name[$j]}"
            continue
          fi
        fi
        trap 'kill $(ps h -o pid --ppid $$ 2>/dev/null) &>/dev/null; should_abort=yes' int
        "@bindir@/tracksplit" --seek=0 "$out_file" /tmp/ova.split_tracks_offsets.$$ \
          "$out_dir" 2>/tmp/ova.split_tracks_error.$$
        trap '' int
        if test "$should_abort" = yes; then
          rm -f "$out_dir/track"??.wav &>/dev/null
          rmdir "$out_dir" &>/dev/null
          last_outcome="aborted by user"
          return 0
        fi
        if test $(stat -c %s /tmp/ova.split_tracks_error.$$ 2>/dev/null) -gt 0; then
          rm -f "$out_dir/track"??.wav
          rmdir "$out_dir" &>/dev/null
          error="tracksplit has failed"
          errorlog=/tmp/ova.split_tracks_error.$$
          clear_screen
          return 1
        fi
        out_track_totalsize=0
        for ((tn=1; tn<=out_track_count; ++tn)); do
          out_track_size=$(stat -c %s "$out_dir/track$(zeropad $tn 2).wav" 2>/dev/null)
          isint "$out_track_size" && let out_track_totalsize+=out_track_size || break
        done
        if test $out_track_totalsize -ne $((out_size+44*out_track_count)); then
          rm -f "$out_dir/track"??.wav
          rmdir "$out_dir" &>/dev/null
          error="output has wrong size for the raw file"
          clear_screen
          return 1
        fi
        "@bindir@/ova-cddb_read" --print-discid $cddb_entry >"$out_dir/discid~" 2>/dev/null
        if grep ^bitrate= "$tag_file" &>/dev/null; then
          for ((tn=1; tn<=out_track_count; ++tn)); do
            cp -f "$tag_file" "$out_dir/track$(zeropad $tn 2).tag~" 2>/dev/null
          done
        fi
        rm -f "$out_file" "$tag_file" "$dir/${split_name[$j]}"
        echo "${split_name[$j]} -> $out_dir" >>"@datadir@/log/ova.tracksplit"
        let ++stat_count
      done
    fi
  done </tmp/ova.split_tracks_dir_list.$$
}

# **********************************************************
# split_tracks }                                           *
# **********************************************************

# **********************************************************
# encode {                                                 *
# **********************************************************

# writes the number of seconds parsed from the mplayer log
# args: $1 - mplayer log filename
encode_parse_mplayer_log()
{
  declare line=$(tail -n 1 "$1" 2>/dev/null)
  declare hours=10#$(echo "$line" | sed 's/^A: *\([0-9]*\):[0-9]*:[0-9]*\..*\|.*/\1/')
  declare mins=10#$(echo "$line" | sed 's/^A: *\([0-9:]*:\)\?\([0-9]*\):[0-9]*\..*\|.*/\2/')
  declare seconds=10#$(echo "$line" | sed 's/^A: *\([0-9:]*:\)\?\([0-9]*\)\..*\|.*/\2/')
  declare seconds10=10#$(echo "$line" | sed 's/^A: *[0-9:]*\.\([0-9]\).*\|.*/\1/')
  echo $((seconds10+seconds*10+mins*600+hours*36000))
}

# writes the completed percentage parsed from the oggenc log
# args: $1 - oggenc log filename
encode_parse_oggenc_log()
{
  declare line=$(tail -n 1 "$1" 2>/dev/null)
  declare percents=10#$(echo "$line" | sed 's/^[[:blank:]]*\[ *\([0-9]*\).*\|.*/\1/')
  declare percents10=10#$(echo "$line" | sed 's/^[[:blank:]]*\[ *[0-9]*\.\([0-9]\).*\|.*/\1/')
  echo $((percents10+percents*10))
}

# args: $1 - job number
encode_get_status()
{
  declare old_status="${enc_status[$1]}"
  if test -f "${enc_fbase[$1]}.decoding"; then
    enc_status[$1]=decoding
  elif test -f "${enc_fbase[$1]}.encoding"; then
    enc_status[$1]=encoding
  elif test "$old_status" = init -o "$old_status" = decoding; then
    enc_status[$1]=init
  elif test "$old_status" = encoding -o "$old_status" = done; then
    enc_status[$1]=done
  fi
  if test "${enc_status[$i]}" != decoding -a "$old_status" = decoding -a -z "${dec_considered[$i]}"; then
    let len_dec_fulldone+=enc_flength[i]
    dec_considered[$i]=1
  fi
  if test "${enc_status[$i]}" != "$old_status" || ! isint "${enc_starttime[$i]}"; then
    enc_progress[$i]=
    enc_starttime[$i]=$(gettimeofday -s)
  fi
  if test "${enc_status[$i]}" = decoding; then
    if test "${enc_progress[$i]}" != "1000"; then
      decoded_len=$(encode_parse_mplayer_log "${enc_fbase[$i]}.decoding")
      isint "$decoded_len" && let enc_progress[i]=decoded_len*1000/enc_flength[i] ||
        enc_progress[$i]=
    fi
  elif test "${enc_status[$i]}" = encoding; then
    if test "${enc_progress[$i]}" != "1000"; then
      oggenc_progress=$(encode_parse_oggenc_log "${enc_fbase[$i]}.encoding")
      isint "$oggenc_progress" && enc_progress[$i]=$oggenc_progress ||
        enc_progress[$i]=
    fi
  elif test "${enc_status[$i]}" = done; then
    enc_progress[$i]=1000
  else
    enc_progress[$i]=
  fi
  isint "${enc_progress[$i]}" && test ${enc_progress[$i]} -gt 1000 && enc_progress[$i]=1000
}

encode_display_file_stats()
{
  declare estimated
  if test -z "$1"; then
    echo -e "${CL2}none$RST"
    echo -e "  ${CL1}free$RST"
    return
  fi
  echo -e "$CL2$1$RST"
  isint "$4" "$5" && estimated=$(($5-$4)) || estimated=
  printf "          \r  $CL1%s$RST\033[11G: " "$2"
  isint "$3" && printf "$CL1%3.1d.%.1d$RST%% done, " $(($3/10)) $(($3%10)) ||
    printf "             "
  printf "elapsed/eta/total: "
  isint "$4" && printf "$CL1%2.1d$RST:$CL1%.2d$RST / " $(($4/60)) $(($4%60)) ||
    printf " ${CL1}wait$RST / "
  if isint "$estimated" && test $estimated -eq 0; then
    printf " ${CL1}done$RST /  ${CL1}done$RST"
  else
    isint "$estimated" && printf "$CL1%2.1d$RST:$CL1%.2d$RST / " $((estimated/60)) $((estimated%60)) ||
      printf " ${CL1}wait$RST / "
    isint "$5" && printf "$CL1%2.1d$RST:$CL1%.2d$RST" $(($5/60)) $(($5%60)) ||
      printf " ${CL1}wait$RST"
  fi
  echo
}

encode_display_full_stats()
{
  declare denominator i decdone_len encdone_len
  test $files_left -lt 0 && files_left=0
  clear_screen
  echo -e "$CL1$last_action$RST\n"
  echo -e "$CL1$current_jobs$RST/$CL1$max_jobs$RST $(noun_form job $max_jobs) running, $CL1$stat_count$RST/$CL1$fcount$RST $(noun_form track $fcount) done, $CL1$files_left$RST $(noun_form track $files_left) queued\n"
  time_s=$(gettimeofday -s)
  let len_dec_done=len_dec_fulldone*1000
  let len_enc_done=len_enc_fulldone*1000
  if test "$total_reset"; then
    total_declen=$len_dec_fulldone
    total_enclen=$len_enc_fulldone
    for ((i=0; i<max_jobs; ++i)); do
      test "${enc_status[$i]}" = free && continue
      test -z "${dec_considered[$i]}" && let total_declen+=enc_flength[i]
      let total_enclen+=enc_flength[i]
    done
    total_reset=
    total_reset_happened=yes
  fi
  for ((i=0; i<max_jobs; ++i)); do
    test "${enc_status[$i]}" = free && continue
    if isint "${enc_progress[$i]}"; then
      if test "${enc_status[$i]}" = decoding; then
        let len_dec_done+=enc_flength[i]*enc_progress[i]
      else
        let len_enc_done+=enc_flength[i]*enc_progress[i]
      fi
    fi
  done
  let decdone_len=len_dec_done/10000
  let encdone_len=len_enc_done/10000
  let len_enc_done=1000*len_enc_done/total_enclen
  test $len_enc_done -eq 0 && progchar="*" || progchar=
  if test $total_declen -ne 0; then
    let len_dec_done=1000*len_dec_done/total_declen
    let denominator=10*total_declen+encdec_speed_ratio*total_enclen
    let "total_progress=len_dec_done*(10000000*total_declen/denominator)/1000000+len_enc_done*(encdec_speed_ratio*1000000*total_enclen/denominator)/1000000"
  else
    let "total_progress=len_enc_done"
  fi
  let time=time_s-total_start
  if test $total_declen -ne 0; then
    test $((len_dec_done+len_enc_done)) -ne 2000 && est_total=$(estimated_total $total_progress $time) || est_total=
    printf "total decoding progress: $CL1%3.1d.%.1d$RST%% ( $CL1%d$RST:$CL1%.2d$RST / $CL1%d$RST:$CL1%.2d$RST )\n" \
      $((len_dec_done/10000)) $(((len_dec_done/1000)%10)) $((decdone_len/60)) $((decdone_len%60)) $(((total_declen/10)/60)) $(((total_declen/10)%60))
  else
    test $len_enc_done -ne 1000 && est_total=$(estimated_total $total_progress $time) || est_total=
  fi
  printf "total encoding progress: $CL1%3.1d.%.1d$RST%% ( $CL1%d$RST:$CL1%.2d$RST / $CL1%d$RST:$CL1%.2d$RST )\n" \
    $((len_enc_done/10000)) $(((len_enc_done/1000)%10)) $((encdone_len/60)) $((encdone_len%60)) $(((total_enclen/10)/60)) $(((total_enclen/10)%60))
  echo
  printf "elapsed time:   $CL1%3.1d$RST:$CL1%.2d$RST\n" $((time/60)) $((time%60))
  printf "estimated time: "
  isint "$time" "$est_total" && let est=est_total-time || est=
  isint "$est" && printf "$CL1%3.1d$RST:$CL1%.2d$CL2$progchar$RST\n" $((est/60)) $((est%60)) ||
    printf "  ${CL1}wait$RST\n"
  printf "total time:     "
  isint "$est_total" && printf "$CL1%3.1d$RST:$CL1%.2d$CL2$progchar$RST\n" $((est_total/60)) $((est_total%60)) ||
    printf "  ${CL1}wait$RST\n"
  echo
  for ((i=0; i<max_jobs; ++i)); do
    if isint "${enc_starttime[$i]}"; then
      let time=time_s-enc_starttime[i]
      est_total=$(estimated_total $((enc_progress[$i]*1000)) $time)
    else
      time=
      est_total=
    fi
    encode_display_file_stats "${enc_fdisplayname[$i]}" "${enc_status[$i]}" "${enc_progress[$i]}" "$time" "$est_total"
  done
}

encode()
{
  declare current_jobs=0 files_left=0 est_total est time time_s time_us \
    total_start len_dec_done len_enc_done total_progress total_reset \
    len_dec_fulldone=0 len_enc_fulldone=0 progchar fcount line i j \
    total_enclen=0 total_declen=0 ui_starttime_s ui_starttime_us \
    total_reset_happened=
  declare -a enc_status enc_fbase enc_fdisplayname enc_pid enc_progress \
    enc_flength enc_starttime dec_considered

  files_left=$(wc -l /tmp/ova.encode_list.$$ | sed 's/^ *\([0-9]*\).*/\1/')
  fcount="$files_left"
  test -z "$fcount" -o $fcount -eq 0 && return 0
  rm -f /tmp/ova.encode_errorlog.$$

  clear_screen
  echo -e "$CL1$last_action$RST\n"
  for ((i=0; i<max_jobs; ++i)); do
    enc_status[$i]=free
  done
  echo -n "calculating total play length: "
  i=1
  while read file; do
    echo -ne "\033[32G$CL1$(zeropad $i ${#files_left})$RST / $CL1$files_left$RST"
    if test -f "$file"; then
      get_playlength "$file"
      let total_enclen+=playlength/100
      test "$(echo "$file" | sed 's/.*\.\([^.]*\)\|.*/\1/')" != wav &&
        let total_declen+=playlength/100
    fi
    let ++i
  done </tmp/ova.encode_list.$$
  echo -e "\033[32G\033[Kdone"

  total_start=$(gettimeofday -s)
  clear_screen
  trap 'should_abort=yes' int
  trap 'test $files_left -ne 0 && { files_left=0; total_reset=1; }' quit
  while read file; do
    if test -f "$file"; then
      for ((i=0; i<max_jobs; ++i)); do
        # if there are free slots in the jobs list, run more jobs
        if test "${enc_status[$i]}" = free; then
          get_playlength "$file"
          if test $playlength -ne 0; then
            enc_status[$i]=init
            enc_fbase[$i]=$(echo "$file" | sed 's/\.[^.]*$//')
            enc_fdisplayname[$i]=$(stripprefix "$file" "$selected_directory")
            enc_progress[$i]=
            enc_starttime[$i]=
            let enc_flength[i]=playlength/100
            test ${enc_flength[i]} -eq 0 && enc_flength[i]=1
            "@bindir@/ova-conv" "$file" >/dev/null 2>"${enc_fbase[$i]}.error" </dev/null &
            enc_pid[$i]=$!
            let ++current_jobs
          fi
          let --files_left
          test "$(echo "$file" | sed 's/.*\.\([^.]*\)\|.*/\1/')" = wav &&
            dec_considered[$i]=1 || dec_considered[$i]=
          encode_display_full_stats
          test $current_jobs -lt $max_jobs -a $files_left -gt 0 && continue 2
          test $files_left -eq 0 && break
        fi
      done
    else
      let --files_left
      test $current_jobs -lt $max_jobs -a $files_left -gt 0 && continue
    fi

    while true; do
      ui_starttime_s=$(gettimeofday -s)
      ui_starttime_us=$(gettimeofday -u)

      if test "$should_abort" = yes; then
        trap '' int quit
        for ((i=0; i<max_jobs; ++i)); do
          test "${enc_status[$i]}" = free && continue
          kill $(ps h -o pid --ppid ${enc_pid[$i]} 2>/dev/null) ${enc_pid[$i]} &>/dev/null
          rm -f "${enc_fbase[$i]}.decoding" "${enc_fbase[$i]}.encoding" "${enc_fbase[$i]}.error"
        done
        if test -f /tmp/ova.encode_errorlog.$$; then
          cp /tmp/ova.encode_errorlog.$$ "@datadir@/log/ova.encode_errors"
          error="aborted by user; list follows\nerror log: '$CL2@datadir@/log/ova.encode_errors$RST'"
          errorlog=/tmp/ova.encode_errorlog.$$
          clear_screen
          return 1
        fi
        last_outcome="aborted by user"
        return 0
      fi

      for ((i=0; i<max_jobs; ++i)); do
        test "${enc_status[$i]}" = free && continue
        encode_get_status $i
        if ! ps -p ${enc_pid[$i]} &>/dev/null; then
	  if test "${enc_status[$i]}" = decoding; then
            test -f /tmp/ova.encode_errorlog.$$ && echo >>/tmp/ova.encode_errorlog.$$
            echo -e "possible problems with decoding '$CL2${enc_fdisplayname[$i]}$RST'" >>/tmp/ova.encode_errorlog.$$
            cat "${enc_fbase[$i]}.error" >>/tmp/ova.encode_errorlog.$$
            rm -f "${enc_fbase[$i]}.decoding" "${enc_fbase[$i]}.encoding"
	  fi
	  rm -f "${enc_fbase[$i]}.error"
	  test -z "${dec_considered[$i]}" && let len_dec_fulldone+=enc_flength[i]
	  let len_enc_fulldone+=enc_flength[i]
	  enc_status[$i]=free
	  enc_fbase[$i]=
	  enc_fdisplayname[$i]=
	  enc_pid[$i]=
	  enc_progress[$i]=
	  enc_flength[$i]=
	  enc_starttime[$i]=
	  dec_considered[$i]=
	  let --current_jobs
	  let ++stat_count
	  continue
	fi
      done

      encode_display_full_stats

      if test $current_jobs -lt $max_jobs; then
        test $files_left -gt 0 && break
	test $current_jobs -eq 0 && break 2
      fi

      time_s=$(($(gettimeofday -s)-ui_starttime_s))
      time_us=$(($(gettimeofday -u)-ui_starttime_us))
      test $time_s -ge 1 && let time_us+=1000000
      let "time_us=ui_update_cycle-time_us*1000"
      test $time_us -gt 0 && nanosleep $((time_us/1000000000)) $((time_us%1000000000))
    done
  done </tmp/ova.encode_list.$$

  trap '' int quit
  if test "$total_reset_happened" = yes; then
    if test -f /tmp/ova.encode_errorlog.$$; then
      cp /tmp/ova.encode_errorlog.$$ "@datadir@/log/ova.encode_errors"
      error="aborted by user; list follows\nerror log: '$CL2@datadir@/log/ova.encode_errors$RST'"
      errorlog=/tmp/ova.encode_errorlog.$$
      clear_screen
      return 1
    fi
    last_outcome="aborted by user"
    return 0
  fi
  if test -f /tmp/ova.encode_errorlog.$$; then
    cp /tmp/ova.encode_errorlog.$$ "@datadir@/log/ova.encode_errors"
    error="list follows\nerror log: '$CL2@datadir@/log/ova.encode_errors$RST'"
    errorlog=/tmp/ova.encode_errorlog.$$
    clear_screen
    return 1
  fi
}

# **********************************************************
# encode }                                                 *
# **********************************************************

# **********************************************************
# identify {                                               *
# **********************************************************

# setup patterns for pathname matching
# args: $1 - pattern
identify_path_pattern_set()
{
  declare match match2 current match_full pos i j count
  for match in artist album title tracknumber; do
    eval path_$match=
    current="$1"
    if ! echo "$current" | grep $match &>/dev/null; then
      eval mpat_$match=
      continue
    fi
    for match2 in artist album title tracknumber; do
      if test "$match" != "$match2"; then
        match_full=pattern_$match2
        match_full=$(echo "${!match_full}" | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g')
        current=$(echo "$current" |
          sed 's/\$'"$match2"'/'"$match_full"'/' 2>/dev/null)
      fi
    done
    pos=$(strstr "$current" "\$$match")
    i=0
    j=0
    count=0
    while true; do
      i=$(strstr "${current:j}" "\(") || break
      let j+=i
      test $j -ge $pos && break
      let ++count
      let j+=2
      test $j -ge $pos && break
    done
    let ++count
    match_full=pattern_$match
    match_full=$(echo "${!match_full}" | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g')
    current=$(echo "$current" |
      sed 's/\$'"$match"'/\\('"$match_full"'\\)/' 2>/dev/null)
    eval mpat_$match='$current'
    eval mpat_${match}_pos='$count'
  done
}

# match a pathname against patterns
# args: $1 - pathname
identify_path_pattern_match()
{
  declare match current pos
  for match in artist album title tracknumber; do
    eval path_$match=
    current=mpat_$match
    current="${!current}"
    test -z "$current" && continue
    pos=mpat_${match}_pos
    pos="${!pos}"
    eval path_$match='$(echo "$1" | sed "s/$current\|.*/\\$pos/" 2>/dev/null)'
  done
}

identify_cddb_submit_write()
{
  declare left="$2"
  if test -z "$left"; then
    echo "$1="
  else
    while test ${#left} -gt 0; do
      echo "$1=${left:0:$((79-${#1}))}"
      left="${left:$((79-${#1}))}"
    done
  fi
}

identify_display_info()
{
  if test "$1" != pager; then
    clear_screen
    identify_info_format
    echo
  fi
  if test "$use_pager" = auto; then
    if test $track_count -ge $use_pager_auto_track_count; then
      really_use_pager=yes
    else
      really_use_pager=no
    fi
  else
    really_use_pager="$use_pager"
  fi
  if test "$really_use_pager" = yes -a "$1" != pager; then
    echo -n "displaying info... "
    identify_display_info pager >/tmp/ova.identify_display_info.$$
    echo "$PAGER" | grep '^less\($\| \)' &>/dev/null &&
      $PAGER -f /tmp/ova.identify_display_info.$$ <&3 ||
      $PAGER /tmp/ova.identify_display_info.$$ <&3
    echo done
  else
    echo -e "tracks: $CL1$track_count_padded$RST\n"
    echo -e "artist: $CL1${artist:-''}$RST"
    echo -e "album:  $CL1${album:-''}$RST"
    echo -e "date:   $CL1${date:-''}$RST"
    echo -e "genre:  $CL1${genre:-''}$RST"
    echo
    for ((i=1; i<=track_count; ++i)); do
      echo -e "($CL2$(zeropad $i 2)$RST/$CL2$track_count_padded$RST)" \
        "$CL2$(basename "${track_fname[$i]}")$RST"
      if test -z "$artist"; then
        echo -e "  ${CL1}track ${track_number[$i]}$RST:" \
          "${track_artist[$i]:-''} $CL1-$RST ${track_title[$i]:-''}"
      else
        echo -e "  ${CL1}track ${track_number[$i]}$RST:" \
          "${track_title[$i]:-''}"
      fi
    done
  fi
}

identify_info_reset()
{
  artist=
  album=
  date=
  genre=
  for ((i=1; i<=track_count; ++i)); do
    track_title[$i]=
    track_artist[$i]=
    track_number[$i]=
  done
}

identify_info_format()
{
  echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
  echo -n "formatting info: "
  heartbeat_init
  conv_2lcase artist album date genre
  for ((i=1; i<=track_count; ++i)); do
    heartbeat
    conv_2lcase track_artist[$i] track_title[$i]
    test -z "${track_number[$i]}" && track_number[$i]=$(zeropad $i 2)
    test "$artist" -a -z "${track_artist[$i]}" && track_artist[$i]="$artist"
  done
  if test "$misc" != no; then
    artist=
    album=
    date=
    genre=$(current_relative_dir | sed 's/\([^/]*\)\/misc\/\?\|.*$/\1/')
    for ((i=1; i<=track_count; ++i)); do
      track_number[$i]=
    done
  fi
  genre=$(echo "$genre" | sed -f "@datadir@/genre_transform")
  conv_uscores2spaces artist album date genre
  artist=$(echo "$artist" | sed 's/ \{2,\}/ /g')
  album=$(echo "$album" | sed 's/ \{2,\}/ /g')
  date=$(echo "$date" | sed 's/ \{2,\}/ /g')
  genre=$(echo "$genre" | sed 's/ \{2,\}/ /g')
  for ((i=1; i<=track_count; ++i)); do
    heartbeat
    conv_uscores2spaces track_artist[$i] track_title[$i]
    track_artist[$i]=$(echo "${track_artist[$i]}" | sed 's/ \{2,\}/ /g')
    track_title[$i]=$(echo "${track_title[$i]}" | sed 's/ \{2,\}/ /g')
  done
  echo done
}

identify_cddb_query()
{
  declare cddb_status
  echo -n "performing CDDB query... "
  if test "$discid_file"; then
    "@bindir@/ova-cddb_query" "$discid_file" \
      >/tmp/ova.identify_cddb_query.$$
  else
    "@bindir@/ova-cddb_query" --filelist=/tmp/ova.identify_file_list.$$ \
      >/tmp/ova.identify_cddb_query.$$
  fi
  cddb_status=$(head -n 1 /tmp/ova.identify_cddb_query.$$)
  echo done
  case ${cddb_status:0:3} in
    200)
      cddb_match_exact=1
      cddb_match_count=1
      cddb_match[1]="${cddb_status:4}"
    ;;
    210|211)
      test "${cddb_status:0:3}" = 210 && cddb_match_exact=1 || cddb_match_exact=0
      cddb_match_count=0
      while read line; do
        test "${line:0:2}" = 21 -o "$line" = . && continue
        let ++cddb_match_count
        cddb_match[$cddb_match_count]="$line"
      done </tmp/ova.identify_cddb_query.$$
    ;;
    *)
      cddb_match_count=0
    ;;
  esac
}

identify_cddb_choose()
{
  declare va_true=auto empty
  cddb_ok=
  while isint "$cddb_match_count"; do
    identify_info_reset
    clear_screen
    echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
    if test $cddb_match_count -eq 0; then
      echo "no CDDB matches"
    else
      if test $cddb_match_exact -eq 1; then
        echo "exact CDDB $(noun_form match $cddb_match_count)"
      else
        echo "inexact CDDB $(noun_form match $cddb_match_count)"
      fi
      echo
      for ((i=1; i<=cddb_match_count; ++i)); do
        echo -e "$CL1$(spacepad $i ${#cddb_match_count})$RST: ${cddb_match[$i]}"
      done
    fi
    echo
    echo -e "${CL1}m$RST: manual selection"
    echo -e "${CL1}n$RST: none of the above"
    echo
    echo -e "${CL1}v$RST: various = ${CL1}$va_true$RST"
    echo
    echo -e "${CL1}s$RST: skip this directory"
    echo -e "${CL1}q$RST: quit to the main menu"
    echo
    ask "action" identify_choice "$default_cddb_match_choice"

    if test "$identify_choice" = q; then
      should_abort=yes
      last_outcome="aborted by user"
      return 1
    elif test "$identify_choice" = s; then
      continue 2
    elif test "$identify_choice" = n; then
      break
    elif test "$identify_choice" = m; then
      echo
      ask "CDDB category and discid" cddb_entry
      test -z "$cddb_entry" && continue
      identify_choice=$((cddb_match_count+1))
      cddb_match[$identify_choice]="$cddb_entry"
    elif test "$identify_choice" = v; then
      case $va_true in
        auto) va_true=yes ;;
        yes) va_true=no ;;
        no) va_true=auto ;;
      esac
      continue
    elif test "$identify_choice" = vv; then
      case $va_true in
        auto) va_true=no ;;
        yes) va_true=auto ;;
        no) va_true=yes ;;
      esac
      continue
    elif ! isint "$identify_choice" || test $identify_choice -lt 1 -o $identify_choice -gt $cddb_match_count; then
      echo
      echo "unrecognized command: $identify_choice"
      kbd_confirm
      continue
    fi
    let "identify_choice=10#$identify_choice"

    cddb_track_count=0
    echo
    if ! cddb_read_process "$(echo "${cddb_match[$identify_choice]}" | cut -d' ' -f1-2)" \
      /tmp/ova.identify_cddb_read_raw.$$ /tmp/ova.identify_cddb_read.$$; then
    :
      kbd_confirm
      continue
    fi

    # determine if this is various artists album or not, artist/title separator
    count_dash=0
    count_slash=0
    j=
    while read line; do
      heartbeat
      pos=$(strstr "$line" '=') || continue
      left="${line:0:$pos}"
      right="${line:$((pos+1))}"
      if test "$left" = dtitle; then
        right_lcase=$(echo "$right" | sed 'y/_/ /' | dd conv=lcase 2>/dev/null)
        if test "$va_true" != yes; then
          if test "$(echo "$right_lcase" | sed 's/^\(v\.\?a\.\?\|various\|various artists\) *[/-].*$//')" -o "$va_true" = no; then
            artist=$(echo "$right" | sed 's/^\(.*\)  *\/ .*\|^\([^/]*\) *\/.*\|^\(.*\)  *- .*\|^\([^-]*\) *-.*\|.*/\1\2\3\4/')
          else
            artist=
          fi
        else
          artist=
        fi
        j="$right"
      elif test "${left:0:6}" = ttitle; then
        echo "$right" | grep -- - >/dev/null && let ++count_dash
        echo "$right" | grep / >/dev/null && let ++count_slash
        let ++cddb_track_count
      fi
    done </tmp/ova.identify_cddb_read.$$
    empty=$((track_count+1))
    track_count=$cddb_track_count
    if test "$va_true" = auto -a "$artist"; then
      test $count_dash -ge $track_count -o $count_slash -ge $track_count && artist=
    fi
    if test -z "$artist"; then
      album=$(echo "$j" | sed 's/^[vV][^/]*\/ *\(.*\)\|^[vV][^-]*- *\(.*\)\|\(.*\)/\1\2\3/')
    else
      album=$(echo "$j" | sed 's/^.* \/  *\(.*\)\|^[^/]*\/ *\(.*\)\|^.* -  *\(.*\)\|^[^-]*- *\(.*\)\|\(.*\)/\1\2\3\4\5/')
    fi
    stripspaces artist album
    track_count_padded=$(zeropad $track_count 2)

    while read line; do
      heartbeat
      pos=$(strstr "$line" '=') || continue
      left="${line:0:$pos}"
      right="${line:$((pos+1))}"
      if test "$left" = dyear; then
        date="$right"
      elif test "$left" = dgenre; then
        genre="$right"
      elif test "$left" = extd; then
        extd="$right"
      elif test "${left:0:6}" = ttitle; then
        let "i=1+${left:6}"
        if test -z "$artist"; then
          if test $count_slash -ge $count_dash; then
            track_artist[$i]=$(echo "$right" | sed 's/^\(\/\?\([^/]\|[^ ]\/[^ ]\)*\/\?\)  *\/ .*\|\([^/]*\) *\/.*\|.*/\1\3/')
            track_title[$i]=$(echo "$right" | sed 's/^\/\?\([^/]\|[^ ]\/[^ ]\)*\/\?  *\/  *\(.*\)\|[^/]* *\/ *\(.*\)\|.*/\2\3/')
          else
            track_artist[$i]=$(echo "$right" | sed 's/^\(-\?\([^-]\|[^ ]-[^ ]\)*-\?\)  *- .*\|\([^-]*\) *-.*\|.*/\1\3/')
            track_title[$i]=$(echo "$right" | sed 's/^-\?\([^-]\|[^ ]-[^ ]\)*-\?  *-  *\(.*\)\|[^-]* *- *\(.*\)\|.*/\2\3/')
          fi
          if test -z "${track_artist[$i]}"; then
            track_artist[$i]="$album"
            track_title[$i]="$right"
          fi
        else
          track_artist[$i]="$artist"
          track_title[$i]="$right"
        fi
        track_number[$i]=$(zeropad $i 2)
        stripspaces track_artist[$i] track_title[$i]
      fi
    done </tmp/ova.identify_cddb_read.$$
    test -z "$album" && album="$artist"
    if test -z "$date"; then
      date=$(echo "$extd" | sed 's/.*\([0-9]\{4\}\).*\|.*/\1/')
      test "$date" && test $date -lt $year_lower_bound -o $date -gt $(date +%Y) && date=
    fi
    if test -z "$genre"; then
      genre=$(echo "$extd" | sed 's/.*ID3G: *\([0-9]\{1,\}\).*\|.*/\1/')
      if isint "$genre"; then
        genre=$(head -n $((genre+1)) "@datadir@/genre_id3v1_list" | tail -n 1)
      else
        genre=
      fi
    fi

    identify_display_info
    echo
    while true; do
      ask "accept this info [ynq]" cddb_ok "$cddb_satisfied"
      test "${cddb_ok:0:1}" = y && break 2
      test "${cddb_ok:0:1}" = n && break
      if test "${cddb_ok:0:1}" = q; then
        should_abort=yes
        last_outcome="aborted by user"
        return 1
      fi
      echo -ne "\033[1A\r\033[K"
    done
  done
  if test "${cddb_ok:0:1}" = y; then
    for ((i=$empty; i<=track_count; ++i)); do
      track_fname[$i]=
      track_title[$i]=
      track_artist[$i]=
      track_number[$i]=
    done
  fi
}

identify_tags_pathnames()
{
  clear_screen
  heartbeat_init
  echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
  echo "no info from CDDB, using tags and pathnames"
  echo
  i=1
  while read line; do
    echo -ne "\rgetting info from file $CL1$(zeropad $i 2)$RST/$CL1$real_track_count_padded$RST: "
    heartbeat
    tag_file=$(echo "$line" | sed 's/\.[^.]*$/.tag~/')
    heartbeat
    if test -f "$tag_file"; then
      grep ^tag_ "$tag_file" >/dev/null || "@bindir@/ova-gettag" --tag-only "$line"
      heartbeat
      grep ^path_ "$tag_file" >/dev/null || "@bindir@/ova-gettag" --path-only "$line"
    else
      "@bindir@/ova-gettag" "$line"
    fi
    let ++i
  done </tmp/ova.identify_file_list.$$
  echo done

  identify_choice=
  while true; do
    clear_screen
    if test -z "$identify_choice"; then
      echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
      echo "tags and pathnames guesswork"
      echo
      echo -e "${CL1}1$RST: display the current info"
      echo -e "${CL1}2$RST: read info from tags"
      echo -e "${CL1}3$RST: guess info from pathnames"
      echo -e "${CL1}4$RST: clear the current info"
      echo -e "${CL1}c$RST: confirm the current info"
      echo
      echo -e "${CL1}s$RST: skip this directory"
      echo -e "${CL1}q$RST: quit to the main menu"
      echo
      ask "action" identify_choice "$default_tags_pathnames_choice"

      if test "$identify_choice" = q; then
        should_abort=yes
        last_outcome="aborted by user"
        return 1
      elif test "$identify_choice" = s; then
        continue 2
      elif test "$identify_choice" = c; then
        break
      fi
      if ! isint "$identify_choice" || test $identify_choice -lt 1 -o $identify_choice -gt 4; then
        echo
        echo "unrecognized command: $identify_choice"
        kbd_confirm
        continue
      fi
      let "identify_choice=10#$identify_choice"
      echo
    fi

    case $identify_choice in
      1)
        if test -z "$artist"; then
          if test $track_count -ge 2; then
            left="${track_artist[1]}"
            right=
            for ((i=2; i<=track_count; ++i)); do
              if test "${track_artist[$i]}" != "$left"; then
                right=va
                break
              fi
            done
            test "$right" = va && artist= || artist="${track_artist[1]}"
          else
            artist="${track_artist[1]}"
          fi
        fi
        right_lcase=$(echo "$artist" | sed 'y/_/ /' | dd conv=lcase 2>/dev/null)
        if test -z "$(echo "$right_lcase" | sed 's/^\(v\.\?a\.\?\|various\|various artists\).*$//')"; then
          artist=
          for ((i=1; i<=track_count; ++i)); do
            test -z "${track_artist[$i]}" && track_artist[$i]="$album"
          done
        fi
        identify_display_info
        test "$really_use_pager" != yes && kbd_confirm
      ;;

      2)
        clear_screen
        echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
        i=1
        heartbeat_init
        while test -z "${track_fname[$i]}"; do
          let ++i
          test $i -gt $track_count && break
        done
        while read line; do
          echo -ne "\rreading tag $CL1$(zeropad $i 2)$RST/$CL1$real_track_count_padded$RST: "
          tag_file=$(echo "$line" | sed 's/\.[^.]*$/.tag~/')
          heartbeat
          . "$tag_file"
          heartbeat
          test -z "${track_artist[$i]}" && track_artist[$i]="$tag_artist"
          test -z "${track_title[$i]}" && track_title[$i]="$tag_title"
          test -z "${track_number[$i]}" && track_number[$i]="$tag_tracknumber"
          test -z "${track_number[$i]}" && track_number[$i]=$i
          isint "${track_number[$i]}" && track_number[$i]=$(zeropad ${track_number[$i]} 2)
          let ++i
          while test -z "${track_fname[$i]}"; do
            let ++i
            test $i -gt $track_count && break 2
          done
        done </tmp/ova.identify_file_list.$$
        test -z "$album" && album="$tag_album"
        test -z "$date" && date="$tag_date"
        test -z "$genre" && genre="$tag_genre"

        identify_choice=1
        continue
      ;;

      3)
        clear_screen
        echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
        i=1
        while test -z "${track_fname[$i]}"; do
          let ++i
          test $i -gt $track_count && break
        done
        j=$i
        pattern_previous="$pattern_selected"
        pattern_selected=
        path_date=
        path_genre=
        while read line; do
          echo -ne "\rmatching pathname $CL1$(zeropad $i 2)$RST/$CL1$real_track_count_padded$RST: "
          tag_file=$(echo "$line" | sed 's/\.[^.]*$/.tag~/')
          . "$tag_file"
          path_name=$(echo "$path_name" | sed 'y/ /_/')
          if test $i -eq $j; then
            path_date=$(echo "$path_name" | sed 's/.*\([0-9]\{4\}\).*\|.*/\1/')
            test "$path_date" && test $path_date -lt $year_lower_bound -o $path_date -gt $(date +%Y) && path_date=
            path_genre=$(echo "$path_name" | sed 's/\([^/]*\)\/.*\|.*/\1/')
            if test "$path_genre"; then
              value_matches_colonlist $(echo "$path_genre" | sed 'y/ /_/' |
                dd conv=lcase 2>/dev/null) "$genres" || path_genre=
            fi
          fi
          test "$path_date" &&
            path_name=$(echo "$path_name" | sed -e 's/[[(_,:-]*[0-9]\{4\}[])_,:-]*//' \
              -e 's/\/\{2,\}/\//g' -e 's/^\///' -e 's/\/$//')
          test "$path_genre" &&
            path_name=$(echo "$path_name" | sed 's/[^/]*\/\(.*\)/\1/')

          if test -z "$pattern_selected"; then
            pattern_num=0
            path_failed=1
            echo -e '\n'
            heartbeat_init
            while test "$path_failed" -a $pattern_num -lt $pathname_patterns_count; do
              if test "$pattern_previous"; then
                echo -ne "\rtrying pattern ${CL1}pv$RST/$CL1$(zeropad $pathname_patterns_count 2)$RST: "
              else
                echo -ne "\rtrying pattern $CL1$(zeropad $((pattern_num+1)) 2)$RST/$CL1$(zeropad $pathname_patterns_count 2)$RST: "
              fi
              heartbeat
              test "$pattern_previous" ||
                identify_path_pattern_set "${pathname_patterns[$pattern_num]}"
              identify_path_pattern_match "$path_name"
              heartbeat
              path_failed=
              for path_i in artist album title tracknumber; do
                path_j=path_$path_i
                if test "$pattern_previous"; then
                  echo "$pattern_previous" | grep $path_i &>/dev/null &&
                    test -z "${!path_j}" && path_failed=1
                else
                  echo "${pathname_patterns[$pattern_num]}" | grep $path_i &>/dev/null &&
                    test -z "${!path_j}" && path_failed=1
                fi
                heartbeat
              done
              if test "$pattern_previous"; then
                test "$path_failed" || pattern_selected="$pattern_previous"
                pattern_previous=
              else
                test "$path_failed" && let ++pattern_num
              fi
            done
            test -z "$pattern_selected" && pattern_selected="${pathname_patterns[$pattern_num]}"
            while true; do
              move_cursor 1 1
              echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
              echo -e "\rmatching pathname $CL1$(zeropad $i 2)$RST/$CL1$real_track_count_padded$RST: \033[J\n"
              echo -e "genre:  $CL1${path_genre:-''}$RST"
              echo -e "date:   $CL1${path_date:-''}$RST"
              echo
              echo -e "pathname: $CL2$path_name$RST"
              echo -e "pattern:  $CL1$pattern_selected$RST"
              test "$path_failed" &&
                echo -e "match:    ${CL2}failure$RST" ||
                echo -e "match:    ${CL2}success$RST"
              echo
              echo -e "artist: $CL1${path_artist:-''}$RST"
              echo -e "album:  $CL1${path_album:-''}$RST"
              echo -e "title:  $CL1${path_title:-''}$RST"
              echo -e "track#: $CL1${path_tracknumber:-''}$RST"
              echo
              echo -e "${CL1}1$RST: select or enter a pattern"
              echo -e "${CL1}c$RST: confirm the current pattern"
              echo -e "${CL1}n$RST: none of the patterns are suitable"
              echo
              echo -e "${CL1}s$RST: skip this directory"
              echo -e "${CL1}q$RST: quit to the main menu"
              echo
              ask "action" identify_choice

              if test "$identify_choice" = q; then
                should_abort=yes
                last_outcome="aborted by user"
                return 1
              elif test "$identify_choice" = s; then
                continue 4
              elif test "$identify_choice" = n; then
                continue 3
              elif test "$identify_choice" = c; then
                path_failed=
                for ((path_i=0; path_i<pathname_patterns_count; ++path_i)); do
                  if test "$pattern_selected" = "${pathname_patterns[$path_i]}"; then
                    path_failed=1
                    break
                  fi
                done
                if test -z "$path_failed"; then
                  array_add pathname_patterns "$pattern_selected"
                  echo "# This pattern was added on $(date --rfc-822)" >>"@sysconfdir@/music.conf"
                  echo 'array_add pathname_patterns \' >>"@sysconfdir@/music.conf"
                  echo "  '$pattern_selected'" >>"@sysconfdir@/music.conf"
                fi
                break
              elif isint "$identify_choice" && test $identify_choice -eq 1; then
                echo
                pattern_selected=$(readdef "pattern: " \
                  "$pattern_selected" "${pathname_patterns[@]}")
                identify_path_pattern_set "$pattern_selected"
                identify_path_pattern_match "$path_name"
                path_failed=
                for path_i in artist album title tracknumber; do
                  path_j=path_$path_i
                  echo "$pattern_selected" | grep $path_i &>/dev/null &&
                    test -z "${!path_j}" && path_failed=1
                done
              else
                echo
                echo "unrecognized command: $identify_choice"
                kbd_confirm
              fi
            done
            move_cursor 1 1
            echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
            echo -ne "\rmatching pathname $CL1$(zeropad $i 2)$RST/$CL1$real_track_count_padded$RST: \033[J"
            heartbeat_init
          else
            heartbeat
            identify_path_pattern_match "$path_name"
          fi

          test -z "${track_artist[$i]}" && track_artist[$i]="$path_artist"
          test -z "${track_title[$i]}" && track_title[$i]="$path_title"
          test -z "${track_number[$i]}" && track_number[$i]="$path_tracknumber"
          test -z "${track_number[$i]}" && track_number[$i]=$i
          isint "${track_number[$i]}" && track_number[$i]=$(zeropad ${track_number[$i]} 2)
          let ++i
          while test -z "${track_fname[$i]}"; do
            let ++i
            test $i -gt $track_count && break 2
          done
        done </tmp/ova.identify_file_list.$$
        test -z "$album" && album="$path_album"
        test -z "$date" && date="$path_date"
        test -z "$genre" && genre="$path_genre"

        identify_choice=1
        continue
      ;;

      4)
        identify_info_reset
      ;;
    esac

    identify_choice=
  done
}

identify_date_genre()
{
  clear_screen
  echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
  if test -z "$date" -a -z "$genre"; then
    echo "date and genre unknown, trying to use tags and pathnames"
  elif test -z "$date"; then
    echo "date unknown, trying to use tags and pathnames"
  else
    echo "genre unknown, trying to use tags and pathnames"
  fi
  echo
  i=1
  heartbeat_init
  while read line; do
    echo -ne "\rgetting info from file $CL1$(zeropad $i 2)$RST/$CL1$real_track_count_padded$RST: "
    tag_file=$(echo "$line" | sed 's/\.[^.]*$/.tag~/')
    heartbeat
    if test -f "$tag_file"; then
      grep ^tag_ "$tag_file" >/dev/null || "@bindir@/ova-gettag" --tag-only "$line"
      heartbeat
      grep ^path_ "$tag_file" >/dev/null || "@bindir@/ova-gettag" --path-only "$line"
    else
      "@bindir@/ova-gettag" "$line"
    fi
    heartbeat
    . "$tag_file"
    test -z "$date" -a "$tag_date" && date="$tag_date"
    test -z "$genre" -a "$tag_genre" && genre="$tag_genre"
    if test $i -eq 1; then
      if test -z "$date"; then
        path_date=$(echo "$path_name" | sed 's/.*\([0-9]\{4\}\).*\|.*/\1/')
        test "$path_date" && test $path_date -lt $year_lower_bound -o $path_date -gt $(date +%Y) && path_date=
        test "$path_date" && date="$path_date"
      fi
      if test -z "$genre"; then
        path_genre=$(echo "$path_name" | sed 's/\([^/]*\)\/.*\|.*/\1/')
        heartbeat
        if test "$path_genre"; then
          value_matches_colonlist $(echo "$path_genre" | sed 'y/ /_/' |
            dd conv=lcase 2>/dev/null) "$genres" || path_genre=
        fi
        test "$path_genre" && genre="$path_genre"
      fi
    fi
    test "$date" -a "$genre" && break
    let ++i
  done </tmp/ova.identify_file_list.$$
  echo done
}

identify_manual_adjustments()
{
  while true; do
    clear_screen
    echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
    echo "manual adjustments"
    echo
    echo -e "${CL1}1$RST: display the current info"
    echo -e "${CL1}2$RST: edit the info interactively"
    echo -e "${CL1}3$RST: edit the info in the editor"
    echo -e "${CL1}4$RST: swap trackartist/tracktitle"
    echo -e "${CL1}5$RST: perform character set conversion"
    echo -e "${CL1}c$RST: confirm the current info as final"
    echo
    echo -e "${CL1}s$RST: skip this directory"
    echo -e "${CL1}q$RST: quit to the main menu"
    echo
    ask "action" identify_choice "$default_manual_adjustments_choice"

    if test "$identify_choice" = q; then
      should_abort=yes
      last_outcome="aborted by user"
      return 1
    elif test "$identify_choice" = s; then
      continue 2
    elif test "$identify_choice" = c; then
      break
    fi
    if ! isint "$identify_choice" || test $identify_choice -lt 1 -o $identify_choice -gt 5; then
      echo
      echo "unrecognized command: $identify_choice"
      kbd_confirm
      continue
    fi
    let "identify_choice=10#$identify_choice"
    echo

    case $identify_choice in
      1)
        identify_display_info
        test "$really_use_pager" != yes && kbd_confirm
      ;;

      2)
        clear_screen
        echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
        echo -e "tracks: $CL1$track_count_padded$RST\n"
        echo -e "${CL1}NB: artist should be left blank for 'various artists' albums$RST\n"
        echo -e "artist: $CL1${artist:-''}$RST"
        echo -e "album:  $CL1${album:-''}$RST"
        echo -e "date:   $CL1${date:-''}$RST"
        echo -e "genre:  $CL1${genre:-''}$RST\033[4A"
        echo -ne "artist:\033[K\r"
        artist=$(readdef "artist: " "$artist")
        stripspaces artist
        echo -e "\033[1Aartist: $CL1${artist:-''}$RST\033[K"
        echo -ne "album:\033[K\r"
        album=$(readdef "album:  " "$album")
        stripspaces album
        echo -e "\033[1Aalbum:  $CL1${album:-''}$RST\033[K"
        echo -ne "date:\033[K\r"
        date=$(readdef "date:   " "$date")
        stripspaces date
        echo -e "\033[1Adate:   $CL1${date:-''}$RST\033[K"
        echo -ne "genre:\033[K\r"
        genre=$(readdef "genre:  " "$genre")
        stripspaces genre
        echo -e "\033[1Agenre:  $CL1${genre:-''}$RST\033[K"
        echo
        for ((i=1; i<=track_count; ++i)); do
          echo -e "($CL2$(zeropad $i 2)$RST/$CL2$track_count_padded$RST)" \
            "$CL2$(basename "${track_fname[$i]}")$RST"
          echo -e "  track number: $CL1${track_number[$i]}$RST"
          if test -z "$artist"; then
            echo -e "  track artist: $CL1${track_artist[$i]:-''}$RST"
          fi
          echo -e "  track title:  $CL1${track_title[$i]:-''}$RST"
          test -z "$artist" && echo -ne "\033[3A" || echo -ne "\033[2A"
          track_number[$i]=$(readdef "  track number: " "${track_number[$i]}")
          stripspaces track_number[$i]
          echo -e "\033[1A  track number: $CL1${track_number[$i]}$RST\033[K"
          if test -z "$artist"; then
            echo -ne "  track artist:\033[K\r"
            track_artist[$i]=$(readdef "  track artist: " "${track_artist[$i]}")
            stripspaces track_artist[$i]
            echo -e "\033[1A  track artist: $CL1${track_artist[$i]:-''}$RST\033[K"
          else
            track_artist[$i]="$artist"
          fi
          echo -ne "  track title:\033[K\r"
          track_title[$i]=$(readdef "  track title:  " "${track_title[$i]}")
          stripspaces track_title[$i]
          echo -e "\033[1A  track title:  $CL1${track_title[$i]:-''}$RST\033[K"
        done
      ;;

      3)
        if test "$EDITOR"; then
          {
            echo -e "# -*- sh -*-\n#"
            echo -e "# identify: $dir\n#"
            echo -e "# This file must be a valid shell script.\n#"
            echo "# NB: artist should be left blank for 'various artists' albums."
            echo "artist='$(echo "$artist" | sed "s/'/'\\\\''/g")'"
            echo "album='$(echo "$album" | sed "s/'/'\\\\''/g")'"
            echo "date='$(echo "$date" | sed "s/'/'\\\\''/g")'"
            echo "genre='$(echo "$genre" | sed "s/'/'\\\\''/g")'"
            for ((i=1; i<=track_count; ++i)); do
              echo
              echo "# ($(zeropad $i 2)/$track_count_padded) $(basename "${track_fname[$i]}")"
              echo "track_number[$i]='$(echo "${track_number[$i]}" | sed "s/'/'\\\\''/g")'"
              if test -z "$artist"; then
                echo "track_artist[$i]='$(echo "${track_artist[$i]}" | sed "s/'/'\\\\''/g")'"
              else
                echo "# track_artist[$i]='$(echo "${track_artist[$i]}" | sed "s/'/'\\\\''/g")'"
              fi
              echo "track_title[$i]='$(echo "${track_title[$i]}" | sed "s/'/'\\\\''/g")'"
            done
          } >/tmp/ova.identify_edit_info.$$
          if "$EDITOR" /tmp/ova.identify_edit_info.$$ <&3; then
            . /tmp/ova.identify_edit_info.$$ 2>/tmp/ova.identify_edit_info_error.$$
            if test $(stat -c %s /tmp/ova.identify_edit_info_error.$$ 2>/dev/null) -ne 0; then
              echo "error interpreting edited info:"
              cat /tmp/ova.identify_edit_info_error.$$
              kbd_confirm
            fi
            if test "$artist"; then
              for ((i=1; i<=track_count; ++i)); do
                track_artist[$i]="$artist"
              done
            fi
          fi
        else
          echo "set the EDITOR environment variable to your editor of choice first"
          kbd_confirm
        fi
      ;;

      4)
        if test -z "$artist"; then
          echo -n "swapping trackartist/tracktitle for each track: "
          heartbeat_init
          for ((i=1; i<=track_count; ++i)); do
            heartbeat
            j="${track_artist[$i]}"
            track_artist[$i]="${track_title[$i]}"
            track_title[$i]="$j"
          done
          echo done
          kbd_confirm
        else
          echo "this feature is only available for 'various artists' albums"
          kbd_confirm
        fi
      ;;

      5)
        charset=$(readdef "source character set: " '')
        echo -ne '\nperforming character set conversion... '
        {
          echo "artist='$(echo "$artist" | sed "s/'/'\\\\''/g")'"
          echo "album='$(echo "$album" | sed "s/'/'\\\\''/g")'"
          echo "date='$(echo "$date" | sed "s/'/'\\\\''/g")'"
          echo "genre='$(echo "$genre" | sed "s/'/'\\\\''/g")'"
          for ((i=1; i<=track_count; ++i)); do
            echo "track_number[$i]='$(echo "${track_number[$i]}" | sed "s/'/'\\\\''/g")'"
            test -z "$artist" &&
              echo "track_artist[$i]='$(echo "${track_artist[$i]}" | sed "s/'/'\\\\''/g")'"
            echo "track_title[$i]='$(echo "${track_title[$i]}" | sed "s/'/'\\\\''/g")'"
          done
        } >/tmp/ova.identify_charset_in.$$
        while true; do
          iconv -f $charset /tmp/ova.identify_charset_in.$$ >/tmp/ova.identify_charset_out.$$
          if test $? -eq 0; then
            . /tmp/ova.identify_charset_out.$$
            echo done
          else
            echo failed
          fi
          break
        done
        kbd_confirm
      ;;
    esac
  done
  if test "$misc" = no; then
    cd_number=$(echo "$album" | sed -e 'y/ /_/' \
      -e 's/\(^\|.*[[(_,:/-]\)\(cd\|disc\|disk\)_*\([0-9]\{1,\}\)\($\|[])_,:/-].*\)/\3/')
    if test "$cd_number" != "$album" && isint "$cd_number"; then
      cd_number="cd $cd_number"
      album=$(echo "$album" | sed -e 'y/ /_/' \
        -e 's/[[(_,:-]*\(cd\|disc\|disk\)_*[0-9]\{1,\}[])_,:-]*//' \
        -e 's/\/\{2,\}/\//g' -e 's/^\///' -e 's/\/$//' -e 'y/_/ /')
    else
      cd_number=
    fi
    while true; do
      clear_screen
      echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
      echo -e "album: $CL1${album:-''}$RST"
      echo -e "disc#: $CL1${cd_number:-''}$RST"
      echo
      while true; do
        ask "accept this info [ynq]" identify_choice "$cdnumber_satisfied"
        test "${identify_choice:0:1}" = y && break 2
        test "${identify_choice:0:1}" = n && break
        if test "${identify_choice:0:1}" = q; then
          should_abort=yes
          last_outcome="aborted by user"
          return 1
        fi
        echo -ne "\033[1A\r\033[K"
      done
      echo -ne "\033[4A\r"
      echo -ne "album:\033[K\r"
      album=$(readdef "album: " "$album")
      stripspaces album
      echo -e "\033[1Aalbum: $CL1${album:-''}$RST\033[K"
      echo -ne "disc#:\033[K\r"
      cd_number=$(readdef "disc#: " "$cd_number")
      stripspaces cd_number
    done
  fi
}

identify()
{
  declare dir cddb_match_count line i j artist album date genre \
    identify_choice left right right_lcase count_dash count_slash cddb_ok \
    track_count real_track_count track_count_padded real_track_count_padded \
    discid_file cddb_entry cddb_category tag_file cddb_discid misc \
    tagfilenum cddb_track_count cddb_match_exact potential_tags \
    pattern_num pattern_selected path_name path_genre path_date \
    path_failed path_i path_j mpat_artist mpat_album extd cddb_revision \
    various mpat_title mpat_tracknumber mpat_artist_pos mpat_album_pos \
    mpat_title_pos mpat_tracknumber_pos pattern_previous charset \
    tag_artist tag_album tag_genre tag_date tag_title tag_tracknumber test_dir
  declare -a cddb_match track_title track_artist track_number

  while read dir; do
    test_dir=$(stripprefix "$dir" "$selected_directory")
    if echo "$test_dir" | grep '^\(misc\|[^/]*/misc\)$' &>/dev/null; then
      misc=yes
    else
      misc=no
    fi
    clear_screen
    echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
    echo -n "listing files... "
    find "$dir" -maxdepth 1 -type f -name "*.ogg" 2>/dev/null |
      sort >/tmp/ova.identify_file_list.$$
    track_count=$(wc -l /tmp/ova.identify_file_list.$$ | sed 's/^ *\([0-9]*\).*/\1/')
    if test $track_count -eq 0; then
      find "$dir" -maxdepth 1 -type f -name "*.mp3" 2>/dev/null |
        sort >/tmp/ova.identify_file_list.$$
      track_count=$(wc -l /tmp/ova.identify_file_list.$$ | sed 's/^ *\([0-9]*\).*/\1/')
      if test $track_count -eq 0; then
        find "$dir" -maxdepth 1 -type f -name "*.wav" 2>/dev/null |
          sort >/tmp/ova.identify_file_list.$$
        track_count=$(wc -l /tmp/ova.identify_file_list.$$ | sed 's/^ *\([0-9]*\).*/\1/')
      fi
    fi
    tagfilenum=$(find "$dir" -maxdepth 1 -type f -name "*.tag" 2>/dev/null |
      wc -l | sed 's/^ *\([0-9]*\).*/\1/')
    if test -f "$dir/discid"; then
      discid_file="$dir/discid"
    elif test -f "$dir/discid~"; then
      discid_file="$dir/discid~"
    else
      discid_file=
    fi
    echo -e "done\n"

    unset track_fname
    declare -a track_fname
    potential_tags=
    real_track_count=0
    if test $track_count -eq 0; then
      test "$discid_file" || continue
      test "$misc" = yes && continue
      track_count=$(cat "$discid_file" | cut -d' ' -f2)
      for ((i=1; i<=track_count; ++i)); do
        track_fname[$i]="$dir/track$(zeropad $i 2).cdda.ogg"
      done
    else
      i=1
      if test "$misc" = no; then
        j=
        while read line; do
          j=$(echo "$line" | sed 's/.*track0\?\([0-9]\?[0-9]\)\.cdda\....\|.*$/\1/')
          test -z "$j" && j=$(echo "$line" | sed 's/.*\/[[(]*\([0-9]\{1,\}\)[])]*[._-][^/]*\|.*/\1/')
          test "$j" && isint "$j" && let "j=10#$j"
          if test "$j" && isint "$j" && test $j -gt 0 -a -z "${track_fname[$j]}"; then
            track_fname[$j]="$line"
            test $i -le $j && let i=j+1
          else
            track_fname[$i]="$line"
            let ++i
          fi
          test -z "$potential_tags" -a "$(echo "$line" |
            sed 's/.*track[0-9][0-9]\.cdda\....$//')" && potential_tags=yes
          let ++real_track_count
        done </tmp/ova.identify_file_list.$$
        test "$j" && isint "$j" && track_count=$j
      else
        while read line; do
          track_fname[$i]="$line"
          let ++i
        done </tmp/ova.identify_file_list.$$
        real_track_count=$((i-1))
        potential_tags=yes
      fi
    fi
    test $tagfilenum -ge $real_track_count && continue
    track_count_padded=$(zeropad $track_count 2)
    real_track_count_padded=$(zeropad $real_track_count 2)
    identify_info_reset

    if test "$misc" = no; then
      identify_cddb_query || return 0
      identify_cddb_choose || return 0
    fi
    if test "$potential_tags" = yes -a $real_track_count -ne 0; then
      if test -z "$album"; then
        identify_tags_pathnames || return 0
      elif test -z "$date" -o -z "$genre"; then
        identify_date_genre || return 0
      fi
    else
      if test -z "$album"; then
        clear_screen
        identify_info_format
      fi
    fi

    identify_manual_adjustments || return 0
    clear_screen
    identify_info_format
    if test "$cddb_submit_url" -a "$discid_file" = "$dir/discid" -a "$misc" = no; then
      echo
      test "${cddb_ok:0:1}" = y &&
        cddb_category=$(echo "${cddb_match[$identify_choice]}" | cut -d' ' -f1) ||
        cddb_category=
      if test -z "$cddb_category"; then
        for i in blues classical country folk jazz reggae soundtrack; do
          if echo "$genre" | grep -i "$i" &>/dev/null; then
            cddb_category="$i"
            break
          fi
        done
        if test -z "$cddb_category"; then
          if echo "$genre" | grep -i 'rock\|metal' &>/dev/null; then
            cddb_category=rock
          elif echo "$genre" | grep -i 'new age' &>/dev/null; then
            cddb_category=newage
          else
            cddb_category=misc
          fi
        fi
      fi
      cddb_category=$(readdef "submit entry to CDDB category: " "$cddb_category" \
        blues classical country data folk jazz misc newage reggae rock soundtrack)
      if test "$cddb_category"; then
        mkdir -p "@datadir@/cddb_submit/$cddb_category" 2>/dev/null
        echo
        echo -n "writing CDDB entry for later submission... "
        cddb_discid=$(cat "$discid_file" | cut -d' ' -f1)
        cddb_revision=$("@bindir@/ova-cddb_read" --print-revision $cddb_category $cddb_discid 2>/dev/null) || cddb_revision=-1
        let ++cddb_revision
        {
          echo "# xmcd"
          echo "#"
          echo "# Track frame offsets:"
          i=$(cat "$discid_file" | cut -d' ' -f2)
          for j in $(cat "$discid_file" | cut -d' ' -f3-$((2+i))); do
            echo "#       $j"
          done
          echo "#"
          echo "# Disc length: $(cat "$discid_file" | cut -d' ' -f$((3+i))) seconds"
          echo "#"
          echo "# Revision: $cddb_revision"
          echo "# Submitted via: @project@ @version@"
          echo "#"
          echo "DISCID=$cddb_discid"
          test -z "$artist" &&
            identify_cddb_submit_write DTITLE "various / $album" ||
            identify_cddb_submit_write DTITLE "$artist / $album"
          identify_cddb_submit_write DYEAR "$date"
          identify_cddb_submit_write DGENRE "$genre"
          for ((i=1; i<=track_count; ++i)); do
            test -z "$artist" &&
              identify_cddb_submit_write TTITLE$((i-1)) "${track_artist[$i]} / ${track_title[$i]}" ||
              identify_cddb_submit_write TTITLE$((i-1)) "${track_title[$i]}"
          done
          echo "EXTD="
          for ((i=0; i<track_count; ++i)); do
            echo "EXTT$i="
          done
          echo "PLAYORDER="
        } >"@datadir@/cddb_submit/$cddb_category/$cddb_discid"
        echo done
      fi
    fi
    test -z "$artist" && various=yes || various=no
    echo
    heartbeat_init
    for ((i=1; i<=track_count; ++i)); do
      echo -ne "\rsaving tag file $CL1$(zeropad $i 2)$RST/$CL1$track_count_padded$RST: "
      heartbeat
      test -z "${track_fname[$i]}" && continue
      tag_file=$(echo "${track_fname[$i]}" | sed 's/\.[^.]*$/.tag/')
      rm -f "${tag_file}~" "$tag_file"
      artist="${track_artist[$i]}"
      title="${track_title[$i]}"
      tracknumber="${track_number[$i]}"
      isint "$tracknumber" && tracknumber=$(zeropad $tracknumber 2)
      outputvars "$tag_file" '' title artist album date genre tracknumber various cd_number
    done
    test "$discid_file" = "$dir/discid~" && rm -f "$dir/discid~"
    let stat_count+=real_track_count
    echo done
  done </tmp/ova.identify_dir_list.$$
}

# **********************************************************
# identify }                                               *
# **********************************************************

# **********************************************************
# tag_relocate {                                           *
# **********************************************************

tag_relocate()
{
  declare dir line i j title artist album date genre tracknumber \
    unknown_album track_count tagline tag_file various left right \
    dest_path dest_dir dest_dir2 dest_diff sel_dir dirmove misc \
    dirmove_stripped cd_number parent_dir parent_dest_dir discid test_dir

  sel_dir=$(echo "$selected_directory" | sed 's/\/$//')
  while read dir; do
    test_dir=$(stripprefix "$dir" "$selected_directory")
    if echo "$test_dir" | grep '^\(misc\|[^/]*/misc\)$' &>/dev/null; then
      misc=yes
    else
      misc=no
    fi
    dir=$(echo "$dir" | sed 's/\/$//')
    clear_screen
    echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
    echo -n "listing files... "
    find "$dir" -maxdepth 1 -type f -name "*.ogg" 2>/dev/null |
      sort >/tmp/ova.tag_relocate_file_list.$$
    echo -e "done\n"
    track_count=$(wc -l /tmp/ova.tag_relocate_file_list.$$ | sed 's/^ *\([0-9]*\).*/\1/')
    test $track_count -eq 0 && continue
    test $(find "$dir" -maxdepth 1 -type f -name "*.tag" |
      wc -l | sed 's/^ *\([0-9]*\).*/\1/') -eq 0 && continue
    track_count=$(zeropad $track_count 2)
    unknown_album=unknown_album_$(gettimeofday)

    i=1
    dest_dir=
    dest_dir2=
    dest_diff=no
    heartbeat_init
    while read line; do
      echo -ne "\rtagging and relocating file $CL1$(zeropad $i ${#track_count})$RST/$CL1$track_count$RST: "
      heartbeat
      tag_file=$(echo "$line" | sed 's/\.[^.]*$/.tag/')
      if test ! -f "$tag_file"; then
        let ++i
        continue
      fi
      title=
      artist=
      album=
      date=
      genre=
      tracknumber=
      various=
      cd_number=
      while read tagline; do
        heartbeat
        pos=$(strstr "$tagline" '=') || continue
        left="${tagline:0:$pos}"
        right="${tagline:$((pos+1))}"
        value_in_colonlist "$left" \
          "title:artist:album:date:genre:tracknumber:various:cd_number:REPLAYGAIN_TRACK_PEAK:REPLAYGAIN_TRACK_GAIN:REPLAYGAIN_ALBUM_PEAK:REPLAYGAIN_ALBUM_GAIN" || continue
        eval $left='$right'
      done <"$tag_file"
      rm -f /tmp/ova.tag_relocate.tag.$$
      echo "artist=$artist" >>/tmp/ova.tag_relocate.tag.$$
      test "$cd_number" &&
        echo "album=$album ($cd_number)" >>/tmp/ova.tag_relocate.tag.$$ ||
        echo "album=$album" >>/tmp/ova.tag_relocate.tag.$$
      for tagline in title date genre tracknumber; do
        echo "$tagline=${!tagline}" >>/tmp/ova.tag_relocate.tag.$$
      done
      if test "$REPLAYGAIN_TRACK_PEAK" -a "$REPLAYGAIN_TRACK_GAIN"; then
        echo "REPLAYGAIN_TRACK_PEAK=$REPLAYGAIN_TRACK_PEAK" >>/tmp/ova.tag_relocate.tag.$$
        echo "REPLAYGAIN_TRACK_GAIN=$REPLAYGAIN_TRACK_GAIN" >>/tmp/ova.tag_relocate.tag.$$
        if test "$REPLAYGAIN_ALBUM_PEAK" -a "$REPLAYGAIN_ALBUM_GAIN"; then
          echo "REPLAYGAIN_ALBUM_PEAK=$REPLAYGAIN_ALBUM_PEAK" >>/tmp/ova.tag_relocate.tag.$$
          echo "REPLAYGAIN_ALBUM_GAIN=$REPLAYGAIN_ALBUM_GAIN" >>/tmp/ova.tag_relocate.tag.$$
        fi
      fi
      heartbeat
      vorbiscomment -w -c /tmp/ova.tag_relocate.tag.$$ "$line"
      heartbeat

      test -z "$genre" && genre=unknown_genre
      test -z "$date" && date=unknown_date
      test -z "$artist" && artist=unknown_artist
      test -z "$title" && title=unknown
      test -z "$album" && album="$unknown_album"
      title=$(echo "$title" | sed 'y/\//_/')
      artist=$(echo "$artist" | sed 'y/\//_/')
      album=$(echo "$album" | sed 'y/\//_/')
      date=$(echo "$date" | sed 'y/\//_/')
      genre=$(echo "$genre" | sed 'y/\//_/')
      tracknumber=$(echo "$tracknumber" | sed 'y/\//_/')

      heartbeat
      dest_path=$(track_path_pattern | sed -e 'y/ /_/' -e 's/_\{2,\}/_/g' \
        -e 's/\(^\|_\)\([][/\<>!@#$%^&*()+={};:,.?~-]*\)\($\|_\)/\2/g' \
        -e 's/\/\./\/dot-/g')
      conv_2lcase dest_path
      dest_dir=$(echo "$dest_path" | sed 's/\/[^/]*$//')
      test -z "$dest_dir2" && dest_dir2="$dest_dir"
      test "$dest_dir" != "$dest_dir2" && dest_diff=yes
      test "$dest_dir" && mkdir -p "$dest_dir" 2>/dev/null
      heartbeat
      if test -f "$dest_path"; then
        error="refusing to overwrite '$CL2$dest_path$RST'"
        clear_screen
        return 1
      fi
      mv -f "$line" "$dest_path" 2>/dev/null
      echo "$line -> $dest_path" >>"@datadir@/log/ova.tag&relocate"

      let ++i
      let ++stat_count
    done </tmp/ova.tag_relocate_file_list.$$
    test -z "$dest_dir" && continue
    rm -f "$dir"/*.tag "$dir"/*.tag~
    echo -e "done\n"
    echo "$dest_dir" >>/tmp/ova.replaygain_dir_list.$$

    parent_dir=
    if test "$dest_diff" != yes -a "$misc" = no; then
      if test -f "$dir/discid"; then
        cat "@datadir@/discid_list" | sed 's/\\/\\\\/g' >/tmp/ova.tag_relocate_discid_pre.$$
        while read discid; do
          test "$discid" = "$dir/discid" || echo "$discid"
        done </tmp/ova.tag_relocate_discid_pre.$$ >/tmp/ova.tag_relocate_discid_list.$$
        echo "$dest_dir/discid" >>/tmp/ova.tag_relocate_discid_list.$$
        rm -f "@datadir@/discid_list"
      fi
      echo -n "moving secondary files... "
      find "$dir" -maxdepth 1 -type f -exec mv -f "{}" "$dest_dir" \; 2>/dev/null
      echo done
      test -f /tmp/ova.tag_relocate_discid_list.$$ && mv -f /tmp/ova.tag_relocate_discid_list.$$ "@datadir@/discid_list"
      echo -n "listing subdirectories... "
      find "$dir" -mindepth 1 -type d 2>/dev/null >/tmp/ova.tag_relocate_dir2move_list.$$
      echo done
      echo -n "moving subdirectories... "
      while read dirmove; do
        if test $(find "$dirmove" -type f -name "*.ogg" 2>/dev/null | wc -l | sed 's/^ *\([0-9]*\).*/\1/') -eq 0; then
          dirmove_stripped=$(stripprefix "$dirmove" "$dir")
          mkdir -p "$dest_dir/$dirmove_stripped" 2>/dev/null
          mv -f "$dirmove"/* "$dest_dir/$dirmove_stripped" 2>/dev/null
          rmdir "$dirmove" 2>/dev/null
        fi
      done </tmp/ova.tag_relocate_dir2move_list.$$
      echo done
      parent_dir=$(echo "$dir" | sed 's/\/[^/]*$//')
    fi
    line="$dir"
    echo -n "removing empty directories: "
    heartbeat_init
    while test "$dir" -a ${#dir} -gt ${#sel_dir}; do
      heartbeat
      rmdir "$dir" 2>/dev/null
      dir=$(echo "$dir" | sed 's/\/[^/]*$//')
    done
    echo done
    if test ${#parent_dir} -ge ${#sel_dir} -a "$misc" = no; then
      echo -n "searching parent directory... "
      if test $(find "$parent_dir" -type f -regex ".*\.\(ogg\|mp3\|wav\)" 2>/dev/null | wc -l | sed 's/^ *\([0-9]*\).*/\1/') -eq 0; then
        echo done
        parent_dest_dir=$(echo "$dest_dir" | sed 's/\/[^/]*$//')
        if test "$parent_dest_dir"; then
          echo -n "moving everything from parent directory... "
          mv -f "$parent_dir"/* "$parent_dest_dir" 2>/dev/null
        fi
      fi
      echo done
      dir="$line"
      echo -n "removing empty directories: "
      heartbeat_init
      while test "$dir" -a ${#dir} -gt ${#sel_dir}; do
        heartbeat
        rmdir "$dir" 2>/dev/null
        dir=$(echo "$dir" | sed 's/\/[^/]*$//')
      done
      echo done
    fi
  done </tmp/ova.tag_relocate_dir_list.$$
}

# **********************************************************
# tag_relocate }                                           *
# **********************************************************

# **********************************************************
# rip {                                                    *
# **********************************************************

# args: $1 - value to match; shift; $@ - values
rip_print_range()
{
  declare start= match="$1" pos=1 one=0
  shift
  while test $# -gt 0; do
    if test "$1" = "$match"; then
      test -z "$start" && start=$pos
    else
      if test "$start"; then
        test $start -eq $((pos-1)) &&
          echo -ne " $CL1$(zeropad $start 2)$RST" ||
          echo -ne " $CL1$(zeropad $start 2)$RST-$CL1$(zeropad $((pos-1)) 2)$RST"
        start=
        one=1
      fi
    fi
    let ++pos
    shift
  done
  if test "$start"; then
    test $start -eq $((pos-1)) &&
      echo -ne " $CL1$(zeropad $start 2)$RST" ||
      echo -ne " $CL1$(zeropad $start 2)$RST-$CL1$(zeropad $((pos-1)) 2)$RST"
    start=
    one=1
  fi
  test $one -eq 1 || echo -ne " ${CL1}none$RST"
  echo
}

rip_range_track_validate()
{
  declare rip_continue_level="$1"
  shift
  isint "$@" || continue $rip_continue_level
  while test $# -gt 0; do
    test $1 -lt 1 -o $1 -gt $cd_track_count && continue $((rip_continue_level+1))
    shift
  done
}

rip_range_add()
{
  if rip_pos=$(strstr "$1" '-'); then
    rip_track1="${1:0:$rip_pos}"
    rip_track2="${1:$((rip_pos+1))}"
    test -z "$rip_track1" && rip_track1=1
    test -z "$rip_track2" && rip_track2=$cd_track_count
    rip_range_track_validate $2 "$rip_track1" "$rip_track2"
    test $rip_track1 -gt $rip_track2 && continue $2
    let "rip_track1=10#$rip_track1-1"
    let "rip_track2=10#$rip_track2-1"
    for ((i=rip_track1; i<=rip_track2; ++i)); do
      cd_selected[$i]=1
    done
  else
    let "rip_track1=10#$1"
    rip_range_track_validate $2 "$rip_track1"
    cd_selected[$((rip_track1-1))]=1
  fi
}

rip()
{
  declare -a cd_ripped cd_selected cd_audio
  declare dir cd_found= cd_track_count track_number wav_realsize wav_hdrsize rip_speed \
    wav_info i j track_start_time track_time global_start_time global_time \
    rip_retry ripped_track_count line audio_track_count rip_range rip_pos rip_track \
    rip_track1 rip_track2 tracks_to_rip last_track_number

  while true; do
    clear_screen
    echo -e "$CL1$last_action$RST\n"
    echo -e "CD reader: $CL2$cd_device$RST\n"
    if test "$use_eject" = yes; then
      echo -n "closing tray... "
      eject -t "$cd_device" 2>/dev/null
      echo done
    fi
    echo -ne "reading the CD TOC... "
    if ! cdparanoia -d "$cd_device" -Q &>/tmp/ova.rip_cdparanoia_query.$$; then
      echo -e failed
      if test "$use_eject" = yes; then
        echo -n "opening tray... "
        eject "$cd_device" 2>/dev/null
        echo done
      fi
      echo -e "\nmake sure there is an audio CD in the drive."
      while true; do
        ask "try again [yn]" rip_retry "y"
        if test "${rip_retry:0:1}" = n; then
          if test "$use_eject" = yes; then
            echo -ne "\033[K\nclosing tray... "
            eject -t "$cd_device" 2>/dev/null
            echo done
          fi
          should_abort=yes
          last_outcome="aborted by user"
          return 0
        fi
        test "${rip_retry:0:1}" = y && break
        echo -ne "\033[1A\r\033[K"
      done
      continue
    fi
    break
  done

  if ! cd-discid "$cd_device" >/tmp/ova.rip_discid.$$ 2>/tmp/ova.rip_errorlog.$$; then
    rm -f /tmp/ova.rip_discid.$$
    error="failed to obtain CD discid"
    errorlog=/tmp/ova.rip_errorlog.$$
    clear_screen
    return 1
  fi
  echo done

  if test ! -f "@datadir@/discid_list"; then
    echo -n "listing ripped CDs... "
    if test "$(stripprefix "$music_incoming" "$music_root")" = "$music_incoming"; then
      find "$music_root" "$music_incoming" -type f -name discid 2>/dev/null |
        sort >"@datadir@/discid_list"
    else
      find "$music_root" -type f -name discid 2>/dev/null |
        sort >"@datadir@/discid_list"
    fi
    echo done
  fi
  echo -n "searching ripped CDs: "
  heartbeat_init
  while read dir; do
    heartbeat
    if cmp "$dir" /tmp/ova.rip_discid.$$ &>/dev/null; then
      cd_found=yes
      break
    fi
  done <"@datadir@/discid_list"
  if test "$cd_found" != yes; then
    echo -ne "not found\nchoosing new directory... "
    rmdir "${music_incoming}cdda/"* 2>/dev/null
    dir=0000
    while test -d "${music_incoming}cdda/${dir}"; do
      let "dir=1+10#$dir"
      dir=$(zeropad $dir 4)
    done
    dir="${music_incoming}cdda/$dir"
    mkdir -p "$dir" 2>/dev/null
    mv /tmp/ova.rip_discid.$$ "$dir/discid"
    echo "$dir/discid" >>"@datadir@/discid_list"
    echo done
  else
    echo "found"
    dir=$(dirname "$dir")
    rm -f /tmp/ova.rip_discid.$$
  fi

  clear_screen
  echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
  cd_track_count=$(cat "$dir/discid" | cut -d' ' -f2)
  audio_track_count=0
  for ((i=0; i<cd_track_count; ++i)); do
    cd_ripped[$i]=0
    cd_audio[$i]=0
  done
  grep '^[[:blank:]]*[0-9]*\.' /tmp/ova.rip_cdparanoia_query.$$ |
    sed 's/^[[:blank:]]*\([0-9]*\)\..*/\1/' >/tmp/ova.rip_cdparanoia_query_tracks.$$
  while read j; do
    if isint "$j" && test $j -gt 0; then
      cd_audio[$((j-1))]=1
      let ++audio_track_count
    fi
  done </tmp/ova.rip_cdparanoia_query_tracks.$$

  echo -n "checking for already ripped tracks: "
  heartbeat_init
  ripped_track_count=0
  for ((i=0; i<cd_track_count; ++i)); do
    heartbeat
    track_number=$(zeropad $((i+1)) 2)
    cd_ripped[$i]=0
    if test -f "$dir/track$track_number.cdda.ogg" -o -f "$dir/$track_number"*".ogg"; then
      cd_ripped[$i]=1
    elif test -f "$dir/track$track_number.cdda.wav"; then
      wav_realsize=$(stat -c %s "$dir/track$track_number.cdda.wav" 2>/dev/null)
      wav_info=$(sfinfo "$dir/track$track_number.cdda.wav" 2>/dev/null | grep "^Audio Data")
      test "$wav_info" &&
        wav_hdrsize=$(($(echo "$wav_info" | sed 's/^Audio Data[[:blank:]]*\([0-9]*\).*/\1/')+\
          $(echo "$wav_info" | sed 's/.*offset *\([0-9]*\).*/\1/')))
      if isint "$wav_realsize" "$wav_hdrsize" && test $((wav_hdrsize-wav_realsize)) -eq 0; then
        cd_ripped[$i]=1
      fi
    fi
    test ${cd_ripped[$i]} -eq 1 && let ++ripped_track_count
  done
  test $ripped_track_count -eq $audio_track_count && ripped_track_count="CD had already been ripped to '$CL1$(current_relative_dir)$RST'"
  echo done
  if isint "$ripped_track_count"; then
    echo
    echo -e "tracks on CD:  $CL1$(zeropad $cd_track_count 2)$RST"
    echo -n "audio tracks: "
    rip_print_range 1 ${cd_audio[*]}
    echo -n "tracks ripped:"
    rip_print_range 1 ${cd_ripped[*]}
    echo
    while true; do
      for ((i=0; i<cd_track_count; ++i)); do
        cd_selected[$i]=0
      done
      echo -ne "\033[1A\r\033[K"
      rip_range=$(readdef "tracks to rip: " "-")
      if test -z "$rip_range"; then
        should_abort=yes
        last_outcome="aborted by user"
        return 0
      fi
      while rip_pos=$(strstr "$rip_range" ' '); do
        rip_track="${rip_range:0:$rip_pos}"
        rip_range="${rip_range:$((rip_pos+1))}"
        rip_range_add "$rip_track" 2
      done
      rip_range_add "$rip_range" 1
      for ((i=0; i<cd_track_count; ++i)); do
        test ${cd_selected[$i]} -eq 1 -a ${cd_audio[$i]} -ne 1 && cd_selected[$i]=0
      done
      break
    done
    ripped_track_count=0
    tracks_to_rip=0
    for ((i=0; i<cd_track_count; ++i)); do
      if test ${cd_selected[$i]} -eq 1; then
        let ++tracks_to_rip
        if test ${cd_ripped[$i]} -eq 1; then
          let ++ripped_track_count
          cd_selected[$i]=0
        fi
      fi
    done
    test $ripped_track_count -eq $tracks_to_rip && ripped_track_count="CD track range had already been ripped to '$CL1$(current_relative_dir)$RST'"
  fi

  if isint "$ripped_track_count"; then
    track_time=
    global_start_time=$(gettimeofday -s)
    for ((i=0; i<cd_track_count; ++i)); do
      test ${cd_selected[$i]} -eq 1 || continue
      track_number=$(zeropad $((i+1)) 2)
      clear_screen
      echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
      global_time=$(($(gettimeofday -s)-global_start_time))
      echo -e "CD reader: $CL2$cd_device$RST\n"
      printf "elapsed time:  $CL1%.1d$RST:$CL1%.2d$RST\033[K\n\n" $((global_time/60)) $((global_time%60))
      echo -e "tracks on CD:  $CL1$(zeropad $cd_track_count 2)$RST"
      echo -n "audio tracks: "
      rip_print_range 1 ${cd_audio[*]}
      echo -n "tracks ripped:"
      rip_print_range 1 ${cd_ripped[*]}
      echo -n "tracks to rip:"
      rip_print_range 1 ${cd_selected[*]}
      echo
      if isint "$track_time"; then
        wav_hdrsize=$(echo "$wav_info" | sed 's/^Audio Data[[:blank:]]*\([0-9]*\).*/\1/')
        let "rip_speed=wav_hdrsize/(17640*track_time)"
        let wav_hdrsize=wav_hdrsize/176400
        printf "track $CL1$last_track_number$RST [$CL1%.1d$RST:$CL1%.2d$RST] has been ripped in $CL1%.1d$RST:$CL1%.2d$RST @ ~$CL1%.1d.%.1d${RST}x\n" \
          $((wav_hdrsize/60)) $((wav_hdrsize%60)) $((track_time/60)) $((track_time%60)) $((rip_speed/10)) $((rip_speed%10))
      else
        echo "no tracks have been ripped yet"
      fi
      echo
      echo -e "ripping track: $CL1$track_number$RST"
      echo
      track_start_time=$(gettimeofday -s)
      trap 'kill $(ps h -o pid --ppid $$ 2>/dev/null) &>/dev/null; should_abort=yes' int
      if ! (cd "$dir"; cdparanoia $cdparanoia_options -d "$cd_device" -B $((i+1)) 2>&1); then
        trap '' int
        if test "$should_abort" = yes; then
          last_outcome="aborted by user"
          return 0
        fi
        echo
        error="cdparanoia has failed"
        return 1
      fi
      trap '' int
      track_time=$(($(gettimeofday -s)-track_start_time))
      wav_realsize=$(stat -c %s "$dir/track$track_number.cdda.wav" 2>/dev/null)
      wav_info=$(sfinfo "$dir/track$track_number.cdda.wav" 2>/dev/null | grep "^Audio Data")
      test "$wav_info" &&
        wav_hdrsize=$(($(echo "$wav_info" | sed 's/^Audio Data[[:blank:]]*\([0-9]*\).*/\1/')+\
          $(echo "$wav_info" | sed 's/.*offset *\([0-9]*\).*/\1/')))
      if ! isint "$wav_realsize" "$wav_hdrsize" || test $((wav_hdrsize-wav_realsize)) -ne 0; then
        error="ripped file '$CL2$dir/track$track_number.cdda.wav$RST' has wrong size for it's header"
        clear_screen
        return 1
      fi
      let ++stat_count
      cd_ripped[$i]=1
      cd_selected[$i]=0
      last_track_number=$track_number
    done
  else
    should_abort=yes
    last_outcome="$ripped_track_count"
  fi

  if test "$use_eject" = yes; then
    clear_screen
    echo -e "$CL1$last_action$RST: $CL1$(current_relative_dir)$RST\n"
    test "$should_abort" = yes &&
      echo -e "$last_outcome" ||
      echo -e "$CL1$stat_count$RST $(noun_form track $stat_count) $(verb_have_form $stat_count) been ripped"
    echo -ne "\nopening tray... "
    eject "$cd_device" 2>/dev/null
    echo done
  fi
}

# **********************************************************
# rip }                                                    *
# **********************************************************

# **********************************************************
# cleanup_stale_files {                                    *
# **********************************************************

cleanup_stale_files()
{
  declare status file
  echo -n "listing media files... "
  if test "$selected_recursive" = yes; then
    find "$selected_directory" -depth -type f -regex ".*\.\(mp3\|wav\)" >/tmp/ova.cleanup_list.$$
  else
    find "$selected_directory" -depth -maxdepth 1 -type f -regex ".*\.\(mp3\|wav\)" >/tmp/ova.cleanup_list.$$
  fi
  echo done
  echo -n "removing stale files: "
  heartbeat_init
  while read line; do
    heartbeat
    file=$(echo "$line" | sed 's/\.[^.]*$//')
    if test -f "$file.mp3"; then
      rm -f "$file.wav" "$file.ogg"
    elif test -f "$file.wav"; then
      rm -f "$file.ogg"
    fi
  done </tmp/ova.cleanup_list.$$
  echo done
}

# **********************************************************
# cleanup_stale_files }                                    *
# **********************************************************

# **********************************************************
# cddb_submit {                                            *
# **********************************************************

cddb_submit()
{
  declare i line entry_count site path name
  clear_screen
  echo -e "${CL1}CDDB submit$RST\n"
  echo -n "listing files... "
  find "@datadir@/cddb_submit" -mindepth 2 -type f >/tmp/ova.cddb_submit.$$
  entry_count=$(wc -l /tmp/ova.cddb_submit.$$ | sed 's/^ *\([0-9]*\).*/\1/')
  echo done
  echo
  i=1
  trap 'kill $(ps h -o pid --ppid $$ 2>/dev/null) &>/dev/null; should_abort=yes' int
  while read line; do
    clear_screen
    echo -e "${CL1}CDDB submit$RST\n"
    echo -e "submitting entry: $CL1$(zeropad $i ${#entry_count})$RST/$CL1$entry_count$RST\n"
    name="$(stripprefix "$line" "@datadir@/cddb_submit")"
    test "$should_abort" = yes && break
    wget -O /tmp/ova.cddb_submit.result.$$ 2>&1 \
      --header="Category: $(echo "$name" | sed 's/\/.*//')" \
      --header="Discid: $(echo "$name" | sed 's/.*\///')" \
      --header="User-Email: $cddb_submit_user_email" \
      --header="Submit-Mode: submit" \
      --header="Charset: UTF-8" \
      --header="X-Cddbd-Note: Submitted via @project@ @version@" \
      --post-file="$line" "$cddb_submit_url"
    test "$should_abort" = yes && break
    status="$(head -n 1 /tmp/ova.cddb_submit.result.$$)"
    if test "${status:0:3}" != 200; then
      trap '' int
      echo
      error="CDDB submit has failed"
      return 1
    fi
    rm -f "$line"
    rmdir "$(dirname "$line")" 2>/dev/null
    let ++i
    let ++stat_count
  done </tmp/ova.cddb_submit.$$
  trap '' int
  if test "$should_abort" = yes; then
    last_outcome="aborted by user"
    return 0
  fi
  echo done
}

# **********************************************************
# cddb_submit }                                            *
# **********************************************************

# **********************************************************
# update_hardlinks {                                       *
# **********************************************************

update_hardlinks()
{
  declare ui_starttime_s elapsed ui_starttime_us time_s time_us lnk_progress lnk_len \
    time_start= total_len est lnk_pid list_is_done=no

  clear_screen
  echo -e "$CL1$last_action$RST\n"
  "@bindir@/ova-hardlink" -a &>/dev/null &
  lnk_pid=$!
  move_cursor 1 3
  echo -ne "listing dirs and existing hard links... "
  time_start=$(gettimeofday -s)
  trap 'should_abort=yes' int
  while ps -p $lnk_pid &>/dev/null; do
    if test "$should_abort" = yes; then
      trap '' int
      kill $(ps h -o pid --ppid $lnk_pid 2>/dev/null) &>/dev/null
      kill $lnk_pid &>/dev/null
      rm -f /tmp/ova-hardlink.*.$lnk_pid
      last_outcome="aborted by user"
      return 0
    fi
    ui_starttime_s=$(gettimeofday -s)
    ui_starttime_us=$(gettimeofday -u)
    if test -f /tmp/ova-hardlink.flag_list_all.$lnk_pid; then
      move_cursor 1 3
      if test "$list_is_done" = no; then
        echo -ne '\033[J'
        time_start=$(gettimeofday -s)
        list_is_done=yes
      fi
      let elapsed=$(gettimeofday -s)-time_start
      if test -f /tmp/ova-hardlink.list_all.$lnk_pid -a -f /tmp/ova-hardlink.list_done.$lnk_pid; then
        lnk_len=$(wc -l /tmp/ova-hardlink.list_done.$lnk_pid | cut -d' ' -f1)
        total_len=$(wc -l /tmp/ova-hardlink.list_all.$lnk_pid | cut -d' ' -f1)
        let lnk_progress=lnk_len*1000/total_len
      else
        lnk_progress=0
      fi
      printf "progress: $CL1%3.1d.%.1d$RST%% done"  $((lnk_progress/10)) $((lnk_progress%10))
      if test $lnk_progress -eq 0; then
        est=
      else
        test $lnk_progress -ne 1000 && est=$(estimated_total $((lnk_progress*1000)) $elapsed) || est=$elapsed
      fi
      printf ", elapsed/eta/total: $CL1%2.1d$RST:$CL1%.2d$RST / " $((elapsed/60)) $((elapsed%60))
      if test "$est"; then
        test $est -lt $elapsed && est=$elapsed
        printf "$CL1%2.1d$RST:$CL1%.2d$RST / $CL1%2.1d$RST:$CL1%.2d$RST\033[K" $(((est-elapsed)/60)) $(((est-elapsed)%60)) $((est/60)) $((est%60))
      else
        printf " ${CL1}wait$RST /  ${CL1}wait$RST\033[K"
      fi
      echo
      if test -f /tmp/ova-hardlink.list_done.$lnk_pid && test $(wc -l /tmp/ova-hardlink.list_done.$lnk_pid | cut -d' ' -f1) -gt 0; then
        echo -e "\n\033[Jlast processed directories:$CL1"
        tail -n $hardlink_display_lines /tmp/ova-hardlink.list_done.$lnk_pid 2>/dev/null
        echo -ne "$RST"
      fi
    fi
    test -f /tmp/ova-hardlink.flag_work.$lnk_pid && break
    time_s=$(($(gettimeofday -s)-ui_starttime_s))
    time_us=$(($(gettimeofday -u)-ui_starttime_us))
    test $time_s -ge 1 && let time_us+=1000000
    let "time_us=ui_update_cycle-time_us*1000"
    test $time_us -gt 0 && nanosleep $((time_us/1000000000)) $((time_us%1000000000))
  done
  move_cursor 1 3
  echo -ne "\033[Jcleaning up stale files... "
  while ps -p $lnk_pid &>/dev/null; do
    if test "$should_abort" = yes; then
      trap '' int
      kill $(ps h -o pid --ppid $lnk_pid 2>/dev/null) &>/dev/null
      kill $lnk_pid &>/dev/null
      rm -f /tmp/ova-hardlink.*.$lnk_pid
      last_outcome="aborted by user"
      return 0
    fi
    ui_starttime_s=$(gettimeofday -s)
    ui_starttime_us=$(gettimeofday -u)
    if test -f /tmp/ova-hardlink.list_rm.$lnk_pid && test $(wc -l /tmp/ova-hardlink.list_rm.$lnk_pid | cut -d' ' -f1) -gt 0; then
      move_cursor 1 5
      echo -e "\033[Jlast removed files:$CL2"
      tail -n $hardlink_display_lines /tmp/ova-hardlink.list_rm.$lnk_pid 2>/dev/null
      echo -ne "$RST"
    fi
    test -f /tmp/ova-hardlink.flag_cleanup_files.$lnk_pid && break
    time_s=$(($(gettimeofday -s)-ui_starttime_s))
    time_us=$(($(gettimeofday -u)-ui_starttime_us))
    test $time_s -ge 1 && let time_us+=1000000
    let "time_us=ui_update_cycle-time_us*1000"
    test $time_us -gt 0 && nanosleep $((time_us/1000000000)) $((time_us%1000000000))
  done
  move_cursor 1 3
  echo -e "\033[Jcleaning up stale files... done"
  echo -ne "cleaning up stale dirs... "
  while ps -p $lnk_pid &>/dev/null; do
    if test "$should_abort" = yes; then
      trap '' int
      kill $(ps h -o pid --ppid $lnk_pid 2>/dev/null) &>/dev/null
      kill $lnk_pid &>/dev/null
      rm -f /tmp/ova-hardlink.*.$lnk_pid
      last_outcome="aborted by user"
      return 0
    fi
    ui_starttime_s=$(gettimeofday -s)
    ui_starttime_us=$(gettimeofday -u)
    if test -f /tmp/ova-hardlink.list_rmdir.$lnk_pid && test $(wc -l /tmp/ova-hardlink.list_rmdir.$lnk_pid | cut -d' ' -f1) -gt 0; then
      move_cursor 1 6
      echo -e "\033[Jlast removed directories:$CL1"
      tail -n $hardlink_display_lines /tmp/ova-hardlink.list_rmdir.$lnk_pid 2>/dev/null
      echo -ne "$RST"
    fi
    time_s=$(($(gettimeofday -s)-ui_starttime_s))
    time_us=$(($(gettimeofday -u)-ui_starttime_us))
    test $time_s -ge 1 && let time_us+=1000000
    let "time_us=ui_update_cycle-time_us*1000"
    test $time_us -gt 0 && nanosleep $((time_us/1000000000)) $((time_us%1000000000))
  done
  trap '' int
  if test -f "@datadir@/log/ova-hardlink.errors"; then
    error="list follows\nerror log: '$CL2@datadir@/log/ova-hardlink.errors$RST'"
    errorlog="@datadir@/log/ova-hardlink.errors"
    clear_screen
    return 1
  fi
}

# **********************************************************
# update_hardlinks }                                       *
# **********************************************************

# **********************************************************
# replaygain {                                             *
# **********************************************************

replaygain()
{
  declare dir vorbisgain_options old_IFS="$IFS" cwd="$(pwd)" test_dir
  IFS=$'\n'
  while read dir; do
    test_dir=$(stripprefix "$dir" "$music_root")
    if echo "$test_dir" | grep '^\(misc\|[^/]*/misc\)$' &>/dev/null; then
      vorbisgain_options=
    else
      vorbisgain_options='-a'
    fi
    dir=$(echo "$dir" | sed 's/\/$//')
    clear_screen
    echo -e "$CL1$last_action$RST: $CL1$dir$RST\n"
    echo -n "listing files... "
    cd "$dir" || continue
    find . -maxdepth 1 -type f -name "*.ogg" 2>/dev/null |
      sort >/tmp/ova.replaygain_file_list.$$
    echo -e "done\n"
    track_count=$(wc -l /tmp/ova.replaygain_file_list.$$ | sed 's/^ *\([0-9]*\).*/\1/')
    test $track_count -eq 0 && continue
    trap 'kill $(ps h -o pid --ppid $$ 2>/dev/null) &>/dev/null; should_abort=yes' int
    if ! vorbisgain $vorbisgain_options -f $(< /tmp/ova.replaygain_file_list.$$) 2>&1; then
      trap '' int
      IFS="$old_IFS"
      cd "$pwd"
      if test "$should_abort" = yes; then
        last_outcome="aborted by user"
        return 0
      fi
      echo
      error="vorbisgain has failed"
      return 1
    fi
    trap '' int
  done </tmp/ova.replaygain_dir_list.$$
  IFS="$old_IFS"
  cd "$pwd"
}

# **********************************************************
# replaygain }                                             *
# **********************************************************

call_ova_function_fill_last()
{
  test "$full_action" && last_action="$full_action+$CL1$last_action$RST" ||
    last_action="$CL1$last_action$RST"
  test "$full_outcome" && last_outcome="${full_outcome}\n         $last_outcome" ||
    last_outcome="$last_outcome"
  action_time=$(($(gettimeofday -s)-action_time))
  last_action_time=$(printf "$CL1%d$RST:$CL1%.2d$RST" $((action_time/60)) $((action_time%60)))
}

call_ova_function()
{
  should_abort=
  stat_count=0
  if ! "$@" || test "$error"; then
    last_outcome="${CL1}error$RST: $error"
    call_ova_function_fill_last
    echo -e "outcome: $last_outcome"
    if test "$errorlog"; then
      echo -e "\nerror log reads:"
      cat $errorlog
    fi
    kbd_confirm
    continue 2
  fi
  if test "$should_abort" = yes; then
    call_ova_function_fill_last
    continue 2
  fi
  clear_screen
}

ova_action()
{
  case "$1" in
    0)
      last_action="split tracks"
      last_outcome=
      clear_screen
      echo -e "$CL1$last_action$RST\n"
      echo -n "listing dirs... "
      if test "$selected_recursive" = yes; then
        find "$selected_directory" -depth -type d 2>/dev/null >/tmp/ova.split_tracks_dir_list.$$
      else
        echo "$selected_directory" >/tmp/ova.split_tracks_dir_list.$$
      fi
      echo done
      call_ova_function split_tracks
      last_outcome="$CL1$stat_count$RST $(noun_form track $stat_count) $(verb_have_form $stat_count) been splitted"
    ;;

    1)
      last_action="rip"
      last_outcome=
      call_ova_function rip
      last_outcome="$CL1$stat_count$RST $(noun_form track $stat_count) $(verb_have_form $stat_count) been ripped"
    ;;

    2)
      last_action="encode"
      last_outcome=
      clear_screen
      echo -e "$CL1$last_action$RST: $CL1$selected_directory$RST\n"
      cleanup_stale_files
      echo -n "listing media files... "
      if test "$selected_recursive" = yes; then
        find "$selected_directory" -type f -regex ".*\.\(mp3\|wav\)" | sort >/tmp/ova.encode_list.$$
      else
        find "$selected_directory" -maxdepth 1 -type f -regex ".*\.\(mp3\|wav\)" | sort >/tmp/ova.encode_list.$$
      fi
      echo done
      call_ova_function encode
      last_outcome="$CL1$stat_count$RST $(noun_form track $stat_count) $(verb_have_form $stat_count) been encoded"
    ;;

    3)
      last_action="identify"
      last_outcome=
      clear_screen
      echo -e "$CL1$last_action$RST\n"
      echo -n "listing dirs... "
      if test "$selected_recursive" = yes; then
        find "$selected_directory" -type d 2>/dev/null | sort >/tmp/ova.identify_dir_list.$$
      else
        echo "$selected_directory" >/tmp/ova.identify_dir_list.$$
      fi
      echo done
      call_ova_function identify
      last_outcome="$CL1$stat_count$RST $(noun_form track $stat_count) $(verb_have_form $stat_count) been identified"
    ;;

    4)
      last_action="tag&relocate"
      last_outcome=
      clear_screen
      echo -e "$CL1$last_action$RST\n"
      echo "listing dirs... "
      if test "$selected_recursive" = yes; then
        find "$selected_directory" -type d 2>/dev/null | sort -r >/tmp/ova.tag_relocate_dir_list.$$
      else
        echo "$selected_directory" >/tmp/ova.tag_relocate_dir_list.$$
      fi
      echo done
      call_ova_function tag_relocate
      last_outcome="$CL1$stat_count$RST $(noun_form track $stat_count) $(verb_have_form $stat_count) been tagged&relocated"
    ;;

    5)
      last_action="cleanup stale files"
      last_outcome=
      clear_screen
      echo -e "$CL1$last_action$RST\n"
      cleanup_stale_files
      echo
      echo -n "removing error log files... "
      find "@datadir@/log/error" -type f -not -name "ova.$$" -exec rm -f "{}" \; 2>/dev/null
      echo done
      last_outcome="success"
    ;;

    6)
      last_action="cleanup CDDB cache"
      last_outcome=
      clear_screen
      echo -e "$CL1$last_action$RST\n"
      echo -n "removing cached CDDB entries... "
      find "@datadir@/cddb_cache" -type f -exec rm -f "{}" \; 2>/dev/null
      find "@datadir@/cddb_cache" -depth -mindepth 1 -type d -exec rmdir "{}" \; 2>/dev/null
      echo done
      last_outcome="success"
    ;;

    7)
      last_action="cleanup discid list"
      last_outcome=
      clear_screen
      echo -e "$CL1$last_action$RST\n"
      echo -n "$removing discid list... "
      rm -f "@datadir@/discid_list"
      echo done
      last_outcome="success"
    ;;

    h)
      last_action="update hard links"
      last_outcome=
      clear_screen
      echo -e "$CL1$last_action$RST\n"
      call_ova_function update_hardlinks
      last_outcome="success"
    ;;

    v)
      last_action="calculate replay gain"
      last_outcome=
      if test ! -f /tmp/ova.replaygain_dir_list.$$; then
        clear_screen
        echo -e "$CL1$last_action$RST\n"
        echo -n "listing dirs... "
        find "$music_root" -type d 2>/dev/null | sort >/tmp/ova.tag_replaygain_dir_list.$$
        echo done
      fi
      call_ova_function replaygain
      last_outcome="success"
    ;;

    s)
      last_action="CDDB submit"
      last_outcome=
      call_ova_function cddb_submit
      last_outcome="$CL1$stat_count$RST $(noun_form entry $stat_count) $(verb_have_form $stat_count) been submitted"
    ;;

    i)
      clear_screen
      echo -e "${CL1}information$RST\n"
      echo -n "CDDB cache size: "
      cache_size=$(du -ks "@datadir@/cddb_cache" | sed 's/^\([0-9]\{1,\}\).*/\1/')
      printf "$CL1%d.%.1d$RST MiB\n" $((cache_size/1024)) $(((cache_size%1024)*10/1024))
      if test "$cddb_submit_url"; then
        echo -e "CDDB submission: $CL1$cddb_submit_count$RST $(noun_form entry $cddb_submit_count) pending"
      fi
      kbd_confirm
      continue 2
    ;;

    c)
      selected_directory=$(readdef "incoming directory: " "$selected_directory" "$music_incoming")
      while true; do
        ask "recursive search [yn]" sel_rec "$selected_recursive"
        if test "${sel_rec:0:1}" = y; then
          selected_recursive=yes
          break
        fi
        if test "${sel_rec:0:1}" = n; then
          selected_recursive=no
          break
        fi
        echo -ne "\033[1A\r\033[K"
      done
      continue 2
    ;;

    h)
      clear_screen
      echo -e "${CL1}help$RST\n"
      echo -e "${CL1}RTFM$RST: unpack the @project@ distribution and read README and doc/*"
      echo "honestly, docs are quite concise and to the point"
      echo
      echo -e "allowed compound actions: ${CL1}12 1234 1234v 234 234v 34 34v 4v$RST"
      kbd_confirm
      continue 2
    ;;

    q)
      quit=1
    ;;

    *)
      echo "unrecognized command: $sel_action"
      kbd_confirm
      continue 2
    ;;
  esac
}

trap '' int
trap 'clear_screen; show_cursor; rm -f /tmp/ova.*.$$; cleanup_errorlog; exit 1' hup quit term
trap 'clear_screen' cont

hide_cursor
quit=
last_action=none
last_outcome=none
last_action_time=none
action="$default_action"
while test -z "$quit"; do
  rm -f /tmp/ova.*.$$
  error=
  errorlog=
  clear_screen
  echo -ne "$RST"
  echo "@project@ @version@"
  echo
  echo -e "selected incoming directory: $CL1$selected_directory$RST"
  echo -e "recursive search: $CL1$selected_recursive$RST"
  echo
  echo -e "last action: $last_action"
  echo -e "outcome: $last_outcome"
  echo -e "elapsed: $last_action_time"
  echo
  echo "actions"
  echo
  echo -e "${CL1}0$RST: split single-file albums"
  echo
  echo -e "${CL1}1$RST: rip an audio compact disc"
  echo -e "${CL1}2$RST: re/encode tracks to ogg"
  echo -e "${CL1}3$RST: identify albums/tracks"
  echo -e "${CL1}4$RST: tag&relocate tracks"
  echo
  echo -e "${CL1}h$RST: update hard links"
  echo -e "${CL1}v$RST: calculate replay gain"
  echo
  echo -e "${CL1}c$RST: configure"
  echo -e "${CL1}i$RST: information"
  if test "$cddb_submit_url"; then
    cddb_submit_count=$(find "@datadir@/cddb_submit" -mindepth 2 -type f |
      wc -l | sed 's/^ *\([0-9]*\).*/\1/')
    echo -e "${CL1}s$RST: CDDB submit: $CL1$cddb_submit_count$RST"
  fi
  echo -e "${CL1}cs$RST: cleanup stale files"
  echo -e "${CL1}cc$RST: cleanup CDDB cache"
  echo -e "${CL1}cd$RST: cleanup discid list"
  echo
  echo -e "${CL1}h$RST: help"
  echo -e "${CL1}q$RST: quit"
  echo
  ask "action" sel_action "$action"
  bk_action="$sel_action"
  echo
  isint "$sel_action" && let "sel_action=10#$sel_action"
  if test -z "$cddb_submit_url" -a "$sel_action" = s || value_in_colonlist "$sel_action" "5:6:7"; then
    echo "unrecognized command: $sel_action"
    kbd_confirm
    continue
  fi
  case $sel_action in
    cs) sel_action=5 ;;
    cc) sel_action=6 ;;
    cd) sel_action=7 ;;
  esac
  if test ${#sel_action} -gt 1; then
    if ! value_in_colonlist "$sel_action" "12:1234:1234v:234:234v:34:34v:4v"; then
      echo "unrecognized compound command: $sel_action"
      kbd_confirm
      continue
    fi
  fi
  action_time=$(gettimeofday -s)
  full_action=
  full_outcome=
  while test ${#sel_action} -gt 0; do
    ova_action "${sel_action:0:1}"
    test "$full_action" && full_action="$full_action+$CL1$last_action$RST" ||
      full_action="$CL1$last_action$RST"
    test "$full_outcome" && full_outcome="${full_outcome}\n         $last_outcome" ||
      full_outcome="$last_outcome"
    sel_action="${sel_action:1}"
  done
  last_action="$full_action"
  last_outcome="$full_outcome"
  action_time=$(($(gettimeofday -s)-action_time))
  last_action_time=$(printf "$CL1%d$RST:$CL1%.2d$RST" $((action_time/60)) $((action_time%60)))
  test "$default_action" && action="$bk_action"
done

echo -ne "$SGR_RESET"
clear_screen
show_cursor
cleanup_errorlog
