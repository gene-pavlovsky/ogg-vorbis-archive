/*
 * copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
 *
 * this is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * isatty: isatty(3) shell counterpart.
*/

#include <stdio.h>
#include <unistd.h>

int main(int argc, char **argv)
{
  int fd;
  if (argc <= 1) {
    fprintf(stderr, "Usage: %s fd\n", argv[0]);
    fprintf(stderr, "\nReturns 0 if fd is an open descriptor connected\n");
    fprintf(stderr, "to a terminal, and 1 if otherwise.\n");
    return 2;
  }
  sscanf(argv[1], "%d", &fd);
  return !isatty(fd);
}
