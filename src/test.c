/*
 * copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
 *
 * this is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * readdef: read a line using the readline library, with a few extras over
 *   bash's 'read -e'.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <readline/readline.h>
#include <readline/history.h>

char *my_rl_default;

int set_rl_default(void) {
  rl_insert_text(my_rl_default);
  return 0;
}

int main(int argc, char **argv)
{
  int i;
  char *str;

  if (argc < 3) {
    fprintf(stderr, "Usage: %s prompt default [history]*\n", argv[0]);
    fprintf(stderr, "\nDisplays a PROMPT, allows to edit a variable with the initial value\n");
    fprintf(stderr, "DEFAULT, prints the result to stderr. Allows to define edit HISTORY.\n");
    exit(2);
  }

  /* klugey way to swap stdout and stderr places (to output all the
  ** interactive stuff to stderr) */
  FILE *temp = stdout;
  stdout = stderr;
  stderr = temp;

  rl_startup_hook = (Function*)set_rl_default;
  my_rl_default = argv[2];

  for (i = argc - 1; i >= 3; --i)
    if (strcmp(argv[2], argv[i]))
      add_history(argv[i]);

  if (str = readline(argv[1])) {
    fprintf(stderr, "%s\n", str);
    return 0;
  }
  else
    return 1;
}
