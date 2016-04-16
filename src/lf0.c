/*
 * copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
 *
 * this is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * lf0: output the input, changing any LF characters to NUL characters.
 * Has low speed and low latency (it was done deliberately).
*/

#include <stdio.h>

int main(int argc, char **argv)
{
  char c;
  while (!feof(stdin)) {
    if ((c = getchar()) == 10)
      c = 0;
    putchar(c);
    if (!c)
      fflush(stdout);
  }
  return 0;
}
