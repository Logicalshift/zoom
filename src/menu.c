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
 * Some functions to do with menus
 */

#include "../config.h"

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <dirent.h>
#ifdef HAVE_UNISTD_H
# include <unistd.h>
#endif
#include <string.h>

#include "zmachine.h"
#include "menu.h"
#include "display.h"
#include "rc.h"
#include "file.h"

#if WINDOW_SYSTEM != 2

static void center(char* text, int columns)
{
  display_set_cursor((columns>>1)-(strlen(text)>>1), display_get_cur_y());
  display_prints_c(text);
}

struct game_struct {
  char* filename;
  char* storyname;
};

static int game_compare(void* a, void* b)
{
  struct game_struct *ga, *gb;

  ga = a; gb = b;

  return strcmp(ga->storyname, gb->storyname);
}

char* menu_get_story(void)
{
  char*     dirname;
  DIR*      gamedir;
  ZDisplay* di;
  int       n_games = 0;
  int       x;
  struct game_struct* game = NULL;
  struct dirent* dent;
  int       selection, start, end, height;
  char      format[10];
  int       read;
  
  display_set_colour(7, 4);
  display_erase_window();

  rc_set_game("xxxxxx", 65535);

  dirname = rc_get_gamedir();
  gamedir = opendir(dirname);

  if (gamedir == NULL)
    zmachine_fatal("Unable to find game direction '%s'", dirname);

  chdir(dirname);
  
  /* Read the files in this directory, and work out their names */
  while ((dent=readdir(gamedir)))
    {
      int len;

      len = strlen(dent->d_name);
      
      if (len > 2)
	{
	  if (dent->d_name[len-2] == 'z' && dent->d_name[len-3]=='.')
	    {
	      ZFile* file;

	      file = open_file(dent->d_name);
	      
	      if (file)
		{
		  int x,len;
		  ZByte* header;

		  header = read_block(file, 0, 64);
		  
		  game =
		    realloc(game, sizeof(struct game_struct)*(n_games+1));
		  game[n_games].filename =
		    malloc(sizeof(char)*(strlen(dent->d_name)+1));
		  strcpy(game[n_games].filename, dent->d_name);
		  
		  game[n_games].storyname =
		    rc_get_game_name(header + ZH_serial,
				     GetWord(header, ZH_release));

		  if (game[n_games].storyname == NULL)
		    {
		      len = strlen(game[n_games].filename);
		      
		      game[n_games].storyname = malloc(len+1);
		      for (x=0; x<len-3; x++)
			{
			  game[n_games].storyname[x] =
			    game[n_games].filename[x];
			}
		      game[n_games].storyname[x] = 0;
		    }

		  free(header);
		  
		  n_games++;

		  close_file(file);
		}
	    }
	}
    }

  closedir(gamedir);

  qsort(game, n_games, sizeof(struct game_struct), game_compare);

  di = display_get_info();

  selection = 0;
  height = (di->lines-6)&~1;
  sprintf(format, " %%.%is ", di->columns-6);

  if (n_games < 1)
    zmachine_fatal("No game file available in %s", dirname);
  
  do
    {
      start = selection - (height>>1);
      end = selection + (height>>1);

      display_erase_window();
      display_set_cursor(0,1);
      display_set_font(3);
      center("Zoom " VERSION " Menu of games", di->columns);
      display_set_cursor(0,di->lines-2);
      center("Use the UP and DOWN arrow keys to select a game", di->columns);
      display_set_cursor(0,di->lines-1);
      center("Press RETURN to load the selected game", di->columns);
    
      if (start < 0)
	{
	  end -= start;
	  start = 0;
	}
      if (end > n_games)
	{
	  end = n_games;
	  start = end - height;
	  if (start < 0)
	    start = 0;
	}
      
      for (x=0; x<(end-start); x++)
	{
	  display_set_cursor(2, 3+x);
	  display_set_cursor(2, 3+x);
	  display_printf(format, game[x+start].storyname);
	}
      display_set_cursor(2, 3+(selection-start));
      display_set_colour(0, 3);
      display_printf(format, game[selection].storyname);
      display_set_colour(7, 4);
  
      read = display_readchar(0);

      switch (read)
	{
	case 'Q':
	case 'q':
	  display_exit(1);
	  
	case 129:
	  selection--;
	  if (selection<0)
	    selection = 0;
	  break;
	  
	case 130:
	  selection++;
	  if (selection>=n_games)
	    selection = n_games-1;
	  break;
	}
    }
  while (read != 13 && read != 10);
  
  return game[selection].filename;
}

#else

char* menu_get_story(void)
{
  return NULL;
}

#endif