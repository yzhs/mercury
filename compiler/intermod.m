%-----------------------------------------------------------------------------%
% Copyright (C) 1996-1999 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%
%
% file: intermod.m
% main author: stayl
%
% This module writes out the interface for inter-module optimization.
% The .opt file includes:
%	- The clauses for exported preds that can be inlined.
%	- The clauses for exported preds that have higher-order pred arguments.
%	- The pred/mode declarations for local predicates that the
%	  above clauses use.
% 	- Non-exported types, insts and modes used by the above.
%	- :- import_module declarations to import stuff used by the above.
%	- pragma declarations for the exported preds.
%	- pragma c_header declarations if any pragma_c_code preds are written.
% All these items should be module qualified.
%
% This module also contains predicates to read in the .opt files and
% to adjust the import status of local predicates which are exported for
% intermodule optimization.
%	
% Note that predicates which call predicates that do not have mode or
% determinism declarations do not have clauses exported, since this would
% require running mode analysis and determinism analysis before writing the
% .opt file, significantly increasing compile time for a very small gain.
%
%-----------------------------------------------------------------------------%

:- module intermod.

%-----------------------------------------------------------------------------%

:- interface.

:- import_module io, bool.
:- import_module hlds_module, modules, prog_io, prog_data.

:- pred intermod__write_optfile(module_info, module_info,
				io__state, io__state).
:- mode intermod__write_optfile(in, out, di, uo) is det.

	% Add the items from the .opt files of imported modules to
	% the items for this module.
:- pred intermod__grab_optfiles(module_imports, module_imports, bool,
				io__state, io__state).
:- mode intermod__grab_optfiles(in, out, out, di, uo) is det.

	% Make sure that local preds which have been exported in the .opt
	% file get an exported(_) label.
:- pred intermod__adjust_pred_import_status(module_info, module_info,
		io__state, io__state).
:- mode intermod__adjust_pred_import_status(in, out, di, uo) is det.

:- type opt_file_type
	--->	opt
	;	trans_opt
	.

	% intermod__update_error_status(OptFileType, FileName, Error, Messages,
	% 	Status0, Status)
	%
	% Work out whether any fatal errors have occurred while reading
	% `.opt' files, updating Status0 if there were fatal errors.
	%
	% A missing `.opt' file is only a fatal error if
	% `--warn-missing-opt-files --halt-at-warn' was passed
	% the compiler.
	%
	% Syntax errors in `.opt' files are always fatal.
	%
	% This is also used by trans_opt.m for reading `.trans_opt' files.
:- pred intermod__update_error_status(opt_file_type, string, module_error,
		message_list, bool, bool, io__state, io__state).
:- mode intermod__update_error_status(in, in, in, in, in, out, di, uo) is det.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module assoc_list, dir, getopt, int, list, map, multi_map, require.
:- import_module set, std_util, string, term, varset.

:- import_module code_util, globals, goal_util, term, varset.
:- import_module hlds_data, hlds_goal, hlds_pred, hlds_out, inlining, llds.
:- import_module mercury_to_mercury, mode_util, modules.
:- import_module options, passes_aux, prog_data, prog_io, prog_out, prog_util.
:- import_module special_pred, typecheck, type_util, instmap, (inst).

%-----------------------------------------------------------------------------%

% Open the file "<module-name>.opt.tmp", and write out the
% declarations and clauses for intermodule optimization.
% Note that update_interface and touch_interface_datestamp
% are called from mercury_compile.m since they must be called
% after unused_args.m appends its information to the .opt.tmp
% file.

intermod__write_optfile(ModuleInfo0, ModuleInfo) -->
	{ module_info_name(ModuleInfo0, ModuleName) },
	module_name_to_file_name(ModuleName, ".opt.tmp", yes, TmpName),
	io__tell(TmpName, Result2),
	(
		{ Result2 = error(Err2) },
		{ io__error_message(Err2, Msg2) },
		io__stderr_stream(ErrStream2),
		io__write_string(ErrStream2, Msg2),
		io__set_exit_status(1),
		{ ModuleInfo = ModuleInfo0 }
	;
		{ Result2 = ok },
		{ module_info_predids(ModuleInfo0, RealPredIds) },
		{ module_info_assertion_table(ModuleInfo0, AssertionTable) },
		{ assertion_table_pred_ids(AssertionTable, AssertPredIds) },
		{ list__append(AssertPredIds, RealPredIds, PredIds) },
		{ init_intermod_info(ModuleInfo0, IntermodInfo0) },
		globals__io_lookup_int_option(
			intermod_inline_simple_threshold, Threshold),
		globals__io_lookup_bool_option(deforestation, Deforestation),
		globals__io_lookup_int_option(higher_order_size_limit,
			HigherOrderSizeLimit),
		{ intermod__gather_preds(PredIds, yes, Threshold,
			HigherOrderSizeLimit, Deforestation,
			IntermodInfo0, IntermodInfo1) },
		{ intermod__gather_instances(IntermodInfo1,
			IntermodInfo) },
		intermod__write_intermod_info(IntermodInfo),
		{ intermod_info_get_module_info(ModuleInfo1,
			IntermodInfo, _) },
		io__told,
		globals__io_lookup_bool_option(intermod_unused_args,
			UnusedArgs),
		( { UnusedArgs = yes } ->
			globals__io_get_globals(Globals),
			{ do_adjust_pred_import_status(IntermodInfo, Globals,
				ModuleInfo1, ModuleInfo) }
		;
			{ ModuleInfo = ModuleInfo1 }
		)
	).

	% a collection of stuff to go in the .opt file
:- type intermod_info
		 ---> info(
			set(module_name),	% modules to import
			set(pred_id), 		% preds to output clauses for
			set(pred_id),	 	% preds to output decls for
			list(pair(class_id, hlds_instance_defn)),
						% instances declarations
						% to write
			unit,
			unit,
			module_info,
			bool,			% do the c_header_codes for
				% the module need writing, yes if there
				% are pragma_c_code procs being exported
			map(prog_var, type),	% Vartypes and tvarset for the
			tvarset			% current pred
		).

:- pred init_intermod_info(module_info::in, intermod_info::out) is det.

init_intermod_info(ModuleInfo, IntermodInfo) :-
	set__init(Modules),
	set__init(Procs),
	set__init(ProcDecls),
	map__init(VarTypes),
	varset__init(TVarSet),
	Instances = [],
	IntermodInfo = info(Modules, Procs, ProcDecls, Instances, unit,
			unit, ModuleInfo, no, VarTypes, TVarSet).
			
%-----------------------------------------------------------------------------%
	% Predicates to gather stuff to output to .opt file.

:- pred intermod__gather_preds(list(pred_id)::in, bool::in, int::in,
	int::in, bool::in, intermod_info::in, intermod_info::out) is det.

intermod__gather_preds([], _CollectTypes, _, _, _) --> [].
intermod__gather_preds([PredId | PredIds], CollectTypes,
		InlineThreshold, HigherOrderSizeLimit, Deforestation) -->
	intermod_info_get_module_info(ModuleInfo0),
	{ module_info_preds(ModuleInfo0, PredTable0) },
	{ map__lookup(PredTable0, PredId, PredInfo0) },
	{ module_info_type_spec_info(ModuleInfo0, TypeSpecInfo) },
	{ TypeSpecInfo = type_spec_info(_, TypeSpecForcePreds, _, _) },
	(
		{ intermod__should_be_processed(PredId, PredInfo0,
			TypeSpecForcePreds, InlineThreshold,
			HigherOrderSizeLimit, Deforestation, ModuleInfo0) }
	->
		=(IntermodInfo0),
		{ pred_info_clauses_info(PredInfo0, ClausesInfo0) },
		{ pred_info_typevarset(PredInfo0, TVarSet) },
		{ clauses_info_vartypes(ClausesInfo0, VarTypes) },
		{ clauses_info_clauses(ClausesInfo0, Clauses0) },
		intermod_info_set_var_types(VarTypes),
		intermod_info_set_tvarset(TVarSet),
		intermod__traverse_clauses(Clauses0, Clauses, DoWrite),
		( { DoWrite = yes } ->
			{ clauses_info_set_clauses(ClausesInfo0, Clauses,
				ClausesInfo) },
			{ pred_info_set_clauses_info(PredInfo0, ClausesInfo,
					PredInfo) },	
			{ map__det_update(PredTable0, PredId,
					PredInfo, PredTable) },
			{ module_info_set_preds(ModuleInfo0, PredTable,
					ModuleInfo) },
			intermod_info_get_preds(Preds0),
			( { pred_info_get_goal_type(PredInfo, pragmas) } ->
				% The header code must be written since
				% it could be used by the pragma_c_code.
				intermod_info_set_write_header
			;
				[]
			),
			{ set__insert(Preds0, PredId, Preds) },
			intermod_info_set_preds(Preds),
			intermod_info_set_module_info(ModuleInfo)
		;
			% Remove any items added for the clauses
			% for this predicate.
			dcg_set(IntermodInfo0)
		)
	;
		[]
	),
	intermod__gather_preds(PredIds, CollectTypes,
		InlineThreshold, HigherOrderSizeLimit, Deforestation).


:- pred intermod__should_be_processed(pred_id::in, pred_info::in,
		set(pred_id)::in, int::in, int::in, bool::in,
		module_info::in) is semidet.

intermod__should_be_processed(PredId, PredInfo, TypeSpecForcePreds,
		InlineThreshold, HigherOrderSizeLimit,
		Deforestation, ModuleInfo) :-
	%
	% note: we can't include exported_to_submodules predicates in
	% the `.opt' file, for reasons explained in the comments for
	% intermod__add_proc
	%
	pred_info_is_exported(PredInfo),
	(
		pred_info_clauses_info(PredInfo, ClauseInfo),
		clauses_info_clauses(ClauseInfo, Clauses),

		pred_info_procids(PredInfo, [ProcId | _ProcIds]),
		pred_info_procedures(PredInfo, Procs),
		map__lookup(Procs, ProcId, ProcInfo),

		% At this point, the goal size includes some dummy unifications
		% HeadVar1 = X, HeadVar2 = Y, etc. which will be optimized away
		% later.  To counter for this, we add the arity to the
		% size thresholds.
		pred_info_arity(PredInfo, Arity),

		% Predicates with `class_method' markers contain
		% class_method_call goals which can't be written
		% to `.opt' files (they can't be read back in).
		% They will be recreated in the importing module.
		pred_info_get_markers(PredInfo, Markers),
		\+ check_marker(Markers, class_method),
		\+ check_marker(Markers, class_instance_method),

		% Don't export builtins since they will be
		% recreated in the importing module anyway.
		\+ code_util__compiler_generated(PredInfo),
		\+ code_util__predinfo_is_builtin(PredInfo),

		% These will be recreated in the importing module.
		\+ set__member(PredId, TypeSpecForcePreds),

		(
			inlining__is_simple_clause_list(Clauses,
				InlineThreshold + Arity),
			pred_info_get_markers(PredInfo, Markers),
			\+ check_marker(Markers, no_inline),
			proc_info_eval_method(ProcInfo, eval_normal)
		;
			pred_info_requested_inlining(PredInfo)
		;
			has_ho_input(ModuleInfo, ProcInfo),
			clause_list_size(Clauses, GoalSize),
			GoalSize =< HigherOrderSizeLimit + Arity
		;
			Deforestation = yes,
			% Double the inline-threshold since
			% goals we want to deforest will have at
			% least two disjuncts. This allows one
			% simple goal in each disjunct.  The
			% disjunction adds one to the goal size,
			% hence the `+1'.
			DeforestThreshold is InlineThreshold * 2 + 1,
			inlining__is_simple_clause_list(Clauses,
				DeforestThreshold + Arity),
			clause_list_is_deforestable(PredId, Clauses)
		)
	;
		% assertions that are in the interface should always get
		% included in the .opt file.
		pred_info_get_goal_type(PredInfo, assertion)
	).

:- pred dcg_set(T::in, T::unused, T::out) is det.
dcg_set(T, _, T).

:- pred intermod__traverse_clauses(list(clause)::in, list(clause)::out,
		bool::out, intermod_info::in, intermod_info::out) is det.

intermod__traverse_clauses([], [], yes) --> [].
intermod__traverse_clauses([clause(P, Goal0, C) | Clauses0],
			[clause(P, Goal, C) | Clauses], DoWrite) -->
	intermod__traverse_goal(Goal0, Goal, DoWrite1),
	( { DoWrite1 = yes } ->
		intermod__traverse_clauses(Clauses0, Clauses, DoWrite)
	;
		{ Clauses = Clauses0 },
		{ DoWrite = no }
	).

:- pred has_ho_input(module_info::in, proc_info::in) is semidet.

has_ho_input(ModuleInfo, ProcInfo) :-
	proc_info_headvars(ProcInfo, HeadVars),
	proc_info_argmodes(ProcInfo, ArgModes),
	proc_info_vartypes(ProcInfo, VarTypes),
	check_for_ho_input_args(ModuleInfo, HeadVars, ArgModes, VarTypes).

:- pred check_for_ho_input_args(module_info::in, list(prog_var)::in,
		list(mode)::in, map(prog_var, type)::in) is semidet.

check_for_ho_input_args(ModuleInfo, [HeadVar | HeadVars],
			[ArgMode | ArgModes], VarTypes) :-
	(
		mode_is_input(ModuleInfo, ArgMode),
		map__lookup(VarTypes, HeadVar, Type),
		classify_type(Type, ModuleInfo, pred_type)
	;
		check_for_ho_input_args(ModuleInfo, HeadVars,
							ArgModes, VarTypes)
	).

	% Rough guess: a goal is deforestable if it contains a single
	% top-level branched goal and is recursive.
:- pred clause_list_is_deforestable(pred_id::in, list(clause)::in) is semidet.

clause_list_is_deforestable(PredId, Clauses)  :-
	some [Clause1] (
		list__member(Clause1, Clauses),
		Clause1 = clause(_, Goal1, _),
		goal_calls_pred_id(Goal1, PredId)
	),
	(
		Clauses = [_, _ | _]
	;
		Clauses = [Clause2],
		Clause2 = clause(_, Goal2, _),
		goal_to_conj_list(Goal2, GoalList),
		goal_contains_one_branched_goal(GoalList)
	).

:- pred goal_contains_one_branched_goal(list(hlds_goal)::in) is semidet.

goal_contains_one_branched_goal(GoalList) :-
	goal_contains_one_branched_goal(GoalList, no).

:- pred goal_contains_one_branched_goal(list(hlds_goal)::in,
		bool::in) is semidet.

goal_contains_one_branched_goal([], yes).
goal_contains_one_branched_goal([Goal | Goals], FoundBranch0) :-
	Goal = GoalExpr - _,
	(
		goal_is_branched(GoalExpr),
		FoundBranch0 = no,
		FoundBranch = yes
	;
		goal_is_atomic(GoalExpr),
		FoundBranch = FoundBranch0
	),
	goal_contains_one_branched_goal(Goals, FoundBranch).

	% Go over the goal of an exported proc looking for proc decls, types,
	% insts and modes that we need to write to the optfile.
:- pred intermod__traverse_goal(hlds_goal::in, hlds_goal::out, bool::out,
			intermod_info::in, intermod_info::out) is det.

intermod__traverse_goal(conj(Goals0) - Info, conj(Goals) - Info, DoWrite) -->
	intermod__traverse_list_of_goals(Goals0, Goals, DoWrite).

intermod__traverse_goal(par_conj(Goals0, SM) - Info, par_conj(Goals, SM) - Info,
		DoWrite) -->
	intermod__traverse_list_of_goals(Goals0, Goals, DoWrite).

intermod__traverse_goal(disj(Goals0, SM) - Info, disj(Goals, SM) - Info,
		DoWrite) -->
	intermod__traverse_list_of_goals(Goals0, Goals, DoWrite).

intermod__traverse_goal(
	call(PredId0, B, Args, D, MaybeUnifyContext, PredName0) - Info,
	call(PredId, B, Args, D, MaybeUnifyContext, PredName) - Info, DoWrite)
		-->
	%
	% Fully module-qualify the pred name
	%
	intermod_info_get_module_info(ModuleInfo),
	intermod_info_get_var_types(VarTypes),
	intermod_info_get_tvarset(TVarSet),
	( { invalid_pred_id(PredId0) } ->
		{ map__apply_to_list(Args, VarTypes, ArgTypes) },
		{ typecheck__resolve_pred_overloading(ModuleInfo, ArgTypes,
			TVarSet, PredName0, PredName1, PredId) }
	;
		{ PredId = PredId0 },
		{ PredName1 = PredName0 }
	),	
	{ unqualify_name(PredName1, UnqualPredName) },
	{ module_info_pred_info(ModuleInfo, PredId, PredInfo) },
	{ pred_info_module(PredInfo, PredModule) },
	{ PredName = qualified(PredModule, UnqualPredName) },

	%
	% Ensure that the called predicate will be exported.
	%
	intermod__add_proc(PredId, DoWrite).

intermod__traverse_goal(generic_call(A,B,C,D) - Info,
			generic_call(A,B,C,D) - Info, yes) --> [].

intermod__traverse_goal(switch(A, B, Cases0, D) - Info,
		switch(A, B, Cases, D) - Info, DoWrite) -->
	intermod__traverse_cases(Cases0, Cases, DoWrite).

	% Export declarations for preds used in higher order pred constants
	% or function calls.
intermod__traverse_goal(unify(LVar, RHS0, C, D, E) - Info,
			unify(LVar, RHS, C, D, E) - Info, DoWrite) -->
	intermod__module_qualify_unify_rhs(LVar, RHS0, RHS, DoWrite).

intermod__traverse_goal(not(Goal0) - Info, not(Goal) - Info, DoWrite) -->
	intermod__traverse_goal(Goal0, Goal, DoWrite).

intermod__traverse_goal(some(Vars, CanRemove, Goal0) - Info,
		some(Vars, CanRemove, Goal) - Info, DoWrite) -->
	intermod__traverse_goal(Goal0, Goal, DoWrite).

intermod__traverse_goal(if_then_else(Vars, Cond0, Then0, Else0, SM) - Info,
		if_then_else(Vars, Cond, Then, Else, SM) - Info, DoWrite) -->
	intermod__traverse_goal(Cond0, Cond, DoWrite1),
	intermod__traverse_goal(Then0, Then, DoWrite2),
	intermod__traverse_goal(Else0, Else, DoWrite3),
	{ bool__and_list([DoWrite1, DoWrite2, DoWrite3], DoWrite) }.

	% Inlineable exported pragma_c_code goals can't use any
	% non-exported types, so we just write out the clauses. 
intermod__traverse_goal(pragma_c_code(A,B,C,D,E,F,G) - Info,
			pragma_c_code(A,B,C,D,E,F,G) - Info, yes) --> [].

intermod__traverse_goal(bi_implication(_, _) - _, _, _) -->
	% these should have been expanded out by now
	{ error("intermod__traverse_goal: unexpected bi_implication") }.


:- pred intermod__traverse_list_of_goals(hlds_goals::in, hlds_goals::out,
		bool::out, intermod_info::in, intermod_info::out) is det.

intermod__traverse_list_of_goals([], [], yes) --> [].
intermod__traverse_list_of_goals([Goal0 | Goals0], [Goal | Goals], DoWrite) -->
	intermod__traverse_goal(Goal0, Goal, DoWrite1),
	( { DoWrite1 = yes } ->
		intermod__traverse_list_of_goals(Goals0, Goals, DoWrite)
	;
		{ DoWrite = no },
		{ Goals = Goals0 }
	).

:- pred intermod__traverse_cases(list(case)::in, list(case)::out, bool::out,
			intermod_info::in, intermod_info::out) is det.

intermod__traverse_cases([], [], yes) --> [].
intermod__traverse_cases([case(F, Goal0) | Cases0],
		[case(F, Goal) | Cases], DoWrite) -->
	intermod__traverse_goal(Goal0, Goal, DoWrite1),
	( { DoWrite1 = yes } ->
		intermod__traverse_cases(Cases0, Cases, DoWrite)
	;
		{ DoWrite = no },
		{ Cases = Cases0 }
	).

	%
	% intermod__add_proc/4 tries to do what ever is necessary to
	% ensure that the specified predicate will be exported,
	% so that it can be called from clauses in the `.opt' file.
	% If it can't, then it returns DoWrite = no, which will
	% prevent the caller from being included in the `.opt' file.
	%
	% If a proc called within an exported proc is local, we need
	% to add a declaration for the called proc to the .opt file.
	% If a proc called within an exported proc is from a different
	% module, we need to include an `:- import_module' declaration
	% to import that module in the `.opt' file.
	%
:- pred intermod__add_proc(pred_id::in, bool::out,
		intermod_info::in, intermod_info::out) is det.

intermod__add_proc(PredId, DoWrite) -->
	intermod_info_get_module_info(ModuleInfo),
	{ module_info_pred_info(ModuleInfo, PredId, PredInfo) },
	{ pred_info_import_status(PredInfo, Status) },
	{ pred_info_procids(PredInfo, ProcIds) },
	{ pred_info_get_markers(PredInfo, Markers) },
	(
		%
		% Calling compiler-generated procedures is fine;
		% we don't need to output declarations for them to
		% the `.opt' file, since they will be recreated every
		% time anyway.
		%
		{ code_util__compiler_generated(PredInfo) }
	->
		{ DoWrite = yes }
	;
		%
		% Don't write the caller to the `.opt' file if it calls
		% a pred without mode or determinism decls, because we'd
		% need to include the mode decls for the callee in the `.opt'
		% file and (since writing the `.opt' file happens before mode
		% inference) we can't do that because we don't know what
		% the modes are.
		%
		% XXX This prevents intermodule optimizations in such cases,
		% which is a pity.
		%
		{
			check_marker(Markers, infer_modes)
		;
			pred_info_procedures(PredInfo, Procs),
			list__member(ProcId, ProcIds),
			map__lookup(Procs, ProcId, ProcInfo),
			proc_info_declared_determinism(ProcInfo, no)
		}
	->
		{ DoWrite = no }
	;
		% Goals which call impure predicates cannot be written
		% due to limitations in mode analysis. The problem is that
		% only head unifications are allowed to be reordered with
		% impure goals.
		% 	
		% e.g
		%	p(A::in, B::in, C::out) :- impure foo(A, B, C).
		% becomes
		% 	p(HeadVar1, HeadVar2, HeadVar3) :-
		%		A = HeadVar1, B = HeadVar2, C = HeadVar3,
		% 		impure foo(A, B, C).
		% 
		% In the clauses written to `.opt' files, the head
		% unifications are already expanded, and are expanded
		% again when the `.opt' file is read in. The `C = HeadVar3'
		% unification cannot be reordered with the impure goal,
		% resulting in a mode error. Fixing this in mode analysis
		% would be tricky.
		%
		% See tests/valid/impure_intermod.m.
		{ pred_info_get_purity(PredInfo, impure) }
	->	
		{ DoWrite = no }
	;
		%
		% Don't write this pred if it is exported to submodules,
		% because we don't know whether or not to write out the
		% pred decl to the .opt file -- if we write it out, you
		% can get spurious "duplicate declaration" errors when
		% compiling the submodules, and if we don't, then you
		% can get spurious "undeclared predicate" errors when
		% compiling other modules which import the parent module.
		%
		% XXX This prevents intermodule optimization in those
		% cases, which is a pity.
		%
		{ Status = exported_to_submodules }
	->
		{ DoWrite = no }
	;
		%
		% If a pred whose code we're going to put in the .opt file
		% calls a predicate which is exported, then we don't
		% need to do anything special.
		%
		{ Status = exported }
	->
		{ DoWrite = yes }
	;
		%
		% Declarations for class methods will be recreated
		% from the class declaration in the `.opt' file.
		% Declarations for local classes are always written
		% to the `.opt' file.
		%
		{ pred_info_get_markers(PredInfo, Markers) },
		{ check_marker(Markers, class_method) }
	->
		{ DoWrite = yes }
	;
		%
		% If a pred whose code we're going to put in the `.opt' file
		% calls a predicate which is local to that module, then
		% we need to put the declaration for the called predicate
		% in the `.opt' file.
		%
		{ Status = local }
	->
		{ DoWrite = yes },
		intermod_info_get_pred_decls(PredDecls0),
		{ set__insert(PredDecls0, PredId, PredDecls) },
		intermod_info_set_pred_decls(PredDecls)
	;
		{ Status = imported(_)
		; Status = opt_imported
		}
	->
		{ DoWrite = yes },
		{ module_info_name(ModuleInfo, ThisModule) },
		{ pred_info_module(PredInfo, PredModule) },
		(
			{ PredModule = ThisModule }
		->
			%
			% This can happen in the case of a local predicate
			% which has been declared as external using a
			% `:- external(Name/Arity)' declaration, e.g.
			% because it is implemented as low-level C code.
			%
			% We treat these the same as local predicates.
			%
			intermod_info_get_pred_decls(PredDecls0),
			{ set__insert(PredDecls0, PredId, PredDecls) },
			intermod_info_set_pred_decls(PredDecls)
		;	
			%
			% imported pred - add import for module
			%
			intermod_info_get_modules(Modules0),
			{ set__insert(Modules0, PredModule, Modules) },
			intermod_info_set_modules(Modules)
		)
	;
		{ error("intermod__add_proc: unexpected status") }
	).

	% Resolve overloading and module qualify everything in a unify_rhs.
:- pred intermod__module_qualify_unify_rhs(prog_var::in, unify_rhs::in,
		unify_rhs::out, bool::out, intermod_info::in,
		intermod_info::out) is det.

intermod__module_qualify_unify_rhs(_, var(Var), var(Var), yes) --> [].

intermod__module_qualify_unify_rhs(_LVar,
		lambda_goal(A,EvalMethod,C,D,E,Modes,G,Goal0),
		lambda_goal(A,EvalMethod,C,D,E,Modes,G,Goal), DoWrite) -->
	( { EvalMethod = (aditi_top_down) } ->
		% XXX Predicates which build this type of lambda expression
		% can't be exported because the importing modules have
		% no way of knowing which Aditi-RL bytecode fragment
		% to use. The best way to handle these is probably to
		% add some sort of lookup table to Aditi.
		{ DoWrite = no },
		{ Goal = Goal0 }
	;
		intermod__traverse_goal(Goal0, Goal, DoWrite)
	).	

	% Fully module-qualify the right-hand-side of a unification.
	% For function calls and higher-order terms, call intermod__add_proc
	% so that the predicate or function will be exported if necessary.
intermod__module_qualify_unify_rhs(LVar, functor(Functor0, Vars),
				functor(Functor, Vars), DoWrite) -->
	intermod_info_get_module_info(ModuleInfo),
	{ module_info_get_predicate_table(ModuleInfo, PredTable) },
	intermod_info_get_tvarset(TVarSet),
	intermod_info_get_var_types(VarTypes),
	(
		% Is it a higher-order function call?
		% (higher-order predicate calls are transformed into
		% higher_order_call goals by make_hlds.m).
		{ Functor0 = cons(unqualified(ApplyName), _) },
		{ ApplyName = "apply"
		; ApplyName = ""
		},
		{ list__length(Vars, ApplyArity) },
		{ ApplyArity >= 1 }
	->
		{ Functor = Functor0 },
		{ DoWrite = yes }
	;
		%
		% Is it a function call?
		%
		{ Functor0 = cons(FuncName, Arity) },
		{ predicate_table_search_func_sym_arity(PredTable,
				FuncName, Arity, PredIds) },
		{ list__append(Vars, [LVar], FuncArgs) },
		{ map__apply_to_list(FuncArgs, VarTypes, FuncArgTypes) },
		{ typecheck__find_matching_pred_id(PredIds, ModuleInfo,
			TVarSet, FuncArgTypes, PredId, QualifiedFuncName) }
	->
		%
		% Yes, it is a function call.
		% Fully module-qualify it.
		% Make sure that the called function will be exported.
		%
		{ Functor = cons(QualifiedFuncName, Arity) },
		intermod__add_proc(PredId, DoWrite)
	;
		%
		% Is this a higher-order predicate or higher-order function
		% term?
		%
		{ Functor0 = cons(PredName, Arity) },
		intermod_info_get_var_types(VarTypes),
		{ map__lookup(VarTypes, LVar, LVarType) },
		{ type_is_higher_order(LVarType, PredOrFunc,
			EvalMethod, PredArgTypes) }
	->
		( { EvalMethod = (aditi_top_down) } ->
			% XXX Predicates which build this type of lambda
			% expression can't be exported because the importing
			% modules have no way of knowing which Aditi-RL
			% bytecode fragment to use. The best way to handle
			% these is probably to add some sort of lookup table
			% to Aditi. 
			{ DoWrite = no },
			{ Functor = Functor0 }
		;
			%
			% Yes, the unification creates a higher-order term.
			% Make sure that the predicate/function is exported.
			%
			{ map__apply_to_list(Vars, VarTypes, Types) },
			{ list__append(Types, PredArgTypes, ArgTypes) },
			{ get_pred_id_and_proc_id(PredName, PredOrFunc,
				TVarSet, ArgTypes, ModuleInfo,
				PredId, _ProcId) },
			intermod__add_proc(PredId, DoWrite),
			%
			% Fully module-qualify it.
			%
			{ unqualify_name(PredName, UnqualPredName) },
			{ predicate_module(ModuleInfo, PredId, Module) },
			{ QualifiedPredName =
				qualified(Module, UnqualPredName) },
			{ Functor = cons(QualifiedPredName, Arity) }
		)
	;
		%
		% Is it a functor symbol for which we can add
		% a module qualifier?
		%
		{ Functor0 = cons(ConsName, ConsArity) },
		{ map__lookup(VarTypes, LVar, VarType) },
		{ type_to_type_id(VarType, TypeId, _) },
		{ TypeId = qualified(TypeModule, _) - _ }
	->
		%
		% Fully module-qualify it
		%
		{ unqualify_name(ConsName, UnqualConsName) },
		{ Functor = cons(qualified(TypeModule, UnqualConsName),
				ConsArity) },
		{ DoWrite = yes }
	;
		% It is a constant of a builtin type.
		% No module qualification needed.
		{ Functor = Functor0 },
		{ DoWrite = yes }
	).

%-----------------------------------------------------------------------------%

:- pred intermod__gather_instances(intermod_info::in,
		intermod_info::out) is det.

intermod__gather_instances -->
	intermod_info_get_module_info(ModuleInfo),
	{ module_info_instances(ModuleInfo, Instances) },
	map__foldl(intermod__gather_instances_2(ModuleInfo), Instances).

:- pred intermod__gather_instances_2(module_info::in, class_id::in,
		list(hlds_instance_defn)::in,
		intermod_info::in, intermod_info::out) is det.

intermod__gather_instances_2(ModuleInfo, ClassId, InstanceDefns) -->
	list__foldl(intermod__gather_instances_3(ModuleInfo, ClassId),
		InstanceDefns).

:- pred intermod__gather_instances_3(module_info::in, class_id::in,
	hlds_instance_defn::in, intermod_info::in, intermod_info::out) is det.
		
intermod__gather_instances_3(ModuleInfo, ClassId, InstanceDefn) -->
	{ InstanceDefn = hlds_instance_defn(Status, B, C, D, Interface0,
				MaybePredProcIds, F, G) },
	(
		%
		% The bodies are always stripped from instance declarations
		% before writing them to `int' files, so the full instance
		% declaration should be written even for exported instances.
		%
		{ status_defined_in_this_module(Status, yes) },

		%
		% See the comments on intermod__add_proc.
		%
		{ Status \= exported_to_submodules }
	->
		=(IntermodInfo0),
		(
			{ Interface0 = concrete(Methods0) },
			{ MaybePredProcIds = yes(PredProcIds) ->
				assoc_list__from_corresponding_lists(
					PredProcIds, Methods0,
					MethodAL0)
			;
				error(
	"intermod__gather_instances_3: method pred_proc_ids not filled in")
			},
			{ list__map(
				intermod__qualify_instance_method(ModuleInfo),
				MethodAL0, MethodAL) },
			{ assoc_list__keys(MethodAL, PredIds) },
			{ assoc_list__values(MethodAL, Methods) },
			list__map_foldl(intermod__add_proc,
				PredIds, DoWriteMethodsList),
			{ bool__and_list(DoWriteMethodsList, DoWriteMethods) },
			(
				{ DoWriteMethods = yes },
				{ Interface = concrete(Methods) }
			;
				{ DoWriteMethods = no },

				%
				% Write an abstract instance declaration
				% if any of the methods cannot be written
				% to the `.opt' file for any reason.
				%
				{ Interface = abstract },

				%
				% Don't write declarations for any of the
				% methods if one can't be written.
				%
				dcg_set(IntermodInfo0)
			)
		;
			{ Interface0 = abstract },
			{ Interface = Interface0 }
		),
		(
			%
			% Don't write an abstract instance declaration
			% if the declaration is already in the `.int' file.
			%
			{
				Interface = abstract
			=>
				status_is_exported(Status, no)
			}
		->
			{ InstanceDefnToWrite = hlds_instance_defn(Status,
					B, C, D, Interface, MaybePredProcIds,
					F, G) },
			intermod_info_get_instances(Instances0),
			intermod_info_set_instances(
				[ClassId - InstanceDefnToWrite | Instances0])
		;
			[]
		)
	;
		[]
	).

	% Resolve overloading of instance methods before writing them
	% to the `.opt' file.
:- pred intermod__qualify_instance_method(module_info::in,
		pair(hlds_class_proc, instance_method)::in,
		pair(pred_id, instance_method)::out) is det.

intermod__qualify_instance_method(ModuleInfo, ClassProcId - InstanceMethod0,
		PredId - InstanceMethod) :-
	ClassProcId = hlds_class_proc(MethodCallPredId, _),
	module_info_pred_info(ModuleInfo, MethodCallPredId,
		MethodCallPredInfo),
	pred_info_arg_types(MethodCallPredInfo, MethodCallTVarSet, _,
		MethodCallArgTypes),
	(
		InstanceMethod0 = func_instance(MethodName,
			InstanceMethodName0, MethodArity, MethodContext),
		module_info_get_predicate_table(ModuleInfo, PredicateTable),
		(
			predicate_table_search_func_sym_arity(PredicateTable,
				InstanceMethodName0, MethodArity, PredIds),
			typecheck__find_matching_pred_id(PredIds, ModuleInfo,
				MethodCallTVarSet, MethodCallArgTypes,
				PredId0, InstanceMethodName)
		->
			PredId = PredId0,
			InstanceMethod = func_instance(MethodName,
				InstanceMethodName, MethodArity, MethodContext)
		;
			error(
		"intermod__qualify_instance_method: undefined function")
		)
	;
		InstanceMethod0 = pred_instance(MethodName,
			InstanceMethodName0, MethodArity, MethodContext),
		typecheck__resolve_pred_overloading(ModuleInfo,
			MethodCallArgTypes, MethodCallTVarSet,
			InstanceMethodName0, InstanceMethodName, PredId),
		InstanceMethod = pred_instance(MethodName,
			InstanceMethodName, MethodArity, MethodContext)
	).

%-----------------------------------------------------------------------------%
	% Output module imports, types, modes, insts and predicates

:- pred intermod__write_intermod_info(intermod_info::in,
				io__state::di, io__state::uo) is det.

intermod__write_intermod_info(IntermodInfo0) -->
	{ intermod_info_get_module_info(ModuleInfo,
		IntermodInfo0, IntermodInfo1) },
	{ module_info_name(ModuleInfo, ModuleName) },
	io__write_string(":- module "),
	mercury_output_bracketed_sym_name(ModuleName),
	io__write_string(".\n"),

	{ intermod_info_get_preds(Preds, IntermodInfo1, IntermodInfo2) },
	{ intermod_info_get_pred_decls(PredDecls,
		IntermodInfo2, IntermodInfo3) },
	{ intermod_info_get_instances(Instances,
		IntermodInfo3, IntermodInfo) },
	(
		%
		% If none of these item types need writing, nothing
		% else needs to be written.
		%
		{ set__empty(Preds) },
		{ set__empty(PredDecls) },
		{ Instances = [] },
		{ module_info_types(ModuleInfo, Types) },
		\+ {
			map__member(Types, _, TypeDefn),
			hlds_data__get_type_defn_status(TypeDefn, Status),
			Status = abstract_exported
		}
	->
		[]	
	;
		intermod__write_intermod_info_2(IntermodInfo)	
	).

:- pred intermod__write_intermod_info_2(intermod_info::in, io__state::di,
		io__state::uo) is det.

intermod__write_intermod_info_2(IntermodInfo) -->
	{ IntermodInfo = info(_, Preds0, PredDecls0, Instances, _, _,
				ModuleInfo, WriteHeader, _, _) },
	{ set__to_sorted_list(Preds0, Preds) }, 
	{ set__to_sorted_list(PredDecls0, PredDecls) },


	{ module_info_get_imported_module_specifiers(ModuleInfo, Modules0) },
	{ set__to_sorted_list(Modules0, Modules) },
	( { Modules \= [] } ->
		% XXX this could be reduced to the set that is
		% actually needed by the items being written.
		io__write_string(":- use_module "),
		intermod__write_modules(Modules)
	;
		[]
	),

	intermod__write_types(ModuleInfo),
	intermod__write_insts(ModuleInfo),
	intermod__write_modes(ModuleInfo),
	intermod__write_classes(ModuleInfo),
	intermod__write_instances(Instances),

	% Disable verbose dumping of clauses.
	globals__io_lookup_string_option(dump_hlds_options, VerboseDump),
	globals__io_set_option(dump_hlds_options, string("")),
	( { WriteHeader = yes } ->
		{ module_info_get_c_header(ModuleInfo, CHeader) },
		intermod__write_c_header(CHeader)
	;
		[]
	),
	intermod__write_pred_decls(ModuleInfo, PredDecls),
	intermod__write_preds(ModuleInfo, Preds),
	globals__io_set_option(dump_hlds_options, string(VerboseDump)).

:- pred intermod__write_modules(list(module_name)::in,
			io__state::di, io__state::uo) is det.

intermod__write_modules([]) --> [].
intermod__write_modules([Module | Rest]) -->
	mercury_output_bracketed_sym_name(Module),
	(
		{ Rest = [] },
		io__write_string(".\n")
	;
		{ Rest = [_ | _] },
		io__write_string(", "),
		intermod__write_modules(Rest)
	).

:- pred intermod__write_c_header(list(c_header_code)::in,
				io__state::di, io__state::uo) is det.

intermod__write_c_header([]) --> [].
intermod__write_c_header([Header - _ | Headers]) -->
        intermod__write_c_header(Headers),
        mercury_output_pragma_c_header(Header).

:- pred intermod__write_types(module_info::in,
		io__state::di, io__state::uo) is det.

intermod__write_types(ModuleInfo) -->
	{ module_info_name(ModuleInfo, ModuleName) },
	{ module_info_types(ModuleInfo, Types) },
	map__foldl(intermod__write_type(ModuleName), Types).

:- pred intermod__write_type(module_name::in, type_id::in,
		hlds_type_defn::in, io__state::di, io__state::uo) is det.

intermod__write_type(ModuleName, TypeId, TypeDefn) -->
	{ hlds_data__get_type_defn_status(TypeDefn, ImportStatus) },
	{ TypeId = Name - _Arity },
	(
		{ Name = qualified(ModuleName, _) },
		{ ImportStatus = local
		; ImportStatus = abstract_exported
		}
	->
		{ hlds_data__get_type_defn_tvarset(TypeDefn, VarSet) },
		{ hlds_data__get_type_defn_tparams(TypeDefn, Args) },
		{ hlds_data__get_type_defn_body(TypeDefn, Body) },
		{ hlds_data__get_type_defn_context(TypeDefn, Context) },
		(
			{ Body = du_type(Ctors, _, _, MaybeEqualityPred) },
			mercury_output_type_defn(VarSet,
				du_type(Name, Args, Ctors,
					MaybeEqualityPred),
				Context)
		;
			{ Body = uu_type(_) },
			{ error("uu types not implemented") }
		;
			{ Body = eqv_type(EqvType) },
			mercury_output_type_defn(VarSet,
				eqv_type(Name, Args, EqvType), Context)
		;
			{ Body = abstract_type },
			mercury_output_type_defn(VarSet,
				abstract_type(Name, Args), Context)
		)
	;
		[]
	).

:- pred intermod__write_modes(module_info::in,
		io__state::di, io__state::uo) is det.

intermod__write_modes(ModuleInfo) -->
	{ module_info_name(ModuleInfo, ModuleName) },
	{ module_info_modes(ModuleInfo, Modes) },
	{ mode_table_get_mode_defns(Modes, ModeDefns) },
	map__foldl(intermod__write_mode(ModuleName), ModeDefns).

:- pred intermod__write_mode(module_name::in, mode_id::in, hlds_mode_defn::in,
		io__state::di, io__state::uo) is det.

intermod__write_mode(ModuleName, ModeId, ModeDefn) -->
	{ ModeId = SymName - _Arity },
	{ ModeDefn = hlds_mode_defn(Varset, Args, eqv_mode(Mode),
			_, Context, ImportStatus) },
	(
		{ SymName = qualified(ModuleName, _) },
		{ ImportStatus = local }
	->
		mercury_output_mode_defn(
			Varset,
			eqv_mode(SymName, Args, Mode),
			Context
		)
	;
		[]
	).

:- pred intermod__write_insts(module_info::in,
		io__state::di, io__state::uo) is det.

intermod__write_insts(ModuleInfo) -->
	{ module_info_name(ModuleInfo, ModuleName) },
	{ module_info_insts(ModuleInfo, Insts) },
	{ inst_table_get_user_insts(Insts, UserInsts) },
	{ user_inst_table_get_inst_defns(UserInsts, InstDefns) },
	map__foldl(intermod__write_inst(ModuleName), InstDefns).

:- pred intermod__write_inst(module_name::in, inst_id::in, hlds_inst_defn::in, 
		io__state::di, io__state::uo) is det.

intermod__write_inst(ModuleName, InstId, InstDefn) -->
	{ InstId = SymName - _Arity },
	{ InstDefn = hlds_inst_defn(Varset, Args, Body, _,
			Context, ImportStatus) },
	(
		{ SymName = qualified(ModuleName, _) },
		{ ImportStatus = local }
	->
		(
			{ Body = eqv_inst(Inst2) },
			mercury_output_inst_defn(
					Varset,
					eqv_inst(SymName, Args, Inst2),
					Context
			)
		;
			{ Body = abstract_inst },
			mercury_output_inst_defn(
					Varset,
					abstract_inst(SymName, Args),
					Context
			)
		)
	;
		[]
	).

:- pred intermod__write_classes(module_info::in,
		io__state::di, io__state::uo) is det.

intermod__write_classes(ModuleInfo) -->
	{ module_info_name(ModuleInfo, ModuleName) },
	{ module_info_classes(ModuleInfo, Classes) },
	map__foldl(intermod__write_class(ModuleName), Classes).

:- pred intermod__write_class(module_name::in, class_id::in,
		hlds_class_defn::in, io__state::di, io__state::uo) is det.

intermod__write_class(ModuleName, ClassId, ClassDefn) -->
	{ ClassDefn = hlds_class_defn(ImportStatus, Constraints,
			TVars, Interface, _HLDSClassInterface,
			TVarSet, Context) },
	{ ClassId = class_id(QualifiedClassName, _) },
	(
		{ QualifiedClassName = qualified(ModuleName, _) },
		{ ImportStatus = local }
	->
		{ Item = typeclass(Constraints, QualifiedClassName, TVars,
				Interface, TVarSet) },
		mercury_output_item(Item, Context)
	;
		[]
	).

:- pred intermod__write_instances(assoc_list(class_id, hlds_instance_defn)::in,
		io__state::di, io__state::uo) is det.

intermod__write_instances(Instances) -->
	list__foldl(intermod__write_instance, Instances).

:- pred intermod__write_instance(pair(class_id, hlds_instance_defn)::in,
		io__state::di, io__state::uo) is det.

intermod__write_instance(ClassId - InstanceDefn) -->
	{ InstanceDefn = hlds_instance_defn(_, Context, Constraints,
				Types, Body, _, TVarSet, _) },
	{ ClassId = class_id(ClassName, _) },
	{ Item = instance(Constraints, ClassName, Types, Body, TVarSet) },
	mercury_output_item(Item, Context).

	% We need to write all the declarations for local predicates so
	% the procedure labels for the C code are calculated correctly.
:- pred intermod__write_pred_decls(module_info::in, list(pred_id)::in,
			io__state::di, io__state::uo) is det.

intermod__write_pred_decls(_, []) --> [].
intermod__write_pred_decls(ModuleInfo, [PredId | PredIds]) -->
	{ module_info_pred_info(ModuleInfo, PredId, PredInfo) },
	{ pred_info_module(PredInfo, Module) },
	{ pred_info_name(PredInfo, Name) },
	{ pred_info_arg_types(PredInfo, TVarSet, ExistQVars, ArgTypes) },
	{ pred_info_context(PredInfo, Context) },
	{ pred_info_get_purity(PredInfo, Purity) },
	{ pred_info_get_is_pred_or_func(PredInfo, PredOrFunc) },
	{ pred_info_get_class_context(PredInfo, ClassContext) },
	(
		{ PredOrFunc = predicate },
		mercury_output_pred_type(TVarSet, ExistQVars,
			qualified(Module, Name), ArgTypes, no, Purity,
			ClassContext, Context)
	;
		{ PredOrFunc = function },
		{ pred_args_to_func_args(ArgTypes, FuncArgTypes, FuncRetType) },
		mercury_output_func_type(TVarSet, ExistQVars,
			qualified(Module, Name), FuncArgTypes,
			FuncRetType, no, Purity, ClassContext, Context)
	),
	{ pred_info_procedures(PredInfo, Procs) },
	{ pred_info_procids(PredInfo, ProcIds) },
		% Make sure the mode declarations go out in the same
		% order they came in, so that the all the modes get the
		% same proc_id in the importing modules.
	{ CompareProcId =
		 lambda([ProcId1::in, ProcId2::in, Result::out] is det, (
			proc_id_to_int(ProcId1, ProcInt1),
			proc_id_to_int(ProcId2, ProcInt2),
			compare(Result, ProcInt1, ProcInt2)
		)) },
	{ list__sort(CompareProcId, ProcIds, SortedProcIds) },
	intermod__write_pred_modes(Procs, qualified(Module, Name),
					PredOrFunc, SortedProcIds),
	intermod__write_pragmas(PredInfo),
	intermod__write_type_spec_pragmas(ModuleInfo, PredId),
	intermod__write_pred_decls(ModuleInfo, PredIds).

:- pred intermod__write_pred_modes(map(proc_id, proc_info)::in, 
		sym_name::in, pred_or_func::in, list(proc_id)::in,
		io__state::di, io__state::uo) is det.

intermod__write_pred_modes(_, _, _, []) --> [].
intermod__write_pred_modes(Procs, SymName, PredOrFunc, [ProcId | ProcIds]) -->
	{ map__lookup(Procs, ProcId, ProcInfo) },
	{ proc_info_maybe_declared_argmodes(ProcInfo, MaybeArgModes) },
	{ proc_info_declared_determinism(ProcInfo, MaybeDetism) },
	{ MaybeArgModes = yes(ArgModes0), MaybeDetism = yes(Detism0) ->
		ArgModes = ArgModes0,
		Detism = Detism0
	;
		error("intermod__write_pred_modes: attempt to write undeclared mode")
	},
	{ proc_info_context(ProcInfo, Context) },
	{ varset__init(Varset) },
	(
		{ PredOrFunc = function },
		{ pred_args_to_func_args(ArgModes, FuncArgModes, FuncRetMode) },
		mercury_output_func_mode_decl(Varset, SymName,
			FuncArgModes, FuncRetMode,
			yes(Detism), Context)
	;
		{ PredOrFunc = predicate },
		mercury_output_pred_mode_decl(Varset, SymName,
				ArgModes, yes(Detism), Context)
	),
	intermod__write_pred_modes(Procs, SymName, PredOrFunc, ProcIds).	

:- pred intermod__write_preds(module_info::in, list(pred_id)::in,
				io__state::di, io__state::uo) is det.

intermod__write_preds(_, []) --> [].
intermod__write_preds(ModuleInfo, [PredId | PredIds]) -->
	{ module_info_pred_info(ModuleInfo, PredId, PredInfo) },
	{ pred_info_module(PredInfo, Module) },
	{ pred_info_name(PredInfo, Name) },
	{ SymName = qualified(Module, Name) },
	{ pred_info_get_is_pred_or_func(PredInfo, PredOrFunc) },
	intermod__write_pragmas(PredInfo),
	% The type specialization pragmas for exported preds should
	% already be in the interface file.

	{ pred_info_clauses_info(PredInfo, ClausesInfo) },
	{ clauses_info_varset(ClausesInfo, VarSet) },
	{ clauses_info_headvars(ClausesInfo, HeadVars) },
	{ clauses_info_clauses(ClausesInfo, Clauses) },

		% handle pragma c_code(...) separately
	( { pred_info_get_goal_type(PredInfo, pragmas) } ->
		{ pred_info_procedures(PredInfo, Procs) },
		intermod__write_c_code(SymName, PredOrFunc, HeadVars, VarSet,
						Clauses, Procs)
	;
		{ pred_info_get_goal_type(PredInfo, assertion) }
	->
		(
			{ Clauses = [Clause] }
		->
			hlds_out__write_assertion(0, ModuleInfo, PredId,
					VarSet, no, HeadVars, PredOrFunc,
					Clause, no)
		;
			{ error("intermod__write_preds: assertion not a single clause.") }
		)
	;
		% { pred_info_typevarset(PredInfo, TVarSet) },
		list__foldl(intermod__write_clause(ModuleInfo, PredId, VarSet,
			HeadVars, PredOrFunc), Clauses)
	),
	intermod__write_preds(ModuleInfo, PredIds).

:- pred intermod__write_clause(module_info::in, pred_id::in, prog_varset::in,
		list(prog_var)::in, pred_or_func::in, clause::in,
		io__state::di, io__state::uo) is det.

intermod__write_clause(ModuleInfo, PredId, VarSet, HeadVars,
		PredOrFunc, Clause0) -->
	{ strip_headvar_unifications(HeadVars, Clause0,
		ClauseHeadVars, Clause) },
	hlds_out__write_clause(1, ModuleInfo, PredId, VarSet, no,
		ClauseHeadVars, PredOrFunc, Clause, no).

	% Strip the `Headvar__n = Term' unifications from each clause,
	% except if the `Term' is a lambda expression.
	%
	% At least two problems occur if this is not done:
	% - in some cases where nested unique modes were accepted by
	% 	mode analysis, the extra aliasing added by the extra level
	%	of headvar unifications caused mode analysis to report
	% 	an error (ground expected unique), when analysing the
	% 	clauses read in from `.opt' files.
	% - only HeadVar unifications may be reordered with impure goals,
	%	so a mode error results for the second level of headvar
	% 	unifications added when the clauses are read in again from
	%	the `.opt' file. Clauses containing impure goals are not
	%	written to the `.opt' file for this reason.
:- pred strip_headvar_unifications(list(prog_var)::in,
		clause::in, list(prog_term)::out, clause::out) is det.

strip_headvar_unifications(HeadVars, clause(ProcIds, Goal0, Context),
		HeadTerms, clause(ProcIds, Goal, Context)) :-
	Goal0 = _ - GoalInfo0,
	goal_to_conj_list(Goal0, Goals0),
	map__init(HeadVarMap0),
	(
		strip_headvar_unifications_from_goal_list(Goals0, HeadVars,
			[], Goals, HeadVarMap0, HeadVarMap)
	->
		list__map(
		    (pred(HeadVar0::in, HeadTerm::out) is det :-
			( map__search(HeadVarMap, HeadVar0, HeadTerm0) ->
				HeadTerm = HeadTerm0
			;
				HeadTerm = term__variable(HeadVar0)
			)
		    ), HeadVars, HeadTerms),
		conj_list_to_goal(Goals, GoalInfo0, Goal)
	;
		term__var_list_to_term_list(HeadVars, HeadTerms),
		Goal = Goal0
	).

:- pred strip_headvar_unifications_from_goal_list(list(hlds_goal)::in,
		list(prog_var)::in, list(hlds_goal)::in, list(hlds_goal)::out,
		map(prog_var, prog_term)::in,
		map(prog_var, prog_term)::out) is semidet.

strip_headvar_unifications_from_goal_list([], _, RevGoals, Goals,
		HeadVarMap, HeadVarMap) :-
	list__reverse(RevGoals, Goals).
strip_headvar_unifications_from_goal_list([Goal | Goals0], HeadVars,
		RevGoals0, Goals, HeadVarMap0, HeadVarMap) :-
	(
		Goal = unify(LHSVar, RHS, _, _, _) - _,
		list__member(LHSVar, HeadVars),
		(
			RHS = var(RHSVar),
			RHSTerm = term__variable(RHSVar)
		;
			RHS = functor(ConsId, Args),
			term__context_init(Context),
			(
				ConsId = int_const(Int),
				RHSTerm = term__functor(term__integer(Int),
						[], Context)
			;
				ConsId = float_const(Float),
				RHSTerm = term__functor(term__float(Float),
						[], Context)
			;
				ConsId = string_const(String),
				RHSTerm = term__functor(term__string(String),
						[], Context)
			;
				ConsId = cons(SymName, _),
				term__var_list_to_term_list(Args, ArgTerms),
				construct_qualified_term(SymName, ArgTerms,
					RHSTerm)
			)
		)
	->
		% Don't strip the headvar unifications if one of the
		% headvars appears twice. This should probably never happen.
		map__insert(HeadVarMap0, LHSVar, RHSTerm, HeadVarMap1),
		RevGoals1 = RevGoals0
	;
		HeadVarMap1 = HeadVarMap0,
		RevGoals1 = [Goal | RevGoals0]
	),
	strip_headvar_unifications_from_goal_list(Goals0, HeadVars,
		RevGoals1, Goals, HeadVarMap1, HeadVarMap).

:- pred intermod__write_pragmas(pred_info::in,
		io__state::di, io__state::uo) is det.

intermod__write_pragmas(PredInfo) -->
	{ pred_info_module(PredInfo, Module) },
	{ pred_info_name(PredInfo, Name) },
	{ pred_info_arity(PredInfo, Arity) },
	{ SymName = qualified(Module, Name) },
	{ pred_info_get_markers(PredInfo, Markers) },
	{ markers_to_marker_list(Markers, MarkerList) },
	{ pred_info_get_is_pred_or_func(PredInfo, PredOrFunc) },
	intermod__write_pragmas(SymName, Arity, MarkerList, PredOrFunc).

:- pred intermod__write_pragmas(sym_name::in, int::in, list(marker)::in,
		pred_or_func::in, io__state::di, io__state::uo) is det.

intermod__write_pragmas(_, _, [], _) --> [].
intermod__write_pragmas(SymName, Arity, [Marker | Markers], PredOrFunc) -->
	{ intermod__should_output_marker(Marker, ShouldOutput) },
	( { ShouldOutput = yes } ->
		{ hlds_out__marker_name(Marker, Name) },
		mercury_output_pragma_decl(SymName, Arity, PredOrFunc, Name)
	;
		[]
	),
	intermod__write_pragmas(SymName, Arity, Markers, PredOrFunc).

:- pred intermod__write_type_spec_pragmas(module_info::in, pred_id::in,
		io__state::di, io__state::uo) is det.

intermod__write_type_spec_pragmas(ModuleInfo, PredId) -->
	{ module_info_type_spec_info(ModuleInfo,
		type_spec_info(_, _, _, PragmaMap)) },
	( { multi_map__search(PragmaMap, PredId, TypeSpecPragmas) } ->
		{ term__context_init(Context) },
		list__foldl(lambda([Pragma::in, IO0::di, IO::uo] is det, (
			mercury_output_item(pragma(Pragma), Context, IO0, IO)
		)), TypeSpecPragmas)
	;
		[]
	).

	% Is a pragma declaration required in the `.opt' file for
	% a predicate with the given marker.
:- pred intermod__should_output_marker(marker::in, bool::out) is det.

	% Since the inferred declarations are output, these
	% don't need to be done in the importing module.
intermod__should_output_marker(infer_type, no).
intermod__should_output_marker(infer_modes, no).
	% Purity is output as part of the pred/func decl.
intermod__should_output_marker((impure), no).
intermod__should_output_marker((semipure), no).
	% There is no pragma required for generated class methods.
intermod__should_output_marker(class_method, no).
intermod__should_output_marker(class_instance_method, no).
	% The warning for calls to local obsolete predicates should appear
	% once in the defining module, not in importing modules.
intermod__should_output_marker(obsolete, no).
intermod__should_output_marker(inline, yes).
intermod__should_output_marker(no_inline, yes).
intermod__should_output_marker(dnf, yes).
intermod__should_output_marker(aditi, yes).
intermod__should_output_marker((aditi_top_down), _) :-
	% We don't write out code for predicates which depend on
	% predicates with this marker: see the comments in
	% intermod__module_qualify_unify_rhs.
	error("intermod__should_output_marker: aditi_top_down").
intermod__should_output_marker(base_relation, yes).
intermod__should_output_marker(aditi_memo, yes).
intermod__should_output_marker(aditi_no_memo, yes).
intermod__should_output_marker(naive, yes).
intermod__should_output_marker(psn, yes).
intermod__should_output_marker(supp_magic, yes).
intermod__should_output_marker(context, yes).
intermod__should_output_marker(promised_pure, yes).
intermod__should_output_marker(terminates, yes).
intermod__should_output_marker(does_not_terminate, yes).
	% Termination should only be checked in the defining module.
intermod__should_output_marker(check_termination, no).
intermod__should_output_marker(generate_inline, _) :-
	% This marker should only occur after the magic sets transformation.
	error("intermod__should_output_marker: generate_inline").

	% Some pretty kludgy stuff to get c code written correctly.
:- pred intermod__write_c_code(sym_name::in, pred_or_func::in, 
	list(prog_var)::in, prog_varset::in,
	list(clause)::in, proc_table::in, io__state::di, io__state::uo) is det.

intermod__write_c_code(_, _, _, _, [], _) --> [].
intermod__write_c_code(SymName, PredOrFunc, HeadVars, Varset, 
		[Clause | Clauses], Procs) -->
	{ Clause = clause(ProcIds, Goal, _) },
	(
		(
			% Pull the C code out of the goal.
			{ Goal = conj(Goals) - _ },
			{ list__filter(
				lambda([X::in] is semidet, (
					X = pragma_c_code(_,_,_,_,_,_,_) - _
				)),
				Goals, [CCodeGoal]) },
			{ CCodeGoal = pragma_c_code(Attributes,
				_, _, Vars, Names, _, PragmaCode) - _ }
		;
			{ Goal = pragma_c_code(Attributes,
				_, _, Vars, Names, _, PragmaCode) - _ }
		)
	->	
		intermod__write_c_clauses(Procs, ProcIds, PredOrFunc,
			PragmaCode, Attributes, Vars, Varset, Names,
			SymName)
	;
		{ error("intermod__write_c_code called with non c_code goal") }
	),
	intermod__write_c_code(SymName, PredOrFunc, HeadVars, Varset, 
				Clauses, Procs).

:- pred intermod__write_c_clauses(proc_table::in, list(proc_id)::in, 
		pred_or_func::in, pragma_c_code_impl::in,
		pragma_c_code_attributes::in, list(prog_var)::in,
		prog_varset::in, list(maybe(pair(string, mode)))::in,
		sym_name::in, io__state::di, io__state::uo) is det.

intermod__write_c_clauses(_, [], _, _, _, _, _, _, _) --> [].
intermod__write_c_clauses(Procs, [ProcId | ProcIds], PredOrFunc,
		PragmaImpl, Attributes, Vars, Varset0, Names, SymName) -->
	{ map__lookup(Procs, ProcId, ProcInfo) },
	{ proc_info_maybe_declared_argmodes(ProcInfo, MaybeArgModes) },
	( { MaybeArgModes = yes(ArgModes) } ->
		{ get_pragma_c_code_vars(Vars, Names, Varset0, ArgModes,
			Varset, PragmaVars) },
		mercury_output_pragma_c_code(Attributes, SymName,
			PredOrFunc, PragmaVars, Varset, PragmaImpl),
		intermod__write_c_clauses(Procs, ProcIds, PredOrFunc,
			PragmaImpl, Attributes, Vars, Varset, Names,
			SymName)
	;
		{ error("intermod__write_c_clauses: no mode declaration") }
	).

:- pred get_pragma_c_code_vars(list(prog_var)::in,
		list(maybe(pair(string, mode)))::in, prog_varset::in,
		list(mode)::in, prog_varset::out, list(pragma_var)::out) is det.

get_pragma_c_code_vars(HeadVars, VarNames, VarSet0, ArgModes,
		VarSet, PragmaVars) :- 
	(
		HeadVars = [Var | Vars],
		VarNames = [Maybe_NameAndMode | Names],
		ArgModes = [Mode | Modes]
	->
		(
			Maybe_NameAndMode = no,
			Name = "_"
		;
			Maybe_NameAndMode = yes(Name - _Mode2)
		),
		PragmaVar = pragma_var(Var, Name, Mode),
		varset__name_var(VarSet0, Var, Name, VarSet1),
		get_pragma_c_code_vars(Vars, Names, VarSet1, Modes,
			VarSet, PragmaVars1),
		PragmaVars = [PragmaVar | PragmaVars1] 
	;
		HeadVars = [],
		VarNames = [],
		ArgModes = []
	->
		PragmaVars = [],
		VarSet = VarSet0
	;
		error("intermod:get_pragma_c_code_vars")
	).

%-----------------------------------------------------------------------------%
	% Access predicates.

:- pred intermod_info_get_modules(set(module_name)::out, intermod_info::in,
			intermod_info::out) is det.
:- pred intermod_info_get_preds(set(pred_id)::out, 
			intermod_info::in, intermod_info::out) is det.
:- pred intermod_info_get_pred_decls(set(pred_id)::out, 
			intermod_info::in, intermod_info::out) is det.
:- pred intermod_info_get_instances(
			assoc_list(class_id, hlds_instance_defn)::out, 
			intermod_info::in, intermod_info::out) is det.
%:- pred intermod_info_get_modes(set(mode_id)::out, 
%			intermod_info::in, intermod_info::out) is det.
%:- pred intermod_info_get_insts(set(inst_id)::out, 
%			intermod_info::in, intermod_info::out) is det.
:- pred intermod_info_get_module_info(module_info::out,
			intermod_info::in, intermod_info::out) is det.
:- pred intermod_info_get_write_c_header(bool::out,
			intermod_info::in, intermod_info::out) is det.
:- pred intermod_info_get_var_types(map(prog_var, type)::out,
			intermod_info::in, intermod_info::out) is det.
:- pred intermod_info_get_tvarset(tvarset::out, intermod_info::in,
			intermod_info::out) is det.

intermod_info_get_modules(Modules)	--> =(info(Modules,_,_,_,_,_,_,_,_,_)). 
intermod_info_get_preds(Procs)		--> =(info(_,Procs,_,_,_,_,_,_,_,_)).
intermod_info_get_pred_decls(ProcDecls) -->
					=(info(_,_,ProcDecls,_,_,_,_,_,_,_)).
intermod_info_get_instances(Instances) -->
		=(info(_,_,_,Instances,_,_,_,_,_,_)).
%intermod_info_get_modes(Modes)		--> =(info(_,_,_,_,Modes,_,_,_,_,_)).
%intermod_info_get_insts(Insts)		--> =(info(_,_,_,_,_,Insts,_,_,_,_)).
intermod_info_get_module_info(Module)	--> =(info(_,_,_,_,_,_,Module,_,_,_)).
intermod_info_get_write_c_header(Write)	--> =(info(_,_,_,_,_,_,_,Write,_,_)).
intermod_info_get_var_types(VarTypes)	--> =(info(_,_,_,_,_,_,_,_,VarTypes,_)).
intermod_info_get_tvarset(TVarSet)	--> =(info(_,_,_,_,_,_,_,_,_,TVarSet)).

:- pred intermod_info_set_modules(set(module_name)::in,
			intermod_info::in, intermod_info::out) is det.
:- pred intermod_info_set_preds(set(pred_id)::in, 
			intermod_info::in, intermod_info::out) is det.
:- pred intermod_info_set_pred_decls(set(pred_id)::in, 
			intermod_info::in, intermod_info::out) is det.
:- pred intermod_info_set_instances(
			assoc_list(class_id, hlds_instance_defn)::in, 
			intermod_info::in, intermod_info::out) is det.
%:- pred intermod_info_set_modes(set(mode_id)::in, 
%			intermod_info::in, intermod_info::out) is det.
%:- pred intermod_info_set_insts(set(inst_id)::in, 
%			intermod_info::in, intermod_info::out) is det.
:- pred intermod_info_set_module_info(module_info::in,
			intermod_info::in, intermod_info::out) is det.
:- pred intermod_info_set_write_header(intermod_info::in,
			intermod_info::out) is det.
:- pred intermod_info_set_var_types(map(prog_var, type)::in, intermod_info::in, 
			intermod_info::out) is det.
:- pred intermod_info_set_tvarset(tvarset::in, intermod_info::in,
			intermod_info::out) is det.

intermod_info_set_modules(Modules, info(_,B,C,D,E,F,G,H,I,J),
				info(Modules, B,C,D,E,F,G,H,I,J)).

intermod_info_set_preds(Procs, info(A,_,C,D,E,F,G,H,I,J),
				info(A, Procs, C,D,E,F,G,H,I,J)).

intermod_info_set_pred_decls(ProcDecls, info(A,B,_,D,E,F,G,H,I,J),
				info(A,B, ProcDecls, D,E,F,G,H,I,J)).

intermod_info_set_instances(Instances, info(A,B,C,_,E,F,G,H,I,J),
				info(A,B,C, Instances, E,F,G,H,I,J)).

%intermod_info_set_modes(Modes, info(A,B,C,D,_,F,G,H,I,J),
%				info(A,B,C,D, Modes, F,G,H,I,J)).
%
%intermod_info_set_insts(Insts, info(A,B,C,D,E,_,G,H,I,J),
%				info(A,B,C,D,E, Insts, G,H,I,J)).

intermod_info_set_module_info(ModuleInfo, info(A,B,C,D,E,F,_,H,I,J),
				info(A,B,C,D,E,F, ModuleInfo, H,I,J)).

intermod_info_set_write_header(info(A,B,C,D,E,F,G,_,I,J),
				 info(A,B,C,D,E,F,G, yes,I,J)).

intermod_info_set_var_types(VarTypes, info(A,B,C,D,E,F,G,H,_,J),
				info(A,B,C,D,E,F,G,H,VarTypes,J)).

intermod_info_set_tvarset(TVarSet, info(A,B,C,D,E,F,G,H,I,_),
				info(A,B,C,D,E,F,G,H,I, TVarSet)).

%-----------------------------------------------------------------------------%

	% Make sure the labels of local preds needed by predicates in 
	% the .opt file are exported, and inhibit dead proc elimination
	% on those preds.
intermod__adjust_pred_import_status(Module0, Module, IO0, IO) :-
	globals__io_lookup_bool_option(very_verbose, VVerbose, IO0, IO1),
	maybe_write_string(VVerbose, 
		"% Adjusting import status of predicates in the `.opt' file...",
		IO1, IO2),

	init_intermod_info(Module0, Info0),
	module_info_predids(Module0, PredIds),
	module_info_globals(Module0, Globals),
	globals__lookup_int_option(Globals, intermod_inline_simple_threshold, 
			Threshold),
	globals__lookup_bool_option(Globals, deforestation, Deforestation),
	globals__lookup_int_option(Globals, higher_order_size_limit,
		HigherOrderSizeLimit),
	intermod__gather_preds(PredIds, yes, Threshold, HigherOrderSizeLimit,
		Deforestation, Info0, Info),
	do_adjust_pred_import_status(Info, Globals, Module0, Module),
	maybe_write_string(VVerbose, " done\n", IO2, IO).

:- pred do_adjust_pred_import_status(intermod_info::in, globals::in,
		module_info::in, module_info::out) is det.

do_adjust_pred_import_status(Info, Globals, ModuleInfo0, ModuleInfo) :-
	intermod_info_get_pred_decls(PredDecls0, Info, _),
	set__to_sorted_list(PredDecls0, PredDecls),
	set_list_of_preds_exported(PredDecls, ModuleInfo0, ModuleInfo1),
	adjust_type_status(Globals, ModuleInfo1, ModuleInfo2),
	adjust_class_status(ModuleInfo2, ModuleInfo3),
	adjust_instance_status(ModuleInfo3, ModuleInfo).

:- pred adjust_type_status(globals::in,
		module_info::in, module_info::out) is det.

adjust_type_status(Globals, ModuleInfo0, ModuleInfo) :-
	module_info_types(ModuleInfo0, Types0),
	map__to_assoc_list(Types0, TypesAL0),
	list__map_foldl(adjust_type_status_2(Globals), TypesAL0, TypesAL,
		ModuleInfo0, ModuleInfo1),
	map__from_assoc_list(TypesAL, Types),
	module_info_set_types(ModuleInfo1, Types, ModuleInfo).

:- pred adjust_type_status_2(globals::in, pair(type_id, hlds_type_defn)::in,
		pair(type_id, hlds_type_defn)::out,
		module_info::in, module_info::out) is det.

adjust_type_status_2(Globals, TypeId - TypeDefn0, TypeId - TypeDefn,
		ModuleInfo0, ModuleInfo) :-
	hlds_data__get_type_defn_status(TypeDefn0, Status),
	(
		module_info_name(ModuleInfo0, ModuleName),
		TypeId = qualified(ModuleName, _) - _,
		( Status = local
		; Status = abstract_exported
		)
	->
		hlds_data__set_type_defn_status(TypeDefn0, exported, TypeDefn),
		fixup_special_preds(TypeId, Globals, ModuleInfo0, ModuleInfo)
	;
		ModuleInfo = ModuleInfo0,
		TypeDefn = TypeDefn0
	).

:- pred fixup_special_preds((type_id)::in, globals::in,
		module_info::in, module_info::out) is det.

fixup_special_preds(TypeId, Globals, ModuleInfo0, ModuleInfo) :-
	special_pred_list(Globals, SpecialPredList),
	module_info_get_special_pred_map(ModuleInfo0, SpecPredMap),
	list__map((pred(SpecPredId::in, PredId::out) is det :-
			map__lookup(SpecPredMap, SpecPredId - TypeId, PredId)
		), SpecialPredList, PredIds),
	set_list_of_preds_exported(PredIds, ModuleInfo0, ModuleInfo).

:- pred adjust_class_status(module_info::in, module_info::out) is det.

adjust_class_status(ModuleInfo0, ModuleInfo) :-
	module_info_name(ModuleInfo0, ModuleName),
	module_info_classes(ModuleInfo0, Classes0),
	map__to_assoc_list(Classes0, ClassAL0),
	list__map_foldl(adjust_class_status_2(ModuleName), ClassAL0, ClassAL,
		ModuleInfo0, ModuleInfo1),
	map__from_assoc_list(ClassAL, Classes),
	module_info_set_classes(ModuleInfo1, Classes, ModuleInfo).

:- pred adjust_class_status_2(module_name::in,
		pair(class_id, hlds_class_defn)::in,
		pair(class_id, hlds_class_defn)::out,
		module_info::in, module_info::out) is det.

adjust_class_status_2(ModuleName, ClassId - ClassDefn0, ClassId - ClassDefn,
			ModuleInfo0, ModuleInfo) :-
	(
		ClassId = class_id(qualified(ModuleName, _), _),
		ClassDefn0 = hlds_class_defn(Status0, Constraints, TVars,
				Interface, HLDSClassInterface,
				TVarSet, Context),	
		Status0 \= exported
	->
		ClassDefn = hlds_class_defn(exported, Constraints, TVars,
				Interface, HLDSClassInterface,
				TVarSet, Context),
		class_procs_to_pred_ids(HLDSClassInterface, PredIds),
		set_list_of_preds_exported(PredIds, ModuleInfo0, ModuleInfo)
	;
		ClassDefn = ClassDefn0,
		ModuleInfo = ModuleInfo0
	).

:- pred class_procs_to_pred_ids(list(hlds_class_proc)::in,
		list(pred_id)::out) is det.

class_procs_to_pred_ids(ClassProcs, PredIds) :-
	list__map(
		(pred(ClassProc::in, PredId::out) is det :-
			ClassProc = hlds_class_proc(PredId, _)
		),
		ClassProcs, PredIds0),
	list__sort_and_remove_dups(PredIds0, PredIds).

:- pred adjust_instance_status(module_info::in, module_info::out) is det.

adjust_instance_status(ModuleInfo0, ModuleInfo) :-
	module_info_instances(ModuleInfo0, Instances0),
	map__to_assoc_list(Instances0, InstanceAL0),
	list__map_foldl(adjust_instance_status_2, InstanceAL0, InstanceAL,
		ModuleInfo0, ModuleInfo1),
	map__from_assoc_list(InstanceAL, Instances),
	module_info_set_instances(ModuleInfo1, Instances, ModuleInfo).

:- pred adjust_instance_status_2(pair(class_id, list(hlds_instance_defn))::in,
		pair(class_id, list(hlds_instance_defn))::out,
		module_info::in, module_info::out) is det.

adjust_instance_status_2(ClassId - InstanceList0, ClassId - InstanceList,
		ModuleInfo0, ModuleInfo) :-
	list__map_foldl(adjust_instance_status_3, InstanceList0, InstanceList,
		ModuleInfo0, ModuleInfo).	

:- pred adjust_instance_status_3(hlds_instance_defn::in,
	hlds_instance_defn::out, module_info::in, module_info::out) is det.

adjust_instance_status_3(Instance0, Instance, ModuleInfo0, ModuleInfo) :-
	Instance0 = hlds_instance_defn(Status0, Context, Constraints, Types,
			Body, HLDSClassInterface, TVarSet, ConstraintProofs),
	(
		( Status0 = local
		; Status0 = abstract_exported
		)
	->
		Instance = hlds_instance_defn(exported, Context, Constraints,
				Types, Body, HLDSClassInterface, TVarSet,
				ConstraintProofs),
		( HLDSClassInterface = yes(ClassInterface) ->
			class_procs_to_pred_ids(ClassInterface, PredIds),
			set_list_of_preds_exported(PredIds,
				ModuleInfo0, ModuleInfo)
		;
			% This can happen if an instance has multiple
			% declarations, one of which is abstract.
			ModuleInfo = ModuleInfo0
		)
	;
		ModuleInfo = ModuleInfo0,
		Instance = Instance0
	).

:- pred set_list_of_preds_exported(list(pred_id)::in, module_info::in,
		module_info::out) is det.

set_list_of_preds_exported(PredIds, ModuleInfo0, ModuleInfo) :-
	module_info_preds(ModuleInfo0, Preds0),
	set_list_of_preds_exported_2(PredIds, Preds0, Preds),
	module_info_set_preds(ModuleInfo0, Preds, ModuleInfo).

:- pred set_list_of_preds_exported_2(list(pred_id)::in, pred_table::in,
					pred_table::out) is det.

set_list_of_preds_exported_2([], Preds, Preds).
set_list_of_preds_exported_2([PredId | PredIds], Preds0, Preds) :-
	map__lookup(Preds0, PredId, PredInfo0),
	( pred_info_import_status(PredInfo0, local) ->	
		(
			pred_info_name(PredInfo0, "__Unify__"),
			pred_info_arity(PredInfo0, 2)
		->
			NewStatus = pseudo_exported
		;
			NewStatus = exported
		),
		pred_info_set_import_status(PredInfo0, NewStatus, PredInfo),
		map__det_update(Preds0, PredId, PredInfo, Preds1)
	;
		Preds1 = Preds0
	),
	set_list_of_preds_exported_2(PredIds, Preds1, Preds).

%-----------------------------------------------------------------------------%
	% Read in and process the optimization interfaces.

intermod__grab_optfiles(Module0, Module, FoundError) -->

		%
		% Read in the .opt files for imported and ancestor modules.
		%
	{ Module0 = module_imports(_, ModuleName, Ancestors0, InterfaceDeps0,
					ImplementationDeps0, _, _, _, _, _) },
	{ list__condense([Ancestors0, InterfaceDeps0, ImplementationDeps0],
		OptFiles) },
	read_optimization_interfaces(OptFiles, [], OptItems, no, OptError),

		%
		% Append the items to the current item list, using
		% a `opt_imported' psuedo-declaration to let
		% make_hlds know the opt_imported stuff is coming.
		%
	{ module_imports_get_items(Module0, Items0) },
	{ make_pseudo_decl(opt_imported, OptImportedDecl) },
	{ list__append(Items0, [OptImportedDecl | OptItems], Items1) },
	{ module_imports_set_items(Module0, Items1, Module1) },

		%
		% Get the :- pragma unused_args(...) declarations created
		% when writing the .opt file for the current module. These
		% are needed because we can probably remove more arguments
		% with intermod_unused_args, but the interface for other
		% modules must remain the same.
		%
	globals__io_lookup_bool_option(intermod_unused_args, UnusedArgs),
	( { UnusedArgs = yes } ->
		read_optimization_interfaces([ModuleName], [],
				LocalItems, no, UAError),
		{ IsPragmaUnusedArgs = lambda([Item::in] is semidet, (
					Item = pragma(PragmaType) - _,
					PragmaType = unused_args(_,_,_,_,_)
				)) },
		{ list__filter(IsPragmaUnusedArgs, LocalItems, PragmaItems) },

		{ module_imports_get_items(Module1, Items2) },
		{ list__append(Items2, PragmaItems, Items) },
		{ module_imports_set_items(Module1, Items, Module2) }
	;
		{ Module2 = Module1 },
		{ UAError = no }
	),

		%
		% Figure out which .int files are needed by the .opt files
		%
	{ get_dependencies(OptItems, NewImportDeps0, NewUseDeps0) },
	{ list__append(NewImportDeps0, NewUseDeps0, NewDeps0) },
	{ set__list_to_set(NewDeps0, NewDepsSet0) },
	{ set__delete_list(NewDepsSet0, [ModuleName | OptFiles], NewDepsSet) },
	{ set__to_sorted_list(NewDepsSet, NewDeps) },

		%
		% Read in the .int, and .int2 files needed by the .opt files.
		% (XXX do we also need to read in .int0 files here?)
		%
	process_module_long_interfaces(NewDeps, ".int", [], NewIndirectDeps,
				Module2, Module3),
	process_module_indirect_imports(NewIndirectDeps, ".int2",
				Module3, Module),

		%
		% Figure out whether anything went wrong
		%
	{ module_imports_get_error(Module, FoundError0) },
	{ ( FoundError0 \= no ; OptError = yes ; UAError = yes) ->
		FoundError = yes
	;
		FoundError = no
	}.

:- pred read_optimization_interfaces(list(module_name)::in, item_list::in,
			item_list::out, bool::in, bool::out,
			io__state::di, io__state::uo) is det.

read_optimization_interfaces([], Items, Items, Error, Error) --> [].
read_optimization_interfaces([Import | Imports],
		Items0, Items, Error0, Error) -->
	( { Import = qualified(_, _) } ->
		% XXX Don't read in optimization interfaces for
		% nested modules, because we also need to read in
		% the `.int0' file for the parent modules.
		% Reading them in may cause problems because the
		% `.int0' files duplicate information in the `.int'
		% files.
		{ Error1 = Error0 },
		{ Items2 = Items0 }
	;
		globals__io_lookup_bool_option(very_verbose, VeryVerbose),
		maybe_write_string(VeryVerbose,
				"% Reading optimization interface for module"),
		maybe_write_string(VeryVerbose, " `"),
		{ prog_out__sym_name_to_string(Import, ImportString) },
		maybe_write_string(VeryVerbose, ImportString),
		maybe_write_string(VeryVerbose, "'... "),
		maybe_flush_output(VeryVerbose),
		maybe_write_string(VeryVerbose, "% done.\n"),

		module_name_to_file_name(Import, ".opt", no, FileName),
		prog_io__read_opt_file(FileName, Import, yes,
				ModuleError, Messages, Items1),
		update_error_status(opt, FileName, ModuleError, Messages,
				Error0, Error1),
		{ list__append(Items0, Items1, Items2) }
	),
	read_optimization_interfaces(Imports, Items2, Items, Error1, Error).

update_error_status(FileType, FileName, ModuleError, Messages,
		Error0, Error1) -->
	(
		{ ModuleError = no },
		{ Error1 = Error0 }
	;
		{ ModuleError = yes },
		prog_out__write_messages(Messages),
		{ Error1 = yes }
	;
		{ ModuleError = fatal },
		{
			FileType = opt,
			WarningOption = warn_missing_opt_files
		;
			FileType = trans_opt,
			WarningOption = warn_missing_trans_opt_files
		},
		globals__io_lookup_bool_option(WarningOption, DoWarn),
		( { DoWarn = yes } ->
			io__write_string("Warning: cannot open `"),
			io__write_string(FileName),
			io__write_string("'.\n"),
			globals__io_lookup_bool_option(halt_at_warn,
					HaltAtWarn),
			{ HaltAtWarn = yes ->
				Error1 = yes
			;
				Error1 = Error0
			}
		;
			{ Error1 = Error0 }	
		)
	).

%-----------------------------------------------------------------------------%
