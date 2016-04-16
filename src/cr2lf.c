/*
 * copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
 *
 * this is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * cr2lf: output the input, changing any CR characters to LF characters.
 * Has low speed and low latency (it was done deliberately).
*/

#include <stdio.h>

int main(int argc, char **argv)
{
  char c;
  while (!feof(stdin)) {
    if ((c = getchar()) == 13)
      c = 10;
    putchar(c);
    if (c == 10)
      fflush(stdout);
  }
  return 0;
}
