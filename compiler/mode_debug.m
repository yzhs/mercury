%-----------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sw=4 et
%-----------------------------------------------------------------------------%
% Copyright (C) 1996-1997, 2003-2005 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%
%
% File: mode_debug.m.
% Main author: fjh.
%
% This module contains code for tracing the actions of the mode checker.
%
%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- module check_hlds__mode_debug.

:- interface.

:- import_module check_hlds__mode_info.
:- import_module io.

    % Print a debugging message which includes the port, message string,
    % and the current instmap (but only if `--debug-modes' was enabled).
    %
:- pred mode_checkpoint(port::in, string::in, mode_info::in, mode_info::out,
    io::di, io::uo) is det.

:- type port
    --->    enter
    ;       exit
    ;       wakeup.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module check_hlds__modes.
:- import_module hlds__hlds_goal.
:- import_module hlds__hlds_module.
:- import_module hlds__instmap.
:- import_module hlds__passes_aux.
:- import_module libs__globals.
:- import_module libs__options.
:- import_module parse_tree__mercury_to_mercury.
:- import_module parse_tree__prog_data.
:- import_module parse_tree__prog_out.

:- import_module assoc_list.
:- import_module bool.
:- import_module list.
:- import_module map.
:- import_module std_util.
:- import_module term.
:- import_module varset.

%-----------------------------------------------------------------------------%

    % This code is used to trace the actions of the mode checker.

mode_checkpoint(Port, Msg, !ModeInfo, !IO) :-
    mode_info_get_debug_modes(!.ModeInfo, DebugModes),
    (
        DebugModes = yes(debug_flags(Verbose, Minimal, Statistics)),
        mode_checkpoint_write(Verbose, Minimal, Statistics, Port, Msg,
            !ModeInfo, !IO)
    ;
        DebugModes = no
    ).

:- pred mode_checkpoint_write(bool::in, bool::in, bool::in, port::in,
    string::in, mode_info::in, mode_info::out, io::di, io::uo) is det.

mode_checkpoint_write(Verbose, Minimal, Statistics, Port, Msg, !ModeInfo,
        !IO) :-
    mode_info_get_errors(!.ModeInfo, Errors),
    ( Port = enter ->
        io__write_string("Enter ", !IO),
        Detail = yes
    ; Port = wakeup ->
        io__write_string("Wake ", !IO),
        Detail = no
    ; Errors = [] ->
        io__write_string("Exit ", !IO),
        Detail = yes
    ;
        io__write_string("Delay ", !IO),
        Detail = no
    ),
    io__write_string(Msg, !IO),
    (
        Detail = yes,
        io__write_string(":\n", !IO),
        maybe_report_stats(Statistics, !IO),
        maybe_flush_output(Statistics, !IO),
        mode_info_get_instmap(!.ModeInfo, InstMap),
        ( instmap__is_reachable(InstMap) ->
            instmap__to_assoc_list(InstMap, NewInsts),
            mode_info_get_last_checkpoint_insts(!.ModeInfo, OldInstMap),
            mode_info_get_varset(!.ModeInfo, VarSet),
            mode_info_get_instvarset(!.ModeInfo, InstVarSet),
            write_var_insts(NewInsts, OldInstMap, VarSet, InstVarSet,
                Verbose, Minimal, !IO)
        ;
            io__write_string("\tUnreachable\n", !IO)
        ),
        mode_info_set_last_checkpoint_insts(InstMap, !ModeInfo)
    ;
        Detail = no
    ),
    io__write_string("\n", !IO),
    io__flush_output(!IO).

:- pred write_var_insts(assoc_list(prog_var, inst)::in, instmap::in,
    prog_varset::in, inst_varset::in, bool::in, bool::in,
    io::di, io::uo) is det.

write_var_insts([], _, _, _, _, _, !IO).
write_var_insts([Var - Inst | VarInsts], OldInstMap, VarSet, InstVarSet,
        Verbose, Minimal, !IO) :-
    instmap__lookup_var(OldInstMap, Var, OldInst),
    (
        (
            identical_insts(Inst, OldInst)
        ;
            Inst = OldInst
        )
    ->
        (
            Verbose = yes,
            io__write_string("\t", !IO),
            mercury_output_var(Var, VarSet, no, !IO),
            io__write_string(" ::", !IO),
            io__write_string(" unchanged\n", !IO)
        ;
            Verbose = no
        )
    ;
        io__write_string("\t", !IO),
        mercury_output_var(Var, VarSet, no, !IO),
        io__write_string(" ::", !IO),
        (
            Minimal = yes,
            io__write_string(" changed\n", !IO)
        ;
            Minimal = no,
            io__write_string("\n", !IO),
            mercury_output_structured_inst(Inst, 2, InstVarSet, !IO)
        )
    ),
    write_var_insts(VarInsts, OldInstMap, VarSet, InstVarSet,
        Verbose, Minimal, !IO).

    % In the usual case of a C backend, this predicate allows us to
    % conclude that two insts are identical without traversing them.
    % Since the terms can be very large, this is a big gain; it can
    % turn the complexity of printing a checkpoint from quadratic in the
    % number of variables live at the checkpoint (when the variables
    % are e.g. all part of a single long list) to linear. The minor
    % increase in the constant factor in cases where identical_insts fails
    % is much easier to live with.
    %
:- pred identical_insts((inst)::in, (inst)::in) is semidet.

identical_insts(_, _) :-
    semidet_fail.

:- pragma foreign_proc("C",
    identical_insts(InstA::in, InstB::in),
    [will_not_call_mercury, promise_pure],
"
    if (InstA == InstB) {
        SUCCESS_INDICATOR = MR_TRUE;
    } else {
        SUCCESS_INDICATOR = MR_FALSE;
    }
").

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%
