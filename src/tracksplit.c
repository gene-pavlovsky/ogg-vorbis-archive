/*
 * copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
 *
 * this is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * tracksplit: split a raw audio file to several wave audio files as
 *   specified by offsets in the offsets file.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <math.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

#define FRAME_SIZE 2352  /* 1 frame of 44100 Hz, 2 channel, 16 bit audio */
#define FRAMES_PER_SECOND 75

#define P_MEMCPY_BLOCKSIZE 1048576

#define CL1 "\033[37m"
#define RST "\033[0m"

void p_memcpy(void *dest, void *src, size_t bytes)
{
  int done = 0, chunk;
  double progress;
  while ((chunk = bytes - done) > 0) {
    if (chunk > P_MEMCPY_BLOCKSIZE)
      chunk = P_MEMCPY_BLOCKSIZE;
    memcpy((char *)dest + done, (char *)src + done, chunk);
    done += chunk;
    progress = (double)done * 100 / bytes;
    printf("\033[7D"CL1"%3d.%.1d"RST"%% ", (int)floor(progress),
      (int)floor((progress - floor(progress)) * 10));
    fflush(stdout);
  }
}

void usage(char * name)
{
  fprintf(stderr, "Usage: %s [--seek=FRAMES] audio_file.raw offset_file output_dir\n", name);
  fprintf(stderr, "\nSplits the audio file according to the track frame offsets file,\n");
  fprintf(stderr, "writing the output wave files to the selected directory.\n");
  fprintf(stderr, "Track frame offsets file consists of a sequence of track frame\n");
  fprintf(stderr, "offsets for each track, separated by any amount of whitespace.\n");
  fprintf(stderr, "If the --seek option is given, it's argument is used instead of the\n");
  fprintf(stderr, "first offset for seeking to the initial position in the input file.\n");
  exit(2);
}

int main(int argc, char ** argv)
{
  FILE * offset_file;
  char * offset_line, * outfile_name;
  int * offsets;
  int first_offset, seek_offset = -1;
  int offset_size, i, trackcount, str_size, audiofile_size, audio_pos, audio_size, flag;
  int audiofile, outfile;
  int argidx = 0;
  double playlen;
  void * in_map, * out_map;
  char * plural;
  char wave_header[45] = "\122\111\106\106\000\000\000\000\127\101\126\105\146"
    "\155\164\040\020\000\000\000\001\000\002\000\104\254\000\000\020\261\002"
    "\000\004\000\020\000\144\141\164\141\000\000\000\000";

  if (argc <= 3)
    usage(argv[0]);

  if (strstr(argv[1], "--seek=")) {
    ++argidx;
    sscanf(argv[1] + 7, "%ld", &seek_offset);
  }

  if (argc <= 3 + argidx)
    usage(argv[0]);

  if (!(offset_file = fopen(argv[2 + argidx], "r"))) {
    perror("Error opening offset file");
    exit(1);
  }

  fseek(offset_file, 0, SEEK_END);
  offset_size = ftell(offset_file);
  fseek(offset_file, 0, SEEK_SET);
  offset_line = (char *)malloc(offset_size + 1);

  if (!fread((void *)offset_line, offset_size, 1, offset_file)) {
    if (ferror(offset_file)) {
      perror("Error reading offset file");
      exit(1);
    } else {
      fprintf(stderr, "No track frame offsets in offset file\n");
      exit(1);
    }
  }
  trackcount = 0;
  i = 0;
  while ((i < offset_size) && (isspace(offset_line[i]) || (offset_line[i] == '\n')))
    ++i;
  for (; i < offset_size; ++i)
    if (isdigit(offset_line[i])) {
      ++trackcount;
      while ((i < offset_size) && (isdigit(offset_line[i])))
        ++i;
      while ((i < offset_size) && (isspace(offset_line[i]) || (offset_line[i] == '\n')))
        ++i;
    }
  free(offset_line);
  if (trackcount <= 0) {
    fprintf(stderr, "No track frame offsets in offset file\n");
    exit(1);
  }

  offsets = (int *)malloc(sizeof(int) * trackcount);
  fseek(offset_file, 0, SEEK_SET);
  for (i = 0; i < trackcount; ++i)
    flag = fscanf(offset_file, "%ld", offsets + i);
    if (!flag || (flag == EOF)) {
      fprintf(stderr, "Error parsing offset file\n");
      exit(1);
    }
  fclose(offset_file);
  if (seek_offset >= 0)
    first_offset = seek_offset;
  else
    first_offset = offsets[0];

  for (i = 0; i < trackcount - 1; ++i)
    offsets[i] = offsets[i + 1] - offsets[i];
  offsets[trackcount - 1] = 0;

  if ((audiofile = open(argv[1 + argidx], O_RDONLY)) == -1) {
    perror("Error opening raw file");
    exit(1);
  }
  audiofile_size = lseek(audiofile, 0, SEEK_END);
  lseek(audiofile, 0, SEEK_SET);
  if ((in_map = mmap(0, audiofile_size, PROT_READ, MAP_SHARED, audiofile, 0)) == MAP_FAILED) {
    perror("Error mmaping raw file");
    exit(1);
  }
  close(audiofile);

  plural = trackcount > 1 ? "tracks" : "track";
  playlen = (double)audiofile_size / (FRAME_SIZE * FRAMES_PER_SECOND);
  printf("raw file: "CL1"%2d"RST":"CL1"%02d"RST" in "CL1"%3d.%d"RST" MiB, contains "CL1"%d"RST" %s\n",
    (int)floor(playlen) / 60, (int)floor(playlen) % 60, audiofile_size / 1048576,
    (int)floor((double)(audiofile_size % 1048576)/104857.6), trackcount, plural);

  str_size = strlen(argv[3 + argidx]) + strlen("/track??.wav") + 1;
  outfile_name = (char *)malloc(str_size);
  audio_pos = FRAME_SIZE * first_offset;
  for (i = 0; i < trackcount; ++i) {
    audio_size = audiofile_size - audio_pos;
    if (((i < trackcount - 1) && (audio_size < FRAME_SIZE * offsets[i])) || (audio_size <= 0)) {
      fprintf(stderr, "Raw file ends prematurely\n");
      exit(1);
    }
    if ((i < trackcount - 1) && (FRAME_SIZE * offsets[i] < audio_size))
      audio_size = FRAME_SIZE * offsets[i];
    snprintf(outfile_name, str_size, "%s/track%02d.wav", argv[3 + argidx], i + 1);
    playlen = (double)audio_size / (FRAME_SIZE * FRAMES_PER_SECOND);
    printf("track "CL1"%02d"RST": "CL1"%2d"RST":"CL1"%02d"RST" in "CL1"%3d.%d"RST" MiB, writing: "CL1"  0.0%% "RST, i + 1,
      (int)floor(playlen) / 60, (int)floor(playlen) % 60, (audio_size + 44) / 1048576,
      (int)floor((double)((audio_size + 44) % 1048576)/104857.6));
    fflush(stdout);
    if ((outfile = open(outfile_name, O_RDWR | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)) == -1) {
      perror("Error opening output file");
      exit(1);
    }
    *((unsigned long *)(wave_header + 4)) = audio_size + 36; /* 44 - 8 */
    *((unsigned long *)(wave_header + 40)) = audio_size;
    write(outfile, wave_header, 44);
    lseek(outfile, audio_size + 43, SEEK_SET);
    write(outfile, "", 1);
    lseek(outfile, 0, SEEK_SET);
    if ((out_map = mmap(0, audio_size + 44, PROT_WRITE, MAP_SHARED, outfile, 0)) == MAP_FAILED) {
      perror("Error mmaping output file");
      exit(1);
    }
    close(outfile);
    p_memcpy((char *)out_map + 44, (char *)in_map + audio_pos, audio_size);
    munmap(out_map, audio_size + 44);
    audio_pos += audio_size;
    printf("\033[7D\033[K done\n");
  }

  munmap(in_map, audiofile_size);
  free(outfile_name);
  free(offsets);
}
