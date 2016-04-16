/*
 * copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
 *
 * this is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * gettimeofday: gettimeofday(2) shell counterpart.
*/

#include <stdio.h>
#include <string.h>
#include <sys/time.h>

int main(int argc, char **argv)
{
  struct timeval tv;
  gettimeofday(&tv, 0);
  if (argc == 2) {
    if (!strcmp(argv[1], "-s"))
      printf("%ld\n", tv.tv_sec);
    else if (!strcmp(argv[1], "-u"))
      printf("%ld\n", tv.tv_usec);
    else
      fprintf(stderr, "unrecognized option: %s\n", argv[1]);
  }
  else
    printf("%ld.%06d\n", tv.tv_sec, tv.tv_usec);
  return 0;
}
