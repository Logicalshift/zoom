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
 * Operation functions
 */

#ifndef __OP_H
#define __OP_H

#include "ztypes.h"
#include "zmachine.h"

#ifdef INLINEOPS
#define _scope static
#else
#define _scope extern
#endif

/*
 * Yes, this file (and op.c) looks a bit weird. That's because
 * we want to inline them if possible
 */

/* 2OPs */
_scope void zcode_op_je        (ZDWord*, ZStack*, int, ZWord, ZWord, ZDWord);
_scope void zcode_op_jen       (ZDWord*, ZStack*, int, ZWord, ZWord, ZDWord);
_scope void zcode_op_jem       (ZDWord*, ZStack*, ZArgblock*, ZDWord);
_scope void zcode_op_jenm      (ZDWord*, ZStack*, ZArgblock*, ZDWord);
_scope void zcode_op_jl        (ZDWord*, ZStack*, int, ZWord, ZWord, ZDWord);
_scope void zcode_op_jln       (ZDWord*, ZStack*, int, ZWord, ZWord, ZDWord);
_scope void zcode_op_jg        (ZDWord*, ZStack*, int, ZWord, ZWord, ZDWord);
_scope void zcode_op_jgn       (ZDWord*, ZStack*, int, ZWord, ZWord, ZDWord);
_scope void zcode_op_dec_chk   (ZDWord*, ZStack*, int, ZWord, ZWord, ZDWord);
_scope void zcode_op_dec_chkn  (ZDWord*, ZStack*, int, ZWord, ZWord, ZDWord);
_scope void zcode_op_inc_chk   (ZDWord*, ZStack*, int, ZWord, ZWord, ZDWord);
_scope void zcode_op_inc_chkn  (ZDWord*, ZStack*, int, ZWord, ZWord, ZDWord);
_scope void zcode_op_jin_123   (ZDWord*, ZStack*, int, ZUWord, ZUWord, ZDWord);
_scope void zcode_op_jinn_123  (ZDWord*, ZStack*, int, ZUWord, ZUWord, ZDWord);
_scope void zcode_op_jin_45678 (ZDWord*, ZStack*, int, ZUWord, ZUWord, ZDWord);
_scope void zcode_op_jinn_45678(ZDWord*, ZStack*, int, ZUWord, ZUWord, ZDWord);
_scope void zcode_op_test      (ZDWord*, ZStack*, int, ZUWord, ZUWord, ZDWord);
_scope void zcode_op_testn     (ZDWord*, ZStack*, int, ZUWord, ZUWord, ZDWord);

_scope void zcode_op_test_attr_123(ZDWord*, ZStack*, int, ZUWord, ZUWord, ZDWord);
_scope void zcode_op_test_attrn_123(ZDWord*, ZStack*, int, ZUWord, ZUWord, ZDWord);
_scope void zcode_op_test_attr_45678(ZDWord*, ZStack*, int, ZUWord, ZUWord, ZDWord);
_scope void zcode_op_test_attrn_45678(ZDWord*, ZStack*, int, ZUWord, ZUWord, ZDWord);
_scope void zcode_op_set_attr_123  (ZStack*, int, ZUWord, ZUWord);
_scope void zcode_op_clear_attr_123(ZStack*, int, ZUWord, ZUWord);
_scope void zcode_op_set_attr_45678(ZStack*, int, ZUWord, ZUWord);
_scope void zcode_op_clear_attr_45678(ZStack*, int, ZUWord, ZUWord);
_scope void zcode_op_insert_obj_123(ZStack*, int, ZUWord, ZUWord);
_scope void zcode_op_insert_obj_45678(ZStack*, int, ZUWord, ZUWord);
_scope void zcode_op_get_prop_123 (ZStack*, int, ZUWord, ZUWord, int);
_scope void zcode_op_get_prop_45678(ZStack*, int, ZUWord, ZUWord, int);
_scope void zcode_op_get_prop_addr_123(ZStack*, int, ZUWord, ZUWord, int);
_scope void zcode_op_get_next_prop_123(ZStack*, int, ZUWord, ZUWord, int);
_scope void zcode_op_get_prop_addr_45678(ZStack*, int, ZUWord, ZUWord, int);
_scope void zcode_op_get_next_prop_45678(ZStack*, int, ZUWord, ZUWord, int);

_scope void zcode_op_store(ZStack*, int, ZWord, ZWord);
_scope void zcode_op_loadw(ZStack*, int, ZUWord, ZUWord, int);
_scope void zcode_op_loadb(ZStack*, int, ZUWord, ZUWord, int);

_scope void zcode_op_or (ZStack*, int, ZWord, ZWord, int);
_scope void zcode_op_and(ZStack*, int, ZWord, ZWord, int);
_scope void zcode_op_add(ZStack*, int, ZWord, ZWord, int);
_scope void zcode_op_sub(ZStack*, int, ZWord, ZWord, int);
_scope void zcode_op_mul(ZStack*, int, ZWord, ZWord, int);
_scope void zcode_op_div(ZStack*, int, ZWord, ZWord, int);
_scope void zcode_op_mod(ZStack*, int, ZWord, ZWord, int);

_scope void zcode_op_call_2s_45678 (ZDWord*, ZStack*, int, ZWord, ZWord, int);
_scope void zcode_op_call_2n_5678  (ZDWord*, ZStack*, int, ZWord, ZWord);
_scope void zcode_op_set_colour_578(ZStack*, int, ZWord, ZWord);
_scope void zcode_op_set_colour_6  (ZStack*, int, ZWord, ZWord);

_scope void zcode_op_throw_5678    (ZDWord*, ZStack*, int, ZUWord, ZUWord);

/* 1OPs */
_scope void zcode_op_jz           (ZDWord*, ZStack*, ZWord, ZDWord);
_scope void zcode_op_jzn          (ZDWord*, ZStack*, ZWord, ZDWord);
_scope void zcode_op_get_sibling_123(ZDWord*, ZStack*, ZUWord, int, ZDWord);
_scope void zcode_op_get_child_123(ZDWord*, ZStack*,  ZUWord, int, ZDWord);
_scope void zcode_op_get_siblingn_123(ZDWord*, ZStack*, ZUWord, int, ZDWord);
_scope void zcode_op_get_childn_123(ZDWord*, ZStack*,  ZUWord, int, ZDWord);
_scope void zcode_op_get_parent_123(ZStack*, ZUWord, int);
_scope void zcode_op_get_prop_len_123(ZStack*, ZUWord, int);
_scope void zcode_op_get_sibling_45678(ZDWord*, ZStack*, ZUWord, int, ZDWord);
_scope void zcode_op_get_siblingn_45678(ZDWord*, ZStack*, ZUWord, int, ZDWord);
_scope void zcode_op_get_child_45678(ZDWord*, ZStack*,  ZUWord, int, ZDWord);
_scope void zcode_op_get_childn_45678(ZDWord*, ZStack*,  ZUWord, int, ZDWord);
_scope void zcode_op_get_parent_45678(ZStack*, ZUWord, int);
_scope void zcode_op_get_prop_len_45678(ZStack*, ZUWord, int);
_scope void zcode_op_inc          (ZStack*, ZWord);
_scope void zcode_op_dec          (ZStack*, ZWord);
_scope void zcode_op_print_addr   (ZStack*, ZUWord);
_scope void zcode_op_call_1s_45678(ZDWord*, ZStack*, ZWord, int);
_scope void zcode_op_remove_obj_123(ZStack*, ZWord);
_scope void zcode_op_print_obj_123(ZStack*, ZWord);
_scope void zcode_op_remove_obj_45678(ZStack*, ZWord);
_scope void zcode_op_print_obj_45678(ZStack*, ZWord);
_scope void zcode_op_ret          (ZDWord*, ZStack*, ZWord);
_scope void zcode_op_jump         (ZDWord*, ZStack*, ZWord);
_scope void zcode_op_print_paddr_123(ZStack*, ZUWord);
_scope void zcode_op_print_paddr_45678(ZStack*, ZUWord);
_scope void zcode_op_load         (ZStack*, ZWord, int);
_scope void zcode_op_not_1234     (ZStack*, ZWord, int);
_scope void zcode_op_call_1n_5678 (ZDWord*, ZStack*, ZWord);

/* 0OPs */
_scope inline void zcode_op_rtrue           (ZDWord*, ZStack*);
_scope inline void zcode_op_rfalse          (ZDWord*, ZStack*);
_scope void zcode_op_print           (char*);
_scope void zcode_op_print_ret       (ZDWord*, ZStack*, char*);
_scope void zcode_op_nop             (ZStack*);
_scope void zcode_op_save_123        (ZDWord*, ZStack*, ZDWord);
_scope void zcode_op_saven_123       (ZDWord*, ZStack*, ZDWord);
_scope void zcode_op_save_4          (ZDWord*, ZStack*, int);
_scope void zcode_op_restore_123     (ZDWord*, ZStack*, ZDWord);
_scope void zcode_op_restoren_123    (ZDWord*, ZStack*, ZDWord);
_scope void zcode_op_restore_4       (ZDWord*, ZStack*, int);
_scope void zcode_op_restart         (ZDWord*, ZStack*);
_scope void zcode_op_ret_popped      (ZDWord*, ZStack*);
_scope void zcode_op_pop_1234        (ZStack*);
_scope void zcode_op_catch_5678      (ZStack*, int);
_scope void zcode_op_quit            (ZDWord*, ZStack*);
_scope void zcode_op_new_line        (ZStack*);
_scope void zcode_op_show_status_3   (ZStack*);
_scope void zcode_op_status_nop_45678(ZStack*);
_scope void zcode_op_verify_345678   (ZDWord*, ZStack*, ZDWord);
_scope void zcode_op_verifyn_345678  (ZDWord*, ZStack*, ZDWord);
_scope void zcode_op_piracy_5678     (ZDWord*, ZStack*, ZDWord);
_scope void zcode_op_piracyn_5678    (ZDWord*, ZStack*, ZDWord);

/* VAR ops */
_scope void zcode_op_call_123            (ZDWord*, ZStack*, ZArgblock*, int);
_scope void zcode_op_call_vs_45678       (ZDWord*, ZStack*, ZArgblock*, int);
_scope void zcode_op_storew              (ZStack*, ZArgblock*);
_scope void zcode_op_storeb              (ZStack*, ZArgblock*);
_scope void zcode_op_put_prop_123        (ZStack*, ZArgblock*);
_scope void zcode_op_put_prop_45678      (ZStack*, ZArgblock*);
_scope void zcode_op_sread_123           (ZStack*, ZArgblock*);
_scope void zcode_op_sread_4             (ZDWord*, ZStack*, ZArgblock*);
_scope void zcode_op_aread_5678          (ZDWord*, ZStack*, ZArgblock*, int);
_scope void zcode_op_print_char          (ZStack*, ZArgblock*);
_scope void zcode_op_print_num           (ZStack*, ZArgblock*);
_scope void zcode_op_random              (ZStack*, ZArgblock*, int);
_scope void zcode_op_push                (ZStack*, ZArgblock*);
_scope void zcode_op_pull_1234578        (ZStack*, ZArgblock*);
_scope void zcode_op_pull_6              (ZStack*, ZArgblock*, int);
_scope void zcode_op_split_window_345678 (ZStack*, ZArgblock*);
_scope void zcode_op_set_window_34578    (ZStack*, ZArgblock*);
_scope void zcode_op_set_window_6        (ZStack*, ZArgblock*);
_scope void zcode_op_call_vs2_45678      (ZDWord*, ZStack*, ZArgblock*, int);
_scope void zcode_op_erase_window_45678  (ZStack*, ZArgblock*);
_scope void zcode_op_erase_line_45678    (ZStack*, ZArgblock*);
_scope void zcode_op_erase_line_4578     (ZStack*, ZArgblock*);
_scope void zcode_op_erase_line_6        (ZStack*, ZArgblock*);
_scope void zcode_op_set_cursor_4578     (ZStack*, ZArgblock*);
_scope void zcode_op_set_cursor_6        (ZStack*, ZArgblock*);
_scope void zcode_op_get_cursor_45678    (ZStack*, ZArgblock*);
_scope void zcode_op_set_text_style_45678(ZStack*, ZArgblock*);
_scope void zcode_op_buffer_mode_45678   (ZStack*, ZArgblock*);
_scope void zcode_op_output_stream_3     (ZStack*, ZArgblock*);
_scope void zcode_op_output_stream_4578  (ZStack*, ZArgblock*);
_scope void zcode_op_output_stream_6     (ZStack*, ZArgblock*);
_scope void zcode_op_input_stream_345678 (ZStack*, ZArgblock*);
_scope void zcode_op_sound_effect_345678 (ZStack*, ZArgblock*);
_scope void zcode_op_read_char_45678     (ZStack*, ZArgblock*, int);
_scope void zcode_op_scan_table_45678    (ZDWord*, ZStack*, ZArgblock*, int, ZDWord);
_scope void zcode_op_scan_tablen_45678   (ZDWord*, ZStack*, ZArgblock*, int, ZDWord);
_scope void zcode_op_not_5678            (ZStack*, ZArgblock*, int);
_scope void zcode_op_call_vn_5678        (ZDWord*, ZStack*, ZArgblock*);
_scope void zcode_op_call_vn2_5678       (ZDWord*, ZStack*, ZArgblock*);
_scope void zcode_op_tokenise_5678       (ZStack*, ZArgblock*);
_scope void zcode_op_encode_text_5678    (ZStack*, ZArgblock*);
_scope void zcode_op_copy_table_5678     (ZStack*, ZArgblock*);
_scope void zcode_op_print_table_5678    (ZStack*, ZArgblock*);
_scope void zcode_op_check_argcount_5678 (ZDWord*, ZStack*, ZArgblock*, ZDWord);
_scope void zcode_op_check_argcountn_5678(ZDWord*, ZStack*, ZArgblock*, ZDWord);

/* EXT ops */
_scope void zcode_op_save_5678           (ZDWord*, ZStack*, ZArgblock*, int);
_scope void zcode_op_restore_5678        (ZDWord*, ZStack*, ZArgblock*, int);
_scope void zcode_op_log_shift_5678      (ZStack*, ZArgblock*, int);
_scope void zcode_op_art_shift_5678      (ZStack*, ZArgblock*, int);
_scope void zcode_op_set_font_5678       (ZStack*, ZArgblock*, int);
_scope void zcode_op_save_undo_5678      (ZDWord*, ZStack*, ZArgblock*, int);
_scope void zcode_op_restore_undo_5678   (ZDWord*, ZStack*, ZArgblock*, int);
_scope void zcode_op_print_unicode_578   (ZStack*, ZArgblock*);
_scope void zcode_op_check_unicode_578   (ZStack*, ZArgblock*, int);

/* Our extensions to the Z-Machine */
_scope void zcode_op_start_timer_45678   (ZStack*, ZArgblock*);
_scope void zcode_op_stop_timer_45678    (ZStack*, ZArgblock*);
_scope void zcode_op_read_timer_45678    (ZStack*, ZArgblock*, int);
_scope void zcode_op_print_timer_45678   (ZStack*, ZArgblock*);

/* Utility functions */
extern ZWord   pop (ZStack* stack);
extern void    push(ZStack* stack, const ZWord word);
extern ZFrame* call_routine(ZDWord* pc, ZStack* stack, ZDWord start);
extern void    store(ZStack* stack, int var, ZWord value);

#undef _scope

#endif
