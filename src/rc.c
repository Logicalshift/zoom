/*
 *  A Z-Machine
 *  Copyright (C) 2000 Andrew Hunter
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/*
 * Deal with the .zoomrc file
 */

#include "../config.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "zmachine.h"
#include "rc.h"
#include "rcp.h"
#include "hash.h"

extern FILE* yyin;
extern int   rc_parse(void);
extern int   _rc_line;

hash rc_hash = NULL;
static rc_game* game = NULL;
static rc_game* defgame = NULL;

#ifdef DATADIR
# define ZOOMRC DATADIR "/zoomrc"
# define GAMEDIR DATADIR "/games"
#else
# define ZOOMRC "zoomrc"
# define GAMEDIR NULL
#endif

void rc_error(char* erm)
{
  zmachine_fatal("Error while parsing .zoomrc (line %i): %s",
		 _rc_line, erm);
}

void rc_load(void)
{
  char* home;
  char* filename;

  if (rc_hash == NULL)
    rc_hash = hash_create();

#if WINDOW_SYSTEM != 2
  home = getenv("HOME");
  if (home==NULL)
    {
      filename = "zoomrc";
    }
  else
    {
      filename = malloc(strlen(home)+9);
      strcpy(filename, home);
      strcat(filename, "/.zoomrc");
    }

  yyin = fopen(filename, "r");
  
  if (yyin==NULL)
    {
      yyin = fopen(ZOOMRC, "r");
      if (yyin == NULL)
	zmachine_fatal("Unable to open resource file '%s', or the systems default file at " ZOOMRC, filename);
    }
#else
  yyin = fopen("zoomrc", "r");
  if (yyin == NULL)
    zmachine_fatal("Unable to open resource file 'zoomrc'. Make sure that it is in the current directory");
#endif

  _rc_line = 1;
  rc_parse();
  fclose(yyin);
}

void rc_set_game(char* serial, int revision)
{
  char hash[20];

  sprintf(hash, "%i.%.6s", revision, serial);
  game = hash_get(rc_hash, hash, strlen(hash));
  if (game == NULL)
    game = hash_get(rc_hash, "default", 7);
  if (game == NULL)
    zmachine_fatal("No .zoomrc entry for your game, and no default entry either");
  defgame = hash_get(rc_hash, "default", 7);
  if (defgame == NULL)
    zmachine_fatal("No default entry in .zoomrc");
}

char* rc_get_game_name(char* serial, int revision)
{
  char hash[20];
  rc_game* game;

  sprintf(hash, "%i.%.6s", revision, serial);
  game = hash_get(rc_hash, hash, strlen(hash));
  if (game == NULL)
    return NULL;
  return game->name;
}

char* rc_get_name(void)
{
  if (game == NULL)
    zmachine_fatal("Programmer is a spoon");

  return game->name;
}

rc_font* rc_get_fonts(int* n_fonts)
{
  rc_font* deffonts;
  int x, y;
  
  if (game == NULL)
    zmachine_fatal("Programmer is a spoon");

  if (game->fonts == NULL)
    {
      *n_fonts = defgame->n_fonts;
      return defgame->fonts;
    }

  deffonts = defgame->fonts;
  for (x=0; x<defgame->n_fonts; x++)
    {
      int found = 0;

      for (y=0; y<game->n_fonts; y++)
	{
	  if (game->fonts[y].num == defgame->fonts[x].num)
	    found = 1;
	}

      if (!found)
	{
	  game->n_fonts++;
	  game->fonts = realloc(game->fonts,
				sizeof(rc_font)*game->n_fonts);
	  game->fonts[game->n_fonts-1] = defgame->fonts[x];
	}
    }
  
  *n_fonts = game->n_fonts;
  return game->fonts;
}

rc_colour* rc_get_colours(int* n_cols)
{
  if (game == NULL)
    zmachine_fatal("Programmer is a spoon");

  if (game->colours == NULL)
    {
      *n_cols = defgame->n_colours;
      return defgame->colours;
    }
  
  *n_cols = game->n_colours;
  return game->colours;  
}

int rc_get_interpreter(void)
{
  if (game->interpreter == -1)
    return defgame->interpreter;
  return game->interpreter;
}

int rc_get_revision(void)
{
  if (game->revision == -1)
    return defgame->revision;
  return game->revision;
}

char* rc_get_gamedir(void)
{
  if (game->gamedir == NULL)
    {
      if (defgame->gamedir == NULL)
	return GAMEDIR;
      return defgame->gamedir;
    }
  return game->gamedir;
}

char* rc_get_savedir(void)
{
  if (game->savedir == NULL)
    {
      if (defgame->gamedir == NULL)
	{
#if WINDOW_SYSTEM != 2
	  return "./";
#else
	  return NULL;
#endif
	}
      return defgame->savedir;
    }
  return game->savedir;
}

char* rc_get_graphics(void)
{
  if (game->graphics == NULL)
    return defgame->graphics;
  return game->graphics;
}

char* rc_get_sounds(void)
{
  if (game->sounds == NULL)
    return defgame->sounds;
  return game->sounds;
}

int rc_get_xsize(void)
{
  if (game->xsize == -1)
    {
      if (defgame->xsize == -1)
	return 80;
      return defgame->xsize;
    }
  return game->xsize;
}

int rc_get_ysize(void)
{
  if (game->ysize == -1)
    {
      if (defgame->ysize == -1)
	return 30;
      return defgame->ysize;
    }
  return game->ysize;
}
