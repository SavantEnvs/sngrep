/*
 * mayhem/harness_link_stubs.c — link-only stubs for the two ncurses-UI functions that
 * src/filter.c's filter_check_call() references (case FILTER_CALL_LIST calls
 * ui_find_by_type()+call_list_line_text() to render a call-list row for text filtering).
 *
 * The harness never calls filter_set()/filter_enable() (see fuzz_sip_check_packet.c), so
 * `filters[FILTER_CALL_LIST].expr` is always NULL and filter_check_call() never actually
 * reaches that branch at runtime — but sip.c takes filter_check_call's ADDRESS as a
 * vector_iterator filter callback (sip_calls_iterator(), sip_calls_clear_soft()), so
 * filter.c must be linked, which in turn needs these two symbols to satisfy the linker.
 * Building the real src/curses/ui_call_list.c + src/curses/ui_manager.c here would drag in
 * the whole ncurses panel/window stack for code this harness provably never executes, so we
 * provide trivial stand-ins instead. This file lives entirely under mayhem/ and touches no
 * upstream source.
 */
#include "curses/ui_manager.h"
#include "curses/ui_call_list.h"

ui_t *
ui_find_by_type(enum panel_types type)
{
    (void) type;
    return NULL;
}

const char *
call_list_line_text(ui_t *ui, sip_call_t *call, char *text)
{
    (void) ui;
    (void) call;
    if (text)
        text[0] = '\0';
    return text;
}
