%-----------------------------------------------------------------------------%
% Copyright (C) 1995 University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%

% This module defines the part of the High Level Data Structure or HLDS
% that deals with issues that are wider than a single predicate.

% The four main data structures defined here are the types
%
%	module_info
%	dependency_info
%	predicate_table
%	shape_table
%
% There is a separate interface section for each of these.

% Main authors: fjh, conway.

:- module hlds_module.

:- interface.

:- import_module hlds_pred, llds, unify_proc, special_pred.
:- import_module relation.

:- implementation.

:- import_module hlds_data, prog_io, shapes.
:- import_module require, int, list, map, set, std_util.

%-----------------------------------------------------------------------------%

:- interface.

:- type module_info.

:- type c_code_info 	--->	c_code_info(
					c_header_info,
					c_body_info
				).

:- type pragma_exported_proc	
			--->	pragma_exported_proc(
					pred_id,
					proc_id,
					string	% the name of the C function
				).


	% Various predicates for manipulating the module_info data structure

	% Create an empty module_info for a given module name.

:- pred module_info_init(string, module_info).
:- mode module_info_init(in, out) is det.

:- pred module_info_name(module_info, string).
:- mode module_info_name(in, out) is det.

:- pred module_info_get_c_header(module_info, c_header_info).
:- mode module_info_get_c_header(in, out) is det.

:- pred module_info_set_c_header(module_info, c_header_info, module_info).
:- mode module_info_set_c_header(in, in, out) is det.

:- pred module_info_get_c_body_code(module_info, c_body_info).
:- mode module_info_get_c_body_code(in, out) is det.

:- pred module_info_set_c_body_code(module_info, c_body_info, module_info).
:- mode module_info_set_c_body_code(in, in, out) is det.

:- pred module_info_get_predicate_table(module_info, predicate_table).
:- mode module_info_get_predicate_table(in, out) is det.

:- pred module_info_preds(module_info, pred_table).
:- mode module_info_preds(in, out) is det.

:- pred module_info_pred_info(module_info, pred_id, pred_info).
:- mode module_info_pred_info(in, in, out) is det.

	% Given a pred_id and a proc_id, get the
	% pred_info that predicate and the proc_info for that
	% mode of that predicate.

:- pred module_info_pred_proc_info(module_info, pred_id, proc_id,
	pred_info, proc_info).
:- mode module_info_pred_proc_info(in, in, in, out, out) is det.

	% Return a list of the pred_ids of all the "valid" predicates.
	% (Predicates whose definition contains a type error, etc.
	% get removed from this list, so that later passes can rely
	% on the predicates in this list being type-correct, etc.)
:- pred module_info_predids(module_info, list(pred_id)).
:- mode module_info_predids(in, out) is det.

	% Reverse the list of pred_ids.
	% (The list is built up by inserting values at the front,
	% for efficiency; once we've done so, we reverse the list
	% so that progress messages and error messages come out
	% in the expected order.)
:- pred module_info_reverse_predids(module_info, module_info).
:- mode module_info_reverse_predids(in, out) is det.

	% For an explanation of the unify_requests structure,
	% see unify_info.m.
:- pred module_info_get_unify_requests(module_info, unify_requests).
:- mode module_info_get_unify_requests(in, out) is det.

:- pred module_info_get_special_pred_map(module_info, special_pred_map).
:- mode module_info_get_special_pred_map(in, out) is det.

:- pred module_info_get_shapes(module_info, shape_table).
:- mode module_info_get_shapes(in, out) is det.

:- pred module_info_shape_info(module_info, shape_info).
:- mode module_info_shape_info(in, out) is det.

:- pred module_info_types(module_info, type_table).
:- mode module_info_types(in, out) is det.

:- pred module_info_typeids(module_info, list(type_id)).
:- mode module_info_typeids(in, out) is det.

:- pred module_info_insts(module_info, inst_table).
:- mode module_info_insts(in, out) is det.

:- pred module_info_instids(module_info, list(inst_id)).
:- mode module_info_instids(in, out) is det.

:- pred module_info_modes(module_info, mode_table).
:- mode module_info_modes(in, out) is det.

:- pred module_info_modeids(module_info, list(mode_id)).
:- mode module_info_modeids(in, out) is det.

:- pred module_info_ctors(module_info, cons_table).
:- mode module_info_ctors(in, out) is det.

:- pred module_info_num_errors(module_info, int).
:- mode module_info_num_errors(in, out) is det.

% not used
% :- pred module_info_num_warnings(module_info, int).
% :- mode module_info_num_warnings(in, out) is det.

:- pred module_info_consids(module_info, list(cons_id)).
:- mode module_info_consids(in, out) is det.

	% The dependency information must have been build before
	% calling this predicate.

:- pred module_info_dependency_info(module_info, dependency_info).
:- mode module_info_dependency_info(in, out) is det.

	% Succeeds iff the dependency information has already been built

:- pred module_info_dependency_info_built(module_info).
:- mode module_info_dependency_info_built(in) is semidet.

:- pred module_info_set_name(module_info, string, module_info).
:- mode module_info_set_name(in, in, out) is det.

:- pred module_info_set_predicate_table(module_info, predicate_table,
					module_info).
:- mode module_info_set_predicate_table(in, in, out) is det.

:- pred module_info_set_preds(module_info, pred_table, module_info).
:- mode module_info_set_preds(in, in, out) is det.

:- pred module_info_set_unify_requests(module_info, unify_requests,
					module_info).
:- mode module_info_set_unify_requests(in, in, out) is det.

:- pred module_info_set_special_pred_map(module_info, special_pred_map,
					module_info).
:- mode module_info_set_special_pred_map(in, in, out) is det.

:- pred module_info_set_shapes(module_info, shape_table, module_info).
:- mode module_info_set_shapes(in, in, out) is det.

:- pred module_info_set_shape_info(module_info, shape_info, module_info).
:- mode module_info_set_shape_info(in, in, out) is det.

:- pred module_info_set_types(module_info, type_table, module_info).
:- mode module_info_set_types(in, in, out) is det.

:- pred module_info_set_insts(module_info, inst_table, module_info).
:- mode module_info_set_insts(in, in, out) is det.

:- pred module_info_set_modes(module_info, mode_table, module_info).
:- mode module_info_set_modes(in, in, out) is det.

:- pred module_info_set_ctors(module_info, cons_table, module_info).
:- mode module_info_set_ctors(in, in, out) is det.

:- pred module_info_set_dependency_info(module_info, dependency_info,
	module_info).
:- mode module_info_set_dependency_info(in, in, out) is det.

:- pred module_info_set_num_errors(module_info, int, module_info).
:- mode module_info_set_num_errors(in, in, out) is det.

:- pred module_info_incr_errors(module_info, module_info).
:- mode module_info_incr_errors(in, out) is det.

/* not used
:- pred module_info_incr_warnings(module_info, module_info).
:- mode module_info_incr_warnings(in, out) is det.
*/

	% The module_info stores a counter which is used to number
	% introduced lambda predicates as __LambdaGoal__1, __LambdaGoal__2,
	% etc.; this predicate returns the next number and increments
	% the counter.

:- pred module_info_next_lambda_count(module_info, int, module_info).
:- mode module_info_next_lambda_count(in, out, out) is det.

:- pred module_info_get_pragma_exported_procs(module_info,
	list(pragma_exported_proc)).
:- mode module_info_get_pragma_exported_procs(in, out) is det.

:- pred module_info_set_pragma_exported_procs(module_info,
	list(pragma_exported_proc), module_info).
:- mode module_info_set_pragma_exported_procs(in, in, out) is det.

	% Remove a predicate from the list of pred_ids, to prevent
	% further processing of this predicate after an error is
	% encountered.

:- pred module_info_remove_predid(module_info, pred_id, module_info).
:- mode module_info_remove_predid(in, in, out) is det.

	% Once the module_info has been built, we call module_info_optimize
	% to attempt to optimize the data structures for lots of accesses
	% and relatively few insertion/deletions. (This was useful when
	% we were using unbalanced binary trees, but now that we are using
	% 234-trees, it is a no-op.)

:- pred module_info_optimize(module_info, module_info).
:- mode module_info_optimize(in, out) is det.

%-----------------------------------------------------------------------------%

:- implementation.

:- type module_info	--->	module(
					string,		% module name
					c_code_info,	
					predicate_table,
					unify_requests,
					special_pred_map,
					shape_info,
					type_table,
					inst_table,
					mode_table,
					cons_table,
					maybe(dependency_info),
					int,		% number of errors
					%%% num_warnings not used:
					%%% int,	% number of warnings
					int,	% lambda predicate counter
					list(pragma_exported_proc)
						% list of the procs for which
						% there is a pragma(export, ...)
						% declaration
				).

	% A predicate which creates an empty module

module_info_init(Name, module(Name, C_Code_Info, PredicateTable, Requests, 
				UnifyPredMap, Shapes, Types, Insts, Modes, 
				Ctors, DepInfo, 0, 0, PragmaExports)) :-
	C_Code_Info = c_code_info([], []),
	predicate_table_init(PredicateTable),
	unify_proc__init_requests(Requests),
	map__init(UnifyPredMap),
	map__init(Types),
	inst_table_init(Insts),
	map__init(Modes),
	shapes__init_shape_table(ShapeTable),
	map__init(AbsExports),
	Shapes = shape_info(ShapeTable, AbsExports),
	map__init(Ctors),
	DepInfo = no,
	PragmaExports = [].

	% Various access predicates which extract different pieces
	% of info from the module_info data structure.

module_info_name(ModuleInfo, Name) :-
	ModuleInfo = module(Name, _, _, _, _, _, _, _, _, _, _, _, _, _).

module_info_get_c_header(ModuleInfo, C_Header) :-
	ModuleInfo = module(_, C_Code_Info, _, _, _, _, _, _, _, _, _, _, _, _),
	C_Code_Info = c_code_info(C_Header, _).

module_info_set_c_header(ModuleInfo1, C_Header, ModuleInfo2) :-
	ModuleInfo1 = module(A, C_Code_Info0, 
		C, D, E, F, G, H, I, J, K, L, M, N),
	C_Code_Info0 = c_code_info(_C_Header0, C_Body),
	C_Code_Info = c_code_info(C_Header, C_Body),
	ModuleInfo2 = module(A, C_Code_Info, 
		C, D, E, F, G, H, I, J, K, L, M, N).

module_info_get_c_body_code(ModuleInfo, C_Body) :-
	ModuleInfo = module(_, C_Code_Info, _, _, _, _, _, _, _, _, _, _, _, _),
	C_Code_Info = c_code_info(_, C_Body).

module_info_set_c_body_code(ModuleInfo1, C_Body, ModuleInfo2) :-
	ModuleInfo1 = module(A, C_Code_Info0, 
		C, D, E, F, G, H, I, J, K, L, M, N),
	C_Code_Info0 = c_code_info(C_Header, _C_Body0),
	C_Code_Info = c_code_info(C_Header, C_Body),
	ModuleInfo2 = module(A, C_Code_Info, 
		C, D, E, F, G, H, I, J, K, L, M, N).

module_info_get_predicate_table(ModuleInfo, PredicateTable) :-
	ModuleInfo = module(_, _, PredicateTable, 
		_, _, _, _, _, _, _, _, _, _, _).

module_info_preds(ModuleInfo, Preds) :-
	module_info_get_predicate_table(ModuleInfo, PredicateTable),
	predicate_table_get_preds(PredicateTable, Preds).

module_info_pred_info(ModuleInfo, PredId, PredInfo) :-
	module_info_preds(ModuleInfo, Preds),
	map__lookup(Preds, PredId, PredInfo).

module_info_pred_proc_info(ModuleInfo, PredId, ProcId, PredInfo, ProcInfo) :-
	module_info_pred_info(ModuleInfo, PredId, PredInfo),
	pred_info_procedures(PredInfo, Procs),
	map__lookup(Procs, ProcId, ProcInfo).

module_info_predids(ModuleInfo, PredIds) :-
	module_info_get_predicate_table(ModuleInfo, PredicateTable),
	predicate_table_get_predids(PredicateTable, PredIds).

module_info_reverse_predids(ModuleInfo0, ModuleInfo) :-
	module_info_get_predicate_table(ModuleInfo0, PredicateTable0),
	predicate_table_reverse_predids(PredicateTable0, PredicateTable),
	module_info_set_predicate_table(ModuleInfo0, PredicateTable,
		ModuleInfo).

module_info_get_unify_requests(ModuleInfo, Requests) :-
	ModuleInfo = module(_, _, _, Requests, _, _, _, _, _, _, _, _, _, _).

module_info_get_shapes(ModuleInfo, Shapes) :-
	module_info_shape_info(ModuleInfo, Shape_Info),
	Shape_Info = shape_info(Shapes, _AbsExports).

module_info_get_special_pred_map(ModuleInfo, SpecialPredMap) :-
	ModuleInfo = module(_, _, _, _, SpecialPredMap, 
		_, _, _, _, _, _, _, _, _).

module_info_shape_info(ModuleInfo, ShapeInfo) :-
	ModuleInfo = module(_, _, _, _, _, ShapeInfo, _, _, _, _, _, _, _, _).

module_info_types(ModuleInfo, Types) :-
	ModuleInfo = module(_, _, _, _, _, _, Types, _, _, _, _, _, _, _).

module_info_typeids(ModuleInfo, TypeIDs) :-
	ModuleInfo = module(_, _, _, _, _, _, Types, _, _, _, _, _, _, _),
	map__keys(Types, TypeIDs).

module_info_insts(ModuleInfo, Insts) :-
	ModuleInfo = module(_, _, _, _, _, _, _, Insts, _, _, _, _, _, _).

module_info_instids(ModuleInfo, InstIDs) :-
	module_info_insts(ModuleInfo, InstTable),
	inst_table_get_user_insts(InstTable, UserInstTable),
	map__keys(UserInstTable, InstIDs).

module_info_modes(ModuleInfo, Modes) :-
	ModuleInfo = module(_, _, _, _, _, _, _, _, Modes, _, _, _, _, _).

module_info_modeids(ModuleInfo, ModeIDs) :-
	ModuleInfo = module(_, _, _, _, _, _, _, _, Modes, _, _, _, _, _),
	map__keys(Modes, ModeIDs).

module_info_ctors(ModuleInfo, Ctors) :-
	ModuleInfo = module(_, _, _, _, _, _, _, _, _, Ctors, _, _, _, _).

module_info_consids(ModuleInfo, ConsIDs) :-
	ModuleInfo = module(_, _, _, _, _, _, _, _, _, Ctors, _, _, _, _),
	map__keys(Ctors, ConsIDs).

module_info_dependency_info(ModuleInfo, DepInfo) :-
	ModuleInfo = module(_, _, _, _, _, _, _, _, _, _, DepInfo0, _, _, _),
	( DepInfo0 = yes(DepInfo1) ->
		DepInfo = DepInfo1
	;
		error("Attempted to access uninitialised dependency_info")
	).

module_info_dependency_info_built(ModuleInfo) :-
	ModuleInfo = module(_, _, _, _, _, _, _, _, _, _, yes(_), _, _, _).

module_info_num_errors(ModuleInfo, NumErrors) :-
	ModuleInfo = module(_, _, _, _, _, _, _, _, _, _, _, NumErrors, _, _).

% not used:
% module_info_num_warnings(ModuleInfo, NumWarnings) :-
% 	ModuleInfo = module(_, _, _, _, _, _, _, _, _, _, _, _, NumWarnings).

% module_info_lambda_count(ModuleInfo, LambdaCount) :-
% 	ModuleInfo = module(_, _, _, _, _, _, _, _, _, _, _, _, LambdaCount).

	% Various predicates which modify the module_info data structure.

module_info_set_name(ModuleInfo0, Name, ModuleInfo) :-
	ModuleInfo0 = module(_, B, C, D, E, F, G, H, I, J, K, L, M, N),
	ModuleInfo = module(Name, B, C, D, E, F, G, H, I, J, K, L, M, N).

module_info_set_predicate_table(ModuleInfo0, PredicateTable, ModuleInfo) :-
	ModuleInfo0 = module(A, B, _, D, E, F, G, H, I, J, K, L, M, N),
	ModuleInfo = module(A, B, PredicateTable, 
		D, E, F, G, H, I, J, K, L, M, N).

module_info_set_preds(ModuleInfo0, Preds, ModuleInfo) :-
	module_info_get_predicate_table(ModuleInfo0, PredicateTable0),
	predicate_table_set_preds(PredicateTable0, Preds, PredicateTable),
	module_info_set_predicate_table(ModuleInfo0, PredicateTable,
		ModuleInfo).

module_info_set_unify_requests(ModuleInfo0, Requests, ModuleInfo) :-
	ModuleInfo0 = module(A, B, C, _, E, F, G, H, I, J, K, L, M, N), 
	ModuleInfo = module(A, B, C, Requests, E, F, G, H, I, J, K, L, M, N).

module_info_set_special_pred_map(ModuleInfo0, SpecialPredMap, ModuleInfo) :-
	ModuleInfo0 = module(A, B, C, D, _, F, G, H, I, J, K, L, M, N),
	ModuleInfo = module(A, B, C, D, SpecialPredMap, 
		F, G, H, I, J, K, L, M, N).

module_info_set_shapes(ModuleInfo0, Shapes, ModuleInfo) :-
	ModuleInfo0 = module(A, B, C, D, E, F, G, H, I, J, K, L, M, N),
	F = shape_info(_, AbsExports),
	ModuleInfo = module(A, B, C, D, E, shape_info(Shapes, AbsExports),
		G, H, I, J, K, L, M, N).

module_info_set_shape_info(ModuleInfo0, Shape_Info, ModuleInfo) :-
	ModuleInfo0 = module(A, B, C, D, E, _, G, H, I, J, K, L, M, N),
	ModuleInfo = module(A, B, C, D, E, Shape_Info, G, H, I, J, K, L, M, N).

module_info_set_types(ModuleInfo0, Types, ModuleInfo) :-
	ModuleInfo0 = module(A, B, C, D, E, F, _, H, I, J, K, L, M, N),
	ModuleInfo = module(A, B, C, D, E, F, Types, H, I, J, K, L, M, N).

module_info_set_insts(ModuleInfo0, Insts, ModuleInfo) :-
	ModuleInfo0 = module(A, B, C, D, E, F, G, _, I, J, K, L, M, N),
	ModuleInfo = module(A, B, C, D, E, F, G, Insts, I, J, K, L, M, N).

module_info_set_modes(ModuleInfo0, Modes, ModuleInfo) :-
	ModuleInfo0 = module(A, B, C, D, E, F, G, H, _, J, K, L, M, N),
	ModuleInfo = module(A, B, C, D, E, F, G, H, Modes, J, K, L, M, N).

module_info_set_ctors(ModuleInfo0, Ctors, ModuleInfo) :-
	ModuleInfo0 = module(A, B, C, D, E, F, G, H, I, _, K, L, M, N),
	ModuleInfo = module(A, B, C, D, E, F, G, H, I, Ctors, K, L, M, N).

module_info_set_dependency_info(ModuleInfo0, DepInfo, ModuleInfo) :-
	ModuleInfo0 = module(A, B, C, D, E, F, G, H, I, J, _, L, M, N),
	ModuleInfo = module(A, B, C, D, E, F, G, H, I, J, yes(DepInfo), 
		L, M, N).

module_info_set_num_errors(ModuleInfo0, Errs, ModuleInfo) :-
	ModuleInfo0 = module(A, B, C, D, E, F, G, H, I, J, K, _, M, N),
	ModuleInfo = module(A, B, C, D, E, F, G, H, I, J, K, Errs, M, N).

module_info_incr_errors(ModuleInfo0, ModuleInfo) :-
	ModuleInfo0 = module(A, B, C, D, E, F, G, H, I, J, K, Errs0, M, N),
	Errs is Errs0 + 1,
	ModuleInfo = module(A, B, C, D, E, F, G, H, I, J, K, Errs, M, N).

/* not used
module_info_incr_warnings(ModuleInfo0, ModuleInfo) :-
	ModuleInfo0 = module(A, B, C, D, E, F, G, H, I, J, K, L, Warns0),
	Warns is Warns0 + 1,
	ModuleInfo = module(A, B, C, D, E, F, G, H, I, J, K, L, Warns).
*/
module_info_next_lambda_count(ModuleInfo0, Count, ModuleInfo) :-
	ModuleInfo0 = module(A, B, C, D, E, F, G, H, I, J, K, L, Count0, N),
	Count is Count0 + 1,
	ModuleInfo = module(A, B, C, D, E, F, G, H, I, J, K, L, Count, N).

module_info_get_pragma_exported_procs(ModuleInfo, Procs) :-
	ModuleInfo = module(_, _, _, _, _, _, _, _, _, _, _, _, _, Procs).

module_info_set_pragma_exported_procs(ModuleInfo0, Procs, ModuleInfo) :-
	ModuleInfo0 = module(A, B, C, D, E, F, G, H, I, J, K, L, M, _),
	ModuleInfo = module(A, B, C, D, E, F, G, H, I, J, K, L, M, Procs).

module_info_remove_predid(ModuleInfo0, PredId, ModuleInfo) :-
	module_info_get_predicate_table(ModuleInfo0, PredicateTable0),
	predicate_table_remove_predid(PredicateTable0, PredId,
				PredicateTable),
	module_info_set_predicate_table(ModuleInfo0, PredicateTable,
				ModuleInfo).

	% After we have finished constructing the symbol tables,
	% we balance all the binary trees, to improve performance
	% in later stages of the compiler.

module_info_optimize(ModuleInfo0, ModuleInfo) :-

	module_info_get_predicate_table(ModuleInfo0, Preds0),
	predicate_table_optimize(Preds0, Preds),
	module_info_set_predicate_table(ModuleInfo0, Preds, ModuleInfo2),

	module_info_get_shapes(ModuleInfo2, (Shapes0 - N)),
	map__optimize(Shapes0, Shapes),
	module_info_set_shapes(ModuleInfo2, (Shapes - N), ModuleInfo3),

	module_info_types(ModuleInfo3, Types0),
	map__optimize(Types0, Types),
	module_info_set_types(ModuleInfo3, Types, ModuleInfo4),

	module_info_insts(ModuleInfo4, InstTable0),
	inst_table_get_user_insts(InstTable0, Insts0),
	map__optimize(Insts0, Insts),
	inst_table_set_user_insts(InstTable0, Insts, InstTable),
	module_info_set_insts(ModuleInfo4, InstTable, ModuleInfo5),

	module_info_modes(ModuleInfo5, Modes0),
	map__optimize(Modes0, Modes),
	module_info_set_modes(ModuleInfo4, Modes, ModuleInfo6),

	module_info_ctors(ModuleInfo6, Ctors0),
	map__optimize(Ctors0, Ctors),
	module_info_set_ctors(ModuleInfo6, Ctors, ModuleInfo).

%-----------------------------------------------------------------------------%

:- interface.

:- type dependency_ordering	== list(list(pred_proc_id)).
:- type dependency_graph	== relation(pred_proc_id).
:- type dependency_info.

:- pred hlds__dependency_info_init(dependency_info).
:- mode hlds__dependency_info_init(out) is det.

:- pred hlds__dependency_info_get_dependency_graph(dependency_info, 
	dependency_graph).
:- mode hlds__dependency_info_get_dependency_graph(in, out) is det.

:- pred hlds__dependency_info_get_dependency_ordering(dependency_info, 
	dependency_ordering).
:- mode hlds__dependency_info_get_dependency_ordering(in, out) is det.

:- pred hlds__dependency_info_set_dependency_graph(dependency_info,
	dependency_graph, dependency_info).
:- mode hlds__dependency_info_set_dependency_graph(in, in, out) is det.

:- pred hlds__dependency_info_set_dependency_ordering(dependency_info,
	dependency_ordering, dependency_info).
:- mode hlds__dependency_info_set_dependency_ordering(in, in, out) is det.

%-----------------------------------------------------------------------------%

:- implementation.

:- type dependency_info --->
		dependency_info(
			dependency_graph,	% Dependency graph
			dependency_ordering,	% Dependency ordering
			set(pred_proc_id),	% Unused procs
			unit,			% Junk slots
			unit,
			unit
		).

hlds__dependency_info_init(DepInfo) :-
	DepInfo = dependency_info(DepRel, DepOrd, Unused, unit, unit, unit),
	relation__init(DepRel),
	DepOrd = [],
	set__init(Unused).

hlds__dependency_info_get_dependency_graph(DepInfo, DepRel) :-
	DepInfo = dependency_info(DepRel, _, _, _, _, _).

hlds__dependency_info_get_dependency_ordering(DepInfo, DepOrd) :-
	DepInfo = dependency_info(_, DepOrd, _, _, _, _).

hlds__dependency_info_set_dependency_graph(DepInfo0, DepRel, DepInfo) :-
	DepInfo0 = dependency_info(_, B, C, D, E, F),
	DepInfo = dependency_info(DepRel, B, C, D, E, F).

hlds__dependency_info_set_dependency_ordering(DepInfo0, DepRel, DepInfo) :-
	DepInfo0 = dependency_info(A, _, C, D, E, F),
	DepInfo = dependency_info(A, DepRel, C, D, E, F).

%-----------------------------------------------------------------------------%

:- interface.

:- type predicate_table.

:- type pred_table	==	map(pred_id, pred_info).

	% Various predicates for accessing the predicate_table type.
	% The predicate_table holds information about the predicates
	% defined in this module or imported from other modules.
	% The primary key for this table is the `pred_id', but there
	% are also secondary indexes on name, name+arity, and module+name+arity.

	% Initialize the predicate table

:- pred predicate_table_init(predicate_table).
:- mode predicate_table_init(out) is det.

	% Balance all the binary trees in the predicate table

:- pred predicate_table_optimize(predicate_table, predicate_table).
:- mode predicate_table_optimize(in, out) is det.

	% Get the pred_id->pred_info map.

:- pred predicate_table_get_preds(predicate_table, pred_table).
:- mode predicate_table_get_preds(in, out) is det.

	% Set the pred_id->pred_info map.
	% NB You shouldn't modify the keys in this table, only
	% use predicate_table_insert and predicate_table_remove_predid.

:- pred predicate_table_set_preds(predicate_table, pred_table, predicate_table).
:- mode predicate_table_set_preds(in, in, out) is det.

	% Get a list of all the valid predids in the predicate_table.

:- pred predicate_table_get_predids(predicate_table, list(pred_id)).
:- mode predicate_table_get_predids(in, out) is det.

	% Remove a pred_id from the valid list.

:- pred predicate_table_remove_predid(predicate_table, pred_id,
					predicate_table).
:- mode predicate_table_remove_predid(in, in, out) is det.

	% Search the table for predicates matching this
	% (possibly module-qualified) sym_name.

:- pred predicate_table_search_sym(predicate_table, sym_name, list(pred_id)).
:- mode predicate_table_search_sym(in, in, out) is semidet.

	% Search the table for predicates matching this
	% (possibly module-qualified) sym_name & arity.

:- pred predicate_table_search_sym_arity(predicate_table, sym_name, arity,
					list(pred_id)).
:- mode predicate_table_search_sym_arity(in, in, in, out) is semidet.

	% Search the table for predicates matching this name.

:- pred predicate_table_search_name(predicate_table, string, list(pred_id)).
:- mode predicate_table_search_name(in, in, out) is semidet.

	% Search the table for predicates matching this name & arity.

:- pred predicate_table_search_name_arity(predicate_table, string, arity,
						list(pred_id)).
:- mode predicate_table_search_name_arity(in, in, in, out) is semidet.

	% Search the table for THE predicate matching this module,
	% name, and arity. (We currently don't allow overloading
	% of predicates with the same name/arity in the same module.)
	% m_n_a is short for module, name, arity.

:- pred predicate_table_search_m_n_a(predicate_table, module_name, string,
						arity, list(pred_id)).
:- mode predicate_table_search_m_n_a(in, in, in, in, out) is semidet.

	% Insert a new pred_info structure into the predicate_table
	% and assign it a new pred_id. You should check beforehand
	% that the pred doesn't already occur in the table.

:- pred predicate_table_insert(predicate_table, pred_info, pred_id,
				predicate_table).
:- mode predicate_table_insert(in, in, out, out) is det.

	% Return an invalid pred_id. Used to initialize the pred_id
	% in call(...) goals before we do typechecking or when type-checking
	% finds that there was no predicate which matched the call.

:- pred invalid_pred_id(pred_id).
:- mode invalid_pred_id(out) is det.
:- mode invalid_pred_id(in) is semidet.

:- pred predicate_module(module_info, pred_id, module_name).
:- mode predicate_module(in, in, out) is det.

:- pred predicate_name(module_info, pred_id, string).
:- mode predicate_name(in, in, out) is det.

:- pred predicate_arity(module_info, pred_id, arity).
:- mode predicate_arity(in, in, out) is det.

%-----------------------------------------------------------------------------%

:- implementation.

:- type predicate_table --->
	predicate_table(
		pred_table,		% map from pred_id to pred_info
		pred_id,		% next available pred_id
		list(pred_id),		% the keys of the pred_table -
					% cached here for efficiency
		pred_name_index,	% map from pred name to pred_id
		pred_name_arity_index,	% map from pred name & arity to pred_id
		pred_module_name_arity_index
					% map from pred module, name & arity
					% to pred_id
	).

:- type pred_name_index	== map(string, list(pred_id)).

:- type pred_name_arity_index == map(name_arity, list(pred_id)).
:- type name_arity ---> string / arity.

:- type pred_module_name_arity_index == map(module_name_arity, list(pred_id)).
:- type module_name_arity ---> module_name_arity(module_name, string, arity).

predicate_table_init(PredicateTable) :-
	PredicateTable = predicate_table(Preds, NextPredId, PredIds,
				N_Index, NA_Index, MNA_Index),
	map__init(Preds),
	NextPredId = 0,
	PredIds = [],
	map__init(N_Index),
	map__init(NA_Index),
	map__init(MNA_Index).

predicate_table_optimize(PredicateTable0, PredicateTable) :-
	PredicateTable0 = predicate_table(A, B, C,
				N_Index0, NA_Index0, MNA_Index0),
	map__optimize(N_Index0, N_Index),
	map__optimize(NA_Index0, NA_Index),
	map__optimize(MNA_Index0, MNA_Index),
	PredicateTable = predicate_table(A, B, C,
				N_Index, NA_Index, MNA_Index).

predicate_table_get_preds(PredicateTable, Preds) :-
	PredicateTable = predicate_table(Preds, _, _, _, _, _).

predicate_table_set_preds(PredicateTable0, Preds, PredicateTable) :-
	PredicateTable0 = predicate_table(_, B, C, D, E, F),
	PredicateTable = predicate_table(Preds, B, C, D, E, F).

predicate_table_get_predids(PredicateTable, PredIds) :-
	PredicateTable = predicate_table(_, _, PredIds, _, _, _).

predicate_table_remove_predid(PredicateTable0, PredId, PredicateTable) :-
	PredicateTable0 = predicate_table(A, B, PredIds0, D, E, F),
	list__delete_all(PredIds0, PredId, PredIds),
	PredicateTable = predicate_table(A, B, PredIds, D, E, F).

:- pred predicate_table_reverse_predids(predicate_table, predicate_table).
:- mode predicate_table_reverse_predids(in, out) is det.

predicate_table_reverse_predids(PredicateTable0, PredicateTable) :-
	PredicateTable0 = predicate_table(A, B, PredIds0, D, E, F),
	list__reverse(PredIds0, PredIds),
	PredicateTable = predicate_table(A, B, PredIds, D, E, F).

:- predicate_table_search_sym(_, X, _) when X. % NU-Prolog indexing.

predicate_table_search_sym(PredicateTable, unqualified(Name), PredIdList) :-
	predicate_table_search_name(PredicateTable, Name, PredIdList).
predicate_table_search_sym(PredicateTable, qualified(Module, Name),
		PredIdList) :-
	predicate_table_search_name(PredicateTable, Name, PredIdList0),
	predicate_table_get_preds(PredicateTable, PredTable),
	find_preds_matching_module(PredIdList0, Module, PredTable, PredIdList),
	PredIdList \= [].

	% Given a list of predicates, and a module name, find all the
	% predicates which came from that module.

:- pred find_preds_matching_module(list(pred_id), module_name, pred_table,
		list(pred_id)).
:- mode find_preds_matching_module(in, in, in, out) is det.

find_preds_matching_module([], _, _, []).
find_preds_matching_module([PredId | PredIds0], Module, PredTable, PredIds) :-
	(
		map__search(PredTable, PredId, PredInfo),
		pred_info_module(PredInfo, Module)
	->
		PredIds = [PredId | PredIds1]
	;
		PredIds = PredIds1
	),
	find_preds_matching_module(PredIds0, Module, PredTable, PredIds1).

:- predicate_table_search_sym_arity(_, X, _, _) when X. % NU-Prolog indexing.

predicate_table_search_sym_arity(PredicateTable, qualified(Module, Name),
		Arity, PredIdList) :-
	predicate_table_search_m_n_a(PredicateTable, Module, Name, Arity,
		PredIdList).
predicate_table_search_sym_arity(PredicateTable, unqualified(Name),
		Arity, PredIdList) :-
	predicate_table_search_name_arity(PredicateTable, Name, Arity,
		PredIdList).

predicate_table_search_name(PredicateTable, PredName, PredId) :-
	PredicateTable = predicate_table(_, _, _, PredNameIndex, _, _),
	map__search(PredNameIndex, PredName, PredId).

predicate_table_search_name_arity(PredicateTable, PredName, Arity, PredId) :-
	PredicateTable = predicate_table(_, _, _, _, PredNameArityIndex, _),
	map__search(PredNameArityIndex, PredName / Arity, PredId).

predicate_table_search_m_n_a(PredicateTable, Module, PredName, Arity, PredIds)
		:-
	PredicateTable = predicate_table(_, _, _, _, _, MNA_Index),
	MNA = module_name_arity(Module, PredName, Arity),
	map__search(MNA_Index, MNA, PredIds).

predicate_table_insert(PredicateTable0, PredInfo, PredId, PredicateTable) :-
	PredicateTable0 = predicate_table(Preds0, NextPredId0, PredIds0,
				N_Index0, NA_Index0, MNA_Index0),
	pred_info_module(PredInfo, Module),
	pred_info_name(PredInfo, Name),
	pred_info_arity(PredInfo, Arity),

		% allocate a new pred_id
	PredId = NextPredId0,
	NextPredId is PredId + 1,

		% insert the pred_id into the name index
	( map__search(N_Index0, Name, N_PredIdList0) ->
		N_PredIdList = [PredId | N_PredIdList0]
	;
		N_PredIdList = [PredId]
	),
	map__set(N_Index0, Name, N_PredIdList, N_Index),

		% insert it into the name/arity index
	NA = Name / Arity,
	( map__search(NA_Index0, NA, NA_PredIdList0) ->
		NA_PredIdList = [PredId | NA_PredIdList0]
	;
		NA_PredIdList = [PredId]
	),
	map__set(NA_Index0, NA, NA_PredIdList, NA_Index),

		% insert it into the module:name/arity index
	MNA = module_name_arity(Module, Name, Arity),
	( map__search(MNA_Index0, MNA, MNA_PredIdList0) ->
		MNA_PredIdList = [PredId | MNA_PredIdList0]
	;
		MNA_PredIdList = [PredId]
	),
	map__set(MNA_Index0, MNA, MNA_PredIdList, MNA_Index),

		% insert it into the pred_id list
	PredIds = [PredId | PredIds0],

		% save the pred_info for this pred_id
	map__set(Preds0, PredId, PredInfo, Preds),

	PredicateTable = predicate_table(Preds, NextPredId, PredIds,
				N_Index, NA_Index, MNA_Index).

invalid_pred_id(-1).

predicate_module(ModuleInfo, PredId, Module) :-
	module_info_preds(ModuleInfo, Preds),
	map__lookup(Preds, PredId, PredInfo),
	pred_info_module(PredInfo, Module).

predicate_name(ModuleInfo, PredId, PredName) :-
	module_info_preds(ModuleInfo, Preds),
	map__lookup(Preds, PredId, PredInfo),
	pred_info_name(PredInfo, PredName).

predicate_arity(ModuleInfo, PredId, Arity) :-
	module_info_preds(ModuleInfo, Preds),
	map__lookup(Preds, PredId, PredInfo),
	pred_info_arity(PredInfo, Arity).

%-----------------------------------------------------------------------------%

:- interface.

:- type shape_id	==	pair(type, inst).

:- type shape_info	--->	shape_info(shape_table, abs_exports).

:- type abs_exports	==	map(type_id, maybe_shape_num).

:- type maybe_shape_num --->	yes(shape_num)
			;	no(type).

:- type shape		--->	quad(shape_tag, shape_tag, shape_tag,
					 shape_tag)
			;	abstract(type, list(shape_num))
			;	equivalent(shape_num)
			;	polymorphic(type, int)
			;	closure(type).

:- type shape_tag	--->	constant
			;	simple(list(pair(shape_num, shape_id)))
			;	complicated(list(list(pair(shape_num, shape_id)))).

:- type shape_table	==	pair(map(shape_id, pair(shape_num, shape)),int).

%-----------------------------------------------------------------------------%
