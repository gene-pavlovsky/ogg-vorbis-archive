/*
 * copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
 *
 * this is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * nanosleep: nanosleep(2) shell counterpart.
*/

#include <stdio.h>
#include <time.h>

int main(int argc, char **argv)
{
  struct timespec ts;
  if (argc <= 1) {
    fprintf(stderr, "Usage: %s sec [nsec=0]\n", argv[0]);
    fprintf(stderr, "\nSleeps for sec seconds and nsec nanoseconds.\n");
    return 2;
  }
  sscanf(argv[1], "%ld", &ts.tv_sec);
  if (argc == 2)
    ts.tv_nsec = 0;
  else
    sscanf(argv[2], "%ld", &ts.tv_nsec);
  nanosleep(&ts, 0);
  return 0;
}
