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
 * Time to get this show on the road
 */

#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <unistd.h>

#include "zmachine.h"
#include "file.h"
#include "options.h"
#include "interp.h"
#include "rc.h"
#include "stream.h"
#include "menu.h"

#include "display.h"

ZMachine machine;
extern char save_fname[256];

int main(int argc, char** argv)
{
  arguments args;
  struct timeval tv;

  machine.display_active = 0;
  
  /* Seed RNG */
  gettimeofday(&tv, NULL);
  srand(tv.tv_sec|tv.tv_usec);

  get_options(argc, argv, &args);
  machine.warning_level = args.warning_level;

#ifdef TRACKING
  machine.track_objects = args.track_objs;
  machine.track_attributes = args.track_attr;
  machine.track_properties = args.track_props;
#endif

  rc_load();
  
  if (args.story_file == NULL)
    {
      rc_set_game("xxxxxx", 65535);
      display_initialise();
      args.story_file = menu_get_story();
      zmachine_load_story(args.story_file, &machine);
      rc_set_game(Address(ZH_serial), Word(ZH_release));
      display_reinitialise();
    }
  else
    {
      zmachine_load_story(args.story_file, &machine);
      rc_set_game(Address(ZH_serial), Word(ZH_release));
      display_initialise();
    }

  {
    char  title[256];
    char* name;
    int x, len, slashpos;

    len = strlen(args.story_file);

    slashpos = -1;
    name = malloc(len+1);
    for (x=0; x<len; x++)
      {
	if (args.story_file[x] == '/')
	  slashpos = x;
      }

    for (x=slashpos+1;
	 args.story_file[x] != 0 && args.story_file[x] != '.';
	 x++)
      {
	name[x-slashpos-1] = args.story_file[x];
      }
    name[x-slashpos-1] = 0;

    sprintf(title, rc_get_name(),
	    name,
	    Word(ZH_release),
	    Address(ZH_serial));
    display_set_title(title);

    sprintf(save_fname, "%s.qut", name);
  }
  
#ifdef DEBUG
  {
    int x;

    display_prints("\nFont 3: ");
    display_set_font(-1);
    for (x=32; x<128; x++)
      display_printf("%c", x);
    display_set_font(0);
  }
#endif
  
  display_set_font(1);
  display_prints("\n\nMaze\n");
  display_set_font(0);
  display_prints("You are in a maze of twisty little software licences, all different.\nA warranty lurks in a corner.\n\n> read warranty\n");
  display_prints("WELCOME, adventurer, to ");
  display_set_font(2);
  display_prints("Zoom " VERSION " Copyright (C) Andrew Hunter, 2000\n");
  display_set_font(0);
  
  display_prints("This program is free software; you can redistribute and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.\n\n");
  display_prints("This program is distributed in the hope that it will be useful, but ");
  display_set_font(1);
  display_prints("WITHOUT ANY WARRANTY");
  display_set_font(0);
  display_prints("; without even the implied warranty of ");
  display_set_font(1);
  display_prints("MERCHANTABILITY");
  display_set_font(0);
  display_prints(" or ");
  display_set_font(1);
  display_prints("FITNESS FOR A PARTICULAR PURPOSE");
  display_set_font(0);
  display_prints(". See the GNU General Public Licence for more details.\n\n");
  display_prints("You should have received a copy of the GNU General Public License along with this program. If not, write to the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.\n");
  display_prints("\nThe Zoom homepage can be located at ");
  display_set_font(2);
  display_prints("http://www.logicalshift.co.uk/unix/zoom/");
  display_set_font(0);
  display_prints(" - check this page for any updates\n\n\n");
  display_set_colour(0, 6);
  display_prints("[ Press any key to begin ]");
  display_set_colour(0, 7);
  display_readchar(0);
  display_clear();

  machine.display_active = 1;

  switch (machine.header[0])
    {
#ifdef SUPPORT_VERSION_3
    case 3:
      display_split(1, 1);
      display_set_more(1, 0);

      display_set_colour(0, 7); display_set_font(0);
      display_set_window(0);
      zmachine_run(3, args.save_file);
      break;
#endif
#ifdef SUPPORT_VERSION_4
    case 4:
      zmachine_run(4, args.save_file);
      break;
#endif
#ifdef SUPPORT_VERSION_5
    case 5:
      display_set_cursor(0,0);
      zmachine_run(5, args.save_file);
      break;
    case 7:
      display_set_cursor(0,0);
      zmachine_run(7, args.save_file);
      break;
    case 8:
      display_set_cursor(0,0);
      zmachine_run(8, args.save_file);
      break;
#endif
#ifdef SUPPORT_VERSION_6
    case 6:
      display_set_cursor(1,1);
      zmachine_run(6, args.save_file);
      break;
#endif

    default:
      zmachine_fatal("Unsupported ZMachine version %i", machine.header[0]);
      break;
    }

  stream_flush_buffer();
  display_prints("\n");
  display_set_colour(7, 1);
  display_prints("[ Press any key to exit ]");
  display_set_colour(7, 0);
  display_readchar(0);
  
  return 0;
}

