%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

% mode_util.nl - utility predicates dealing with modes and insts.

% Main author: fjh.

:- module mode_util.
:- interface.
:- import_module hlds, int, string, list, prog_io.

	% XXX how should these predicates handle abstract insts?
	% In that case, we don't _know_ whether the mode is input
	% or not!

:- pred mode_is_input(module_info, mode).
:- mode mode_is_input(in, in) is semidet.

:- pred mode_is_output(module_info, mode).
:- mode mode_is_output(in, in) is semidet.

:- pred inst_is_ground(module_info, inst).
:- mode inst_is_ground(in, in) is semidet.

:- pred inst_list_is_ground(list(inst), module_info).
:- mode inst_list_is_ground(in, in) is semidet.

:- pred inst_is_free(module_info, inst).
:- mode inst_is_free(in, in) is semidet.

:- pred inst_list_is_free(list(inst), module_info).
:- mode inst_list_is_free(in, in) is semidet.

:- pred bound_inst_list_is_free(list(bound_inst), module_info).
:- mode bound_inst_list_is_free(in, in) is semidet.

:- pred bound_inst_list_is_ground(list(bound_inst), module_info).
:- mode bound_inst_list_is_ground(in, in) is semidet.

:- pred mode_id_to_int(mode_id, int).
:- mode mode_id_to_int(in, out) is det.

:- pred mode_list_get_final_insts(list(mode), module_info, list(inst)).
:- mode mode_list_get_final_insts(in, in, out) is det.

:- pred mode_list_get_initial_insts(list(mode), module_info, list(inst)).
:- mode mode_list_get_initial_insts(in, in, out) is det.

:- pred inst_lookup(module_info, sym_name, list(inst), inst).
:- mode inst_lookup(in, in, in, out) is det.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.
:- import_module require, map, set, term, std_util.

mode_list_get_final_insts([], _ModuleInfo, []).
mode_list_get_final_insts([Mode | Modes], ModuleInfo, [Inst | Insts]) :-
	mode_get_insts(ModuleInfo, Mode, _, Inst),
	mode_list_get_final_insts(Modes, ModuleInfo, Insts).

mode_list_get_initial_insts([], _ModuleInfo, []).
mode_list_get_initial_insts([Mode | Modes], ModuleInfo, [Inst | Insts]) :-
	mode_get_insts(ModuleInfo, Mode, Inst, _),
	mode_list_get_initial_insts(Modes, ModuleInfo, Insts).

%-----------------------------------------------------------------------------%

	% A mode is considered an input mode if the top-level
	% node is input.

mode_is_input(ModuleInfo, Mode) :-
	mode_get_insts(ModuleInfo, Mode, InitialInst, _FinalInst),
	inst_is_bound(ModuleInfo, InitialInst).

	% A mode is considered an output mode if the top-level
	% node is output.

mode_is_output(ModuleInfo, Mode) :-
	mode_get_insts(ModuleInfo, Mode, InitialInst, FinalInst),
	inst_is_free(ModuleInfo, InitialInst),
	inst_is_bound(ModuleInfo, FinalInst).

	% inst_is_free succeeds iff the inst passed is `free'
	% or is a user-defined inst which is defined as `free'.
	% Abstract insts must not be free.

:- inst_is_free(_, X) when X.		% NU-Prolog indexing.

inst_is_free(_, free).
inst_is_free(_, inst_var(_)) :-
	error("internal error: uninstantiated inst parameter").
inst_is_free(ModuleInfo, user_defined_inst(Name, Args)) :-
	inst_lookup(ModuleInfo, Name, Args, Inst),
	inst_is_free(ModuleInfo, Inst).

	% inst_is_bound succeeds iff the inst passed is not `free'
	% or is a user-defined inst which is not defined as `free'.
	% Abstract insts must be bound.

:- pred inst_is_bound(module_info, inst).
:- mode inst_is_bound(in, in) is semidet.

:- inst_is_bound(_, X) when X.		% NU-Prolog indexing.

inst_is_bound(_, ground).
inst_is_bound(_, bound(_)).
inst_is_bound(_, inst_var(_)) :-
	error("internal error: uninstantiated inst parameter").
inst_is_bound(ModuleInfo, user_defined_inst(Name, Args)) :-
	inst_lookup(ModuleInfo, Name, Args, Inst),
	inst_is_bound(ModuleInfo, Inst).
inst_is_bound(_, abstract_inst(_, _)).

	% inst_is_bound_to_functors succeeds iff the inst passed is
	% `bound(Functors)' or is a user-defined inst which expands to
	% `bound(Functors)'.

:- pred inst_is_bound_to_functors(module_info, inst, list(bound_inst)).
:- mode inst_is_bound_to_functors(in, in, out) is semidet.

:- inst_is_bound_to_functors(_, _, X) when X.		% NU-Prolog indexing.

inst_is_bound_to_functors(_, bound(Functors), Functors).
inst_is_bound_to_functors(_, inst_var(_), _) :-
	error("internal error: uninstantiated inst parameter").
inst_is_bound_to_functors(ModuleInfo, user_defined_inst(Name, Args), Functors)
		:-
	inst_lookup(ModuleInfo, Name, Args, Inst),
	inst_is_bound_to_functors(ModuleInfo, Inst, Functors).

	% inst_is_ground succeeds iff the inst passed is `ground'
	% or the equivalent.  Abstract insts are not considered ground.

inst_is_ground(ModuleInfo, Inst) :-
	set__init(Expansions),
	inst_is_ground_2(ModuleInfo, Inst, Inst, Expansions).

	% The third argument must be the same as the second.
	% The fourth arg is the set of insts which have already
	% been expanded - we use this to avoid going into an
	% infinite loop.

:- pred inst_is_ground_2(module_info, inst, inst, set(inst)).
:- mode inst_is_ground_2(in, in, in, in) is semidet.

:- inst_is_ground_2(_, X, _, _) when X.		% NU-Prolog indexing.

inst_is_ground_2(ModuleInfo, bound(List), _, Expansions) :-
	bound_inst_list_is_ground_2(List, ModuleInfo, Expansions).
inst_is_ground_2(_, ground, _, _).
inst_is_ground_2(_, inst_var(_), _, _) :-
	error("internal error: uninstantiated inst parameter").
inst_is_ground_2(ModuleInfo, user_defined_inst(Name, Args), Inst, Expansions) :-
	( set__member(Inst, Expansions) ->
		true
	;
		set__insert(Expansions, Inst, Expansions2),
		inst_lookup(ModuleInfo, Name, Args, Inst2),
		inst_is_ground_2(ModuleInfo, Inst2, Inst2, Expansions2)
	).

bound_inst_list_is_ground([], _).
bound_inst_list_is_ground([functor(_Name, Args)|BoundInsts], ModuleInfo) :-
	inst_list_is_ground(Args, ModuleInfo),
	bound_inst_list_is_ground(BoundInsts, ModuleInfo).

:- pred bound_inst_list_is_ground_2(list(bound_inst), module_info, set(inst)).
:- mode bound_inst_list_is_ground_2(in, in, in) is semidet.

bound_inst_list_is_ground_2([], _, _).
bound_inst_list_is_ground_2([functor(_Name, Args)|BoundInsts], ModuleInfo,
		Expansions) :-
	inst_list_is_ground_2(Args, ModuleInfo, Expansions),
	bound_inst_list_is_ground_2(BoundInsts, ModuleInfo, Expansions).

inst_list_is_ground([], _).
inst_list_is_ground([Inst | Insts], ModuleInfo) :-
	inst_is_ground(ModuleInfo, Inst),
	inst_list_is_ground(Insts, ModuleInfo).

:- pred inst_list_is_ground_2(list(inst), module_info, set(inst)).
:- mode inst_list_is_ground_2(in, in, in) is semidet.

inst_list_is_ground_2([], _, _).
inst_list_is_ground_2([Inst | Insts], ModuleInfo, Expansions) :-
	inst_is_ground_2(ModuleInfo, Inst, Inst, Expansions),
	inst_list_is_ground_2(Insts, ModuleInfo, Expansions).

bound_inst_list_is_free([], _).
bound_inst_list_is_free([functor(_Name, Args)|BoundInsts], ModuleInfo) :-
	inst_list_is_free(Args, ModuleInfo),
	bound_inst_list_is_free(BoundInsts, ModuleInfo).

inst_list_is_free([], _).
inst_list_is_free([Inst | Insts], ModuleInfo) :-
	inst_is_free(ModuleInfo, Inst),
	inst_list_is_free(Insts, ModuleInfo).

inst_lookup(ModuleInfo, Name, Args, Inst) :-
	length(Args, Arity),
	module_info_insts(ModuleInfo, Insts),
	map__search(Insts, Name - Arity, InstDefn),
	InstDefn = hlds__inst_defn(_VarSet, Params, Inst0, _Cond, _Context),
	inst_lookup_2(Inst0, Params, Name, Args, Inst).

:- pred inst_lookup_2(hlds__inst_body, list(inst_param), sym_name, list(inst),
			inst).
:- mode inst_lookup_2(in, in, in, in, out).

inst_lookup_2(eqv_inst(Inst0), Params, _Name, Args, Inst) :-
	inst_substitute_arg_list(Inst0, Params, Args, Inst).
inst_lookup_2(abstract_inst, _Params, Name, Args,
		abstract_inst(Name, Args)).

	% mode_get_insts returns the initial instantiatedness and
	% the final instantiatedness for a given mode.

:- pred mode_get_insts(module_info, mode, inst, inst).
:- mode mode_get_insts(in, in, out, out).

mode_get_insts(_ModuleInfo, InitialInst -> FinalInst, InitialInst, FinalInst).
mode_get_insts(ModuleInfo, user_defined_mode(Name, Args), Initial, Final) :-
	length(Args, Arity),
	module_info_modes(ModuleInfo, Modes),
	map__search(Modes, Name - Arity, HLDS_Mode),
	HLDS_Mode = hlds__mode_defn(_VarSet, Params, ModeDefn, _Cond, _Context),
	ModeDefn = eqv_mode(Mode0),
	mode_substitute_arg_list(Mode0, Params, Args, Mode),
	mode_get_insts(ModuleInfo, Mode, Initial, Final).

	% mode_substitute_arg_list(Mode0, Params, Args, Mode) is true
	% iff Mode is the mode that results from substituting all
	% occurrences of Params in Mode0 with the corresponding
	% value in Args.

:- pred mode_substitute_arg_list(mode, list(inst_param), list(inst), mode).
:- mode mode_substitute_arg_list(in, in, in, out).

mode_substitute_arg_list(Mode0, Params, Args, Mode) :-
	( Params = [] ->
		Mode = Mode0	% optimize common case
	;
		map__from_corresponding_lists(Params, Args, Subst),
		mode_apply_substitution(Mode0, Subst, Mode)
	).
		
	% inst_substitute_arg_list(Inst0, Params, Args, Inst) is true
	% iff Inst is the inst that results from substituting all
	% occurrences of Params in Inst0 with the corresponding
	% value in Args.

:- pred inst_substitute_arg_list(inst, list(inst_param), list(inst), inst).
:- mode inst_substitute_arg_list(in, in, in, out).

inst_substitute_arg_list(Inst0, Params, Args, Inst) :-
	( Params = [] ->
		Inst = Inst0	% optimize common case
	;
		map__from_corresponding_lists(Params, Args, Subst),
		inst_apply_substitution(Inst0, Subst, Inst)
	).

	% mode_apply_substitution(Mode0, Subst, Mode) is true iff
	% Mode is the mode that results from apply Subst to Mode0.

:- type inst_subst == map(inst_param, inst).

:- pred mode_apply_substitution(mode, inst_subst, mode).
:- mode mode_apply_substitution(in, in, out).

mode_apply_substitution(I0 -> F0, Subst, I -> F) :-
	inst_apply_substitution(I0, Subst, I),
	inst_apply_substitution(F0, Subst, F).
mode_apply_substitution(user_defined_mode(Name, Args0), Subst,
		    user_defined_mode(Name, Args)) :-
	inst_list_apply_substitution(Args0, Subst, Args).

	% inst_list_apply_substitution(Insts0, Subst, Insts) is true
	% iff Inst is the inst that results from applying Subst to Insts0.

:- pred inst_list_apply_substitution(list(inst), inst_subst, list(inst)).
:- mode inst_list_apply_substitution(in, in, out).

inst_list_apply_substitution([], _, []).
inst_list_apply_substitution([A0 | As0], Subst, [A | As]) :-
	inst_apply_substitution(A0, Subst, A),
	inst_list_apply_substitution(As0, Subst, As).

	% inst_substitute_arg(Inst0, Subst, Inst) is true
	% iff Inst is the inst that results from substituting all
	% occurrences of Param in Inst0 with Arg.

:- pred inst_apply_substitution(inst, inst_subst, inst).
:- mode inst_apply_substitution(in, in, out).

inst_apply_substitution(free, _, free).
inst_apply_substitution(ground, _, ground).
inst_apply_substitution(bound(Alts0), Subst, bound(Alts)) :-
	alt_list_apply_substitution(Alts0, Subst, Alts).
inst_apply_substitution(inst_var(Var), Subst, Result) :-
	(if some [Replacement]
		% XXX should params be vars?
		map__search(Subst, term__variable(Var), Replacement)
	then
		Result = Replacement
	else
		Result = inst_var(Var)
	).
inst_apply_substitution(user_defined_inst(Name, Args0), Subst,
		    user_defined_inst(Name, Args)) :-
	inst_list_apply_substitution(Args0, Subst, Args).
inst_apply_substitution(abstract_inst(Name, Args0), Subst,
		    abstract_inst(Name, Args)) :-
	inst_list_apply_substitution(Args0, Subst, Args).

:- pred alt_list_apply_substitution(list(bound_inst), inst_subst,
				list(bound_inst)).
:- mode alt_list_apply_substitution(in, in, out).

alt_list_apply_substitution([], _, []).
alt_list_apply_substitution([Alt0|Alts0], Subst, [Alt|Alts]) :-
	Alt0 = functor(Name, Args0),
	inst_list_apply_substitution(Args0, Subst, Args),
	Alt = functor(Name, Args),
	alt_list_apply_substitution(Alts0, Subst, Alts).

%-----------------------------------------------------------------------------%

	% In case we later decided to change the representation
	% of mode_ids.

mode_id_to_int(_ - X, X).

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%
