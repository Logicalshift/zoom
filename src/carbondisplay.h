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
 * Display for MacOS (Carbon)
 */

#ifndef __CARBONDISPLAY_H
#define __CARBONDISPLAY_H

#define SIGNATURE '????'

extern WindowRef zoomWindow;
extern RGBColor  maccolour[14];
extern int       window_available;
extern DialogRef fataldlog;
extern FSRef*    lastopenfs;
extern FSRef*    forceopenfs;
extern int       quitflag;
extern int       mac_openflag;

extern FSRef* carbon_get_zcode_file(void);

extern ZFile* open_file_fsref(FSRef* ref);
extern ZFile* open_file_write_fsref(FSRef* ref);
extern ZDWord get_file_size_fsref(FSRef* file);

extern Boolean display_force_input  (char* text);
extern void    display_force_restore(FSRef* ref);

extern OSErr ae_opendocs_handler(const AppleEvent* evt,
				 AppleEvent* reply,
				 SInt32      handlerRefIcon);
extern OSErr ae_open_handler    (const AppleEvent* evt,
				 AppleEvent* reply,
				 SInt32      handlerRefIcon);
extern OSErr ae_print_handler   (const AppleEvent* evt,
				 AppleEvent* reply,
				 SInt32      handlerRefIcon);
extern OSErr ae_quit_handler    (const AppleEvent* evt,
				 AppleEvent* reply,
				 SInt32      handlerRefIcon);
extern OSErr ae_reopen_handler  (const AppleEvent* evt,
				 AppleEvent* reply,
				 SInt32      handlerRefIcon);

extern void carbon_display_message(char* title, char* message);

#endif
