%---------------------------------------------------------------------------%
% Copyright (C) 1996-1999 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%---------------------------------------------------------------------------%
%
% File: pragma_c_gen.m
%
% Main authors: dgj, conway, zs.
%
% The code in this module generates code for pragma_c_code goals.
%
% The schemes we use to generate code for model_det and model_semi
% pragma_c_codes are quite similar, so we handle them together.
% The code that does this is reasonably simple.
%
% The scheme for model_non pragma_c_codes is substantially different,
% so we handle them separately.

:- module pragma_c_gen.

:- interface.

:- import_module hlds_goal, hlds_pred, prog_data.
:- import_module llds, code_info.
:- import_module list, std_util.

:- pred pragma_c_gen__generate_pragma_c_code(code_model::in,
	pragma_c_code_attributes::in, pred_id::in, proc_id::in,
	list(prog_var)::in, list(maybe(pair(string, mode)))::in, list(type)::in,
	hlds_goal_info::in, pragma_c_code_impl::in, code_tree::out,
	code_info::in, code_info::out) is det.

:- pred pragma_c_gen__struct_name(module_name::in, string::in, int::in,
	proc_id::in, string::out) is det.

%---------------------------------------------------------------------------%

:- implementation.

:- import_module hlds_module, hlds_pred, call_gen, llds_out, trace, tree.
:- import_module code_util.
:- import_module options, globals.
:- import_module bool, string, int, assoc_list, set, map, require, term.

% The code we generate for an ordinary (model_det or model_semi) pragma_c_code
% must be able to fit into the middle of a procedure, since such
% pragma_c_codes can be inlined. This code is of the following form:
%
%    <save live variables onto the stack> /* see note (1) below */
%    {
%	<declaration of one local variable for each arg>
%	#define MR_PROC_LABEL <procedure label> /* see note (5) below */
%
%	<assignment of input values from registers to local variables>
%	save_registers(); /* see notes (1) and (2) below */
%	{ <the c code itself> }
%	<for semidet code, check of r1>
%	#ifndef CONSERVATIVE_GC
%	  restore_registers(); /* see notes (1) and (3) below */
%	#endif
%	<assignment of the output values from local variables to registers>
%
%	#undef MR_PROC_LABEL /* see note (5) below */
%    }
%
% In the case of a semidet pragma c_code, the above is followed by
%
%    goto skip_label;
%    fail_label:
%    <code to fail>
%    skip_label:
%
% and the <check of r1> is of the form
%
%	if (!r1) GOTO_LABEL(fail_label);
%
% The code we generate for nondet pragma_c_code assumes that this code is
% the only thing between the procedure prolog and epilog; such pragma_c_codes
% therefore cannot be inlined. The code of the procedure is of one of the
% following two forms:
%
% form 1 (duplicated common code):
% <proc entry label and comments>
% <mkframe including space for the save struct, redoip = do_fail>
% <#define MR_ORDINARY_SLOTS>
% <--- boundary between prolog and code generated here --->
% <set redoip to point to &&xxx_i1>
% <code for entry to a disjunction and first disjunct>
% {
%	<declaration of one local variable for each input and output arg>
%	<declaration of one local variable to point to save struct>
%	<assignment of input values from registers to local variables>
%	<assignment to save struct pointer>
%	save_registers(); /* see notes (1) and (2) below */
%	#define MR_PROC_LABEL <procedure label> /* see note (5) below */
%	#define SUCCEED()	goto callsuccesslabel
%	#define SUCCEED_LAST()	goto calllastsuccesslabel
%	#define FAIL()		fail()
%	{ <the user-written call c code> }
%	{ <the user-written shared c code> }
% callsuccesslabel:
%	restore_registers(); /* see notes (1) and (3) below */
%	<assignment of the output values from local variables to registers>
%	succeed()
% calllastsuccesslabel: /* see note (4) below) */
%	restore_registers(); /* see notes (1) and (3) below */
%	<assignment of the output values from local variables to registers>
%	succeed_discard()
% 	#undef SUCCEED
% 	#undef SUCCEED_LAST
% 	#undef FAIL
%	#undef MR_PROC_LABEL /* see note (5) below */
% }
% Define_label(xxx_i1)
% <code for entry to a later disjunct>
% {
%	<declaration of one local variable for each output arg>
%	<declaration of one local variable to point to save struct>
%	<assignment to save struct pointer>
%	save_registers(); /* see notes (1) and (2) below */
%	#define MR_PROC_LABEL <procedure label> /* see note (5) below */
%	#define SUCCEED()	goto retrysuccesslabel
%	#define SUCCEED_LAST()	goto retrylastsuccesslabel
%	#define FAIL()		fail()
%	{ <the user-written retry c code> }
%	{ <the user-written shared c code> }
% retrysuccesslabel:
%	restore_registers(); /* see notes (1) and (3) below */
%	<assignment of the output values from local variables to registers>
%	succeed()
% retrylastsuccesslabel: /* see note (4) below) */
%	restore_registers(); /* see notes (1) and (3) below */
%	<assignment of the output values from local variables to registers>
%	succeed_discard()
% 	#undef SUCCEED
% 	#undef SUCCEED_LAST
% 	#undef FAIL
%	#undef MR_PROC_LABEL /* see note (5) below */
% }
% <--- boundary between code generated here and epilog --->
% <#undef MR_ORDINARY_SLOTS>
%
% form 2 (shared common code):
% <proc entry label and comments>
% <mkframe including space for the save struct, redoip = do_fail>
% <#define MR_ORDINARY_SLOTS>
% <--- boundary between prolog and code generated here --->
% <set redoip to point to &&xxx_i1>
% <code for entry to a disjunction and first disjunct>
% {
%	<declaration of one local variable for each input and output arg>
%	<declaration of one local variable to point to save struct>
%	<assignment of input values from registers to local variables>
%	<assignment to save struct pointer>
%	save_registers(); /* see notes (1) and (2) below */
%	#define MR_PROC_LABEL <procedure label> /* see note (5) below */
%	#define SUCCEED()	goto callsuccesslabel
%	#define SUCCEED_LAST()	goto calllastsuccesslabel
%	#define FAIL()		fail()
%	{ <the user-written call c code> }
%	GOTO_LABEL(xxx_i2)
% callsuccesslabel: /* see note (4) below */
%	restore_registers(); /* see notes (1) and (3) below */
%	<assignment of the output values from local variables to registers>
%	succeed()
% calllastsuccesslabel: /* see note (4) below */
%	restore_registers(); /* see notes (1) and (3) below */
%	<assignment of the output values from local variables to registers>
%	succeed_discard()
% 	#undef SUCCEED
% 	#undef SUCCEED_LAST
% 	#undef FAIL
%	#undef MR_PROC_LABEL /* see note (5) below */
% }
% Define_label(xxx_i1)
% <code for entry to a later disjunct>
% {
%	<declaration of one local variable for each output arg>
%	<declaration of one local variable to point to save struct>
%	<assignment to save struct pointer>
%	save_registers(); /* see notes (1) and (2) below */
%	#define MR_PROC_LABEL <procedure label> /* see note (5) below */
%	#define SUCCEED()	goto retrysuccesslabel
%	#define SUCCEED_LAST()	goto retrylastsuccesslabel
%	#define FAIL()		fail()
%	{ <the user-written retry c code> }
%	GOTO_LABEL(xxx_i2)
% retrysuccesslabel: /* see note (4) below */
%	restore_registers(); /* see notes (1) and (3) below */
%	<assignment of the output values from local variables to registers>
%	succeed()
% retrylastsuccesslabel: /* see note (4) below */
%	restore_registers(); /* see notes (1) and (3) below */
%	<assignment of the output values from local variables to registers>
%	succeed_discard()
% 	#undef SUCCEED
% 	#undef SUCCEED_LAST
% 	#undef FAIL
%	#undef MR_PROC_LABEL /* see note (5) below */
% }
% Define_label(xxx_i2)
% {
%	<declaration of one local variable for each output arg>
%	<declaration of one local variable to point to save struct>
%	<assignment to save struct pointer>
%	#define MR_PROC_LABEL <procedure label> /* see note (5) below */
%	#define SUCCEED()	goto sharedsuccesslabel
%	#define SUCCEED_LAST()	goto sharedlastsuccesslabel
%	#define FAIL()		fail()
%	{ <the user-written shared c code> }
% sharedsuccesslabel:
%	restore_registers(); /* see notes (1) and (3) below */
%	<assignment of the output values from local variables to registers>
%	succeed()
% sharedlastsuccesslabel: /* see note (4) below */
%	restore_registers(); /* see notes (1) and (3) below */
%	<assignment of the output values from local variables to registers>
%	succeed_discard()
% 	#undef SUCCEED
% 	#undef SUCCEED_LAST
% 	#undef FAIL
%	#undef MR_PROC_LABEL /* see note (5) below */
% }
% <--- boundary between code generated here and epilog --->
% <#undef MR_ORDINARY_SLOTS>
%
% The first form is more time efficient, since it does not include the jumps
% from the call code and retry code to the shared code and the following
% initialization of the save struct pointer in the shared code block,
% while the second form can lead to smaller code since it does not include
% the shared C code (which can be quite big) twice.
%
% Programmers may indicate which form they wish the compiler to use;
% if they don't, the compiler will choose form 1 if the shared code fragment
% is "short", and form 2 if it is "long".
%
% The procedure prolog creates a nondet stack frame that includes space for
% a struct that is saved across calls. Since the position of this struct in
% the nondet stack frame is not known until the procedure prolog is created,
% which is *after* the call to pragma_c_gen__generate_pragma_c_code, the
% prolog will #define MR_ORDINARY_SLOTS as the number of ordinary slots
% in the nondet frame. From the size of the fixed portion of the nondet stack
% frame, from MR_ORDINARY_SLOTS and from the size of the save struct itself,
% one can calculate the address of the save struct itself. The epilog will
% #undef MR_ORDINARY_SLOTS. It need not do anything else, since all the normal
% epilog stuff has been done in the code above.
%
% Unlike with ordinary pragma C codes, with nondet C codes there are never
% any live variables to save at the start, except for the input variables,
% and saving these is a job for the included C code. Also unlike ordinary
% pragma C codes, nondet C codes are never followed by any other code,
% so the exprn_info component of the code generator state need not be
% kept up to date.
%
% Depending on the value of options such as generate_trace, use_trail, and
% reclaim_heap_on_nondet_failure, we may need to include some code before
% the call and retry labels. The generation of this code should follow
% the same rules as the generation of similar code in nondet disjunctions.
%
% Notes:
%
% (1)	These parts are only emitted if the C code may call Mercury.
%	If a pragma c_code(will_not_call_mercury, ...) declaration was used,
%	they will not be emitted.
%
% (2)	The call to save_registers() is needed so that if the
%	C code calls Mercury code, we can call restore_registers()
%	on entry to the Mercury code (see export.m) to get the
%	right values of `sp', `hp', `curfr' and `maxfr' for the
%	recursive invocation of Mercury.
%
% (3)	The call to restore_registers() is needed in case the
%	C code calls Mercury code which allocates some data
%	on the heap, and this data is returned from Mercury
%	through C back to Mercury.  In that case, we need to
%	keep the value of `hp' that was set by the recursive
%	invocation of Mercury.  The Mercury calling convention
%	guarantees that when calling det or semidet code, the values
%	of `sp', `curfr', and `maxfr' will be preserved, so if we're
%	using conservative gc, there is nothing that needs restoring.
%
%	When calling nondet code, maxfr may be changed. This is why
%	we must call restore_registers() from the code we generate for
%	nondet pragma C codes even if we are not using conservative gc.
%
% (4)	These labels and the code following them can be optimized away
%	by the C compiler if the macro that branches to them is not invoked
%	in the preceding body of included C code. We cannot optimize them
%	away ourselves, since these macros can be invoked from other macros,
%	and thus we do not have a sure test of whether the code fragments
%	invoke the macros.
%
% (5)	We insert a #define for MR_PROC_LABEL, so that the C code in the
%	Mercury standard library that allocates memory manually can use
%	MR_PROC_LABEL as the procname argument to incr_hp_msg(), for memory
%	profiling.  Hard-coding the procname argument in the C code would
%	be wrong, since it wouldn't handle the case where the original
%	pragma c_code procedure gets inlined and optimized away.
%	Of course we also need to #undef it afterwards.

pragma_c_gen__generate_pragma_c_code(CodeModel, Attributes,
		PredId, ProcId, ArgVars, ArgDatas, OrigArgTypes, _GoalInfo,
		PragmaImpl, Code) -->
	(
		{ PragmaImpl = ordinary(C_Code, Context) },
		pragma_c_gen__ordinary_pragma_c_code(CodeModel, Attributes,
			PredId, ProcId, ArgVars, ArgDatas, OrigArgTypes,
			C_Code, Context, Code)
	;
		{ PragmaImpl = nondet(
			Fields, FieldsContext, First, FirstContext,
			Later, LaterContext, Treat, Shared, SharedContext) },
		pragma_c_gen__nondet_pragma_c_code(CodeModel, Attributes,
			PredId, ProcId, ArgVars, ArgDatas, OrigArgTypes,
			Fields, FieldsContext, First, FirstContext,
			Later, LaterContext, Treat, Shared, SharedContext,
			Code)
	).

%---------------------------------------------------------------------------%

:- pred pragma_c_gen__ordinary_pragma_c_code(code_model::in,
	pragma_c_code_attributes::in, pred_id::in, proc_id::in,
	list(prog_var)::in, list(maybe(pair(string, mode)))::in, list(type)::in,
	string::in, maybe(prog_context)::in, code_tree::out,
	code_info::in, code_info::out) is det.

pragma_c_gen__ordinary_pragma_c_code(CodeModel, Attributes,
		PredId, ProcId, ArgVars, ArgDatas, OrigArgTypes,
		C_Code, Context, Code) -->
	
	%
	% Extract the attributes
	%
	{ may_call_mercury(Attributes, MayCallMercury) },
	{ thread_safe(Attributes, ThreadSafe) },

	%
	% First we need to get a list of input and output arguments
	%
	code_info__get_pred_proc_arginfo(PredId, ProcId, ArgInfos),
	{ make_c_arg_list(ArgVars, ArgDatas, OrigArgTypes, ArgInfos, Args) },
	{ pragma_select_in_args(Args, InArgs) },
	{ pragma_select_out_args(Args, OutArgs) },

	%
	% Generate code to <save live variables on stack>
	%
	( { MayCallMercury = will_not_call_mercury } ->
		{ SaveVarsCode = empty }
	;
		% the C code might call back Mercury code
		% which clobbers the succip
		code_info__succip_is_used,

		% the C code might call back Mercury code which clobbers the
		% other registers, so we need to save any live variables
		% (other than the output args) onto the stack
		{ get_c_arg_list_vars(OutArgs, OutArgs1) },
		{ set__list_to_set(OutArgs1, OutArgsSet) },
		call_gen__save_variables(OutArgsSet, SaveVarsCode)
	),

	%
	% Generate the values of input variables.
	% (NB we need to be careful that the rvals generated here
	% remain valid below.)
	%
	get_pragma_input_vars(InArgs, InputDescs, InputVarsCode),

	%
	% For semidet pragma c_code, we have to move anything that is
	% currently in r1 elsewhere, so that the C code can assign to
	% SUCCESS_INDICATOR without clobbering anything important.
	%
	( { CodeModel = model_semi } ->
		code_info__clear_r1(ShuffleR1_Code)
	;
		{ ShuffleR1_Code = empty }
	),

	%
	% Generate <declaration of one local variable for each arg>
	%
	{ make_pragma_decls(Args, Decls) },

	%
	% Generate #define MR_PROC_LABEL <procedure label> /* see note (5) */
	% and #undef MR_PROC_LABEL
	%
	code_info__get_module_info(ModuleInfo),
	code_info__get_pred_id(CallerPredId),
	code_info__get_proc_id(CallerProcId),
	{ make_proc_label_hash_define(ModuleInfo, CallerPredId, CallerProcId,
		ProcLabelHashDefine, ProcLabelHashUndef) },

	%
	% <assignment of input values from registers to local vars>
	%
	{ InputComp = pragma_c_inputs(InputDescs) },

	%
	% save_registers(); /* see notes (1) and (2) above */
	%
	{ MayCallMercury = will_not_call_mercury ->
		SaveRegsComp = pragma_c_raw_code("")
	;
		SaveRegsComp = pragma_c_raw_code(
			"\tsave_registers();\n"
		)
	},

	%
	% Code fragments to obtain and release the global lock
	%
	{ ThreadSafe = thread_safe ->
		ObtainLock = pragma_c_raw_code(""),
		ReleaseLock = pragma_c_raw_code("")
	;
		module_info_pred_info(ModuleInfo, PredId, PredInfo),
		pred_info_name(PredInfo, Name),
		llds_out__quote_c_string(Name, MangledName),
		string__append_list(["\tMR_OBTAIN_GLOBAL_LOCK(""",
			MangledName, """);\n"], ObtainLockStr),
		ObtainLock = pragma_c_raw_code(ObtainLockStr),
		string__append_list(["\tMR_RELEASE_GLOBAL_LOCK(""",
			MangledName, """);\n"], ReleaseLockStr),
		ReleaseLock = pragma_c_raw_code(ReleaseLockStr)
	},

	%
	% <The C code itself>
	%
	{ C_Code_Comp = pragma_c_user_code(Context, C_Code) },

	%
	% <for semidet code, check of r1>
	%
	( { CodeModel = model_semi } ->
		code_info__get_next_label(FailLabel),
		{ CheckR1_Comp = pragma_c_fail_to(FailLabel) },
		{ MaybeFailLabel = yes(FailLabel) }
	;
		{ CheckR1_Comp = pragma_c_noop },
		{ MaybeFailLabel = no }
	),

	%
	% #ifndef CONSERVATIVE_GC
	%   restore_registers(); /* see notes (1) and (3) above */
	% #endif
	%
	{ MayCallMercury = will_not_call_mercury ->
		RestoreRegsComp = pragma_c_noop
	;
		RestoreRegsComp = pragma_c_raw_code(
		    "#ifndef CONSERVATIVE_GC\n\trestore_registers();\n#endif\n"
		)
	},

	%
	% The C code may have called Mercury code which clobbered the regs,
	% in which case we need to tell the code_info that they have been
	% clobbered.
	%
	( { MayCallMercury = will_not_call_mercury } ->
		[]
	;
		code_info__clear_all_registers
	),

	%
	% <assignment of the output values from local variables to registers>
	%
	pragma_acquire_regs(OutArgs, Regs),
	place_pragma_output_args_in_regs(OutArgs, Regs, OutputDescs),
	{ OutputComp = pragma_c_outputs(OutputDescs) },

	%
	% join all the components of the pragma_c together
	%
	{ Components = [ProcLabelHashDefine, InputComp, SaveRegsComp,
			ObtainLock, C_Code_Comp, ReleaseLock,
			CheckR1_Comp, RestoreRegsComp,
			OutputComp, ProcLabelHashUndef] },
	{ PragmaCCode = node([
		pragma_c(Decls, Components, MayCallMercury, no,
			MaybeFailLabel, no)
			- "Pragma C inclusion"
	]) },

	%
	% for semidet code, we need to insert the failure handling code here:
	%
	%	goto skip_label;
	%	fail_label:
	%	<code to fail>
	%	skip_label:
	%
	( { MaybeFailLabel = yes(TheFailLabel) } ->
		code_info__get_next_label(SkipLabel),
		code_info__generate_failure(FailCode),
		{ GotoSkipLabelCode = node([
			goto(label(SkipLabel)) - "Skip past failure code"
		]) },
		{ SkipLabelCode = node([ label(SkipLabel) - "" ]) },
		{ FailLabelCode = node([ label(TheFailLabel) - "" ]) },
		{ FailureCode =
			tree(GotoSkipLabelCode,
			tree(FailLabelCode,
			tree(FailCode,
			     SkipLabelCode)))
		}
	;
		{ FailureCode = empty }
	),

	%
	% join all code fragments together
	%
	{ Code =
		tree(SaveVarsCode,
		tree(InputVarsCode,
		tree(ShuffleR1_Code, 
		tree(PragmaCCode,
		     FailureCode))))
	}.

:- pred make_proc_label_hash_define(module_info, pred_id, proc_id,
		pragma_c_component, pragma_c_component).
:- mode make_proc_label_hash_define(in, in, in, out, out) is det.

make_proc_label_hash_define(ModuleInfo, PredId, ProcId,
		ProcLabelHashDef, ProcLabelHashUndef) :-
	code_util__make_entry_label(ModuleInfo, PredId, ProcId, no,
		CodeAddr),
	( CodeAddr = imported(ProcLabel) ->
		llds_out__get_proc_label(ProcLabel, yes, ProcLabelString)
	; CodeAddr = label(ProcLabel) ->
		llds_out__get_label(ProcLabel, yes, ProcLabelString)
	;
		error("unexpected code_addr in make_proc_label_hash_define")
	),
	ProcLabelHashDef = pragma_c_raw_code(string__append_list([
			"#define MR_PROC_LABEL ", ProcLabelString, "\n"])),
	ProcLabelHashUndef = pragma_c_raw_code("#undef MR_PROC_LABEL\n").

%-----------------------------------------------------------------------------%

:- pred pragma_c_gen__nondet_pragma_c_code(code_model::in,
	pragma_c_code_attributes::in, pred_id::in, proc_id::in,
	list(prog_var)::in, list(maybe(pair(string, mode)))::in, list(type)::in,
	string::in, maybe(prog_context)::in,
	string::in, maybe(prog_context)::in,
	string::in, maybe(prog_context)::in, pragma_shared_code_treatment::in,
	string::in, maybe(prog_context)::in, code_tree::out,
	code_info::in, code_info::out) is det.

pragma_c_gen__nondet_pragma_c_code(CodeModel, Attributes,
		PredId, ProcId, ArgVars, ArgDatas, OrigArgTypes,
		_Fields, _FieldsContext, First, FirstContext,
		Later, LaterContext, Treat, Shared, SharedContext, Code) -->
	{ require(unify(CodeModel, model_non),
		"inappropriate code model for nondet pragma C code") },
	%
	% Extract the may_call_mercury attribute
	%
	{ may_call_mercury(Attributes, MayCallMercury) },

	%
	% Generate #define MR_PROC_LABEL <procedure label> /* see note (5) */
	% and #undef MR_PROC_LABEL
	%
	code_info__get_module_info(ModuleInfo),
	code_info__get_pred_id(CallerPredId),
	code_info__get_proc_id(CallerProcId),
	{ make_proc_label_hash_define(ModuleInfo, CallerPredId, CallerProcId,
		ProcLabelDefine, ProcLabelUndef) },

	%
	% Get a list of input and output arguments
	%
	code_info__get_pred_proc_arginfo(PredId, ProcId, ArgInfos),
	{ make_c_arg_list(ArgVars, ArgDatas, OrigArgTypes, ArgInfos, Args) },
	{ pragma_select_in_args(Args, InArgs) },
	{ pragma_select_out_args(Args, OutArgs) },
	{ make_pragma_decls(Args, Decls) },
	{ make_pragma_decls(OutArgs, OutDecls) },

	{ input_descs_from_arg_info(InArgs, InputDescs) },
	{ output_descs_from_arg_info(OutArgs, OutputDescs) },

	{ module_info_pred_info(ModuleInfo, PredId, PredInfo) },
	{ pred_info_module(PredInfo, ModuleName) },
	{ pred_info_name(PredInfo, PredName) },
	{ pred_info_arity(PredInfo, Arity) },
	{ pragma_c_gen__struct_name(ModuleName, PredName, Arity, ProcId,
		StructName) },
	{ SaveStructDecl = pragma_c_struct_ptr_decl(StructName, "LOCALS") },
	{ string__format("\tLOCALS = (struct %s *) ((char *)
		(MR_curfr + 1 - MR_ORDINARY_SLOTS - MR_NONDET_FIXED_SIZE)
		- sizeof(struct %s));\n",
		[s(StructName), s(StructName)],
		InitSaveStruct) },

	code_info__get_next_label(RetryLabel),
	{ ModFrameCode = node([
		assign(redoip(lval(curfr)),
			const(code_addr_const(label(RetryLabel))))
			- "Set up backtracking to retry label"
	]) },
	{ RetryLabelCode = node([
		label(RetryLabel) -
			"Start of the retry block"
	]) },

	code_info__get_globals(Globals),

	{ globals__lookup_bool_option(Globals, reclaim_heap_on_nondet_failure,
		ReclaimHeap) },
	code_info__maybe_save_hp(ReclaimHeap, SaveHeapCode, MaybeHpSlot),
	code_info__maybe_restore_hp(MaybeHpSlot, RestoreHeapCode),

	{ globals__lookup_bool_option(Globals, use_trail, UseTrail) },
	code_info__maybe_save_ticket(UseTrail, SaveTicketCode, MaybeTicketSlot),
	code_info__maybe_reset_ticket(MaybeTicketSlot, undo, RestoreTicketCode),

	{ FirstContext = yes(FirstContextPrime) ->
		ActualFirstContext = FirstContextPrime
	;
		term__context_init(ActualFirstContext)
	},
	trace__maybe_generate_pragma_event_code(nondet_pragma_first,
		ActualFirstContext, FirstTraceCode),
	{ LaterContext = yes(LaterContextPrime) ->
		ActualLaterContext = LaterContextPrime
	;
		term__context_init(ActualLaterContext)
	},
	trace__maybe_generate_pragma_event_code(nondet_pragma_later,
		ActualLaterContext, LaterTraceCode),

	{ FirstDisjunctCode =
		tree(SaveHeapCode,
		tree(SaveTicketCode,
		     FirstTraceCode))
	},
	{ LaterDisjunctCode =
		tree(RestoreHeapCode,
		tree(RestoreTicketCode,
		     LaterTraceCode))
	},

	%
	% save_registers(); /* see notes (1) and (2) above */
	%
	{ MayCallMercury = will_not_call_mercury ->
		SaveRegs = ""
	;
		SaveRegs = "\tsave_registers();\n"
	},

	%
	% restore_registers(); /* see notes (1) and (3) above */
	%
	{ MayCallMercury = will_not_call_mercury ->
		RestoreRegs = ""
	;
		RestoreRegs = "\trestore_registers();\n"
	},

	{
	Succeed	 = "\tMR_succeed();\n",
	SucceedDiscard = "\tMR_succeed_discard();\n",

	CallDef1 = "#define\tSUCCEED     \tgoto MR_call_success\n",
	CallDef2 = "#define\tSUCCEED_LAST\tgoto MR_call_success_last\n",
	CallDef3 = "#define\tFAIL\tMR_fail()\n",

	CallSuccessLabel     = "MR_call_success:\n",
	CallLastSuccessLabel = "MR_call_success_last:\n",

	RetryDef1 = "#define\tSUCCEED     \tgoto MR_retry_success\n",
	RetryDef2 = "#define\tSUCCEED_LAST\tgoto MR_retry_success_last\n",
	RetryDef3 = "#define\tFAIL\tMR_fail()\n",

	RetrySuccessLabel     = "MR_retry_success:\n",
	RetryLastSuccessLabel = "MR_retry_success_last:\n",

	Undef1 = "#undef\tSUCCEED\n",
	Undef2 = "#undef\tSUCCEED_LAST\n",
	Undef3 = "#undef\tFAIL\n"
	},

	(
			% Use the form that duplicates the common code
			% if the programmer asked for it, or if the code
			% is small enough for its duplication not to have
			% a significant effect on code size. (This form
			% generates slightly faster code.)
			% However, if `pragma no_inline' is specified,
			% then we don't duplicate the code unless the
			% programmer asked for it -- the code may contain
			% static variable declarations, so duplicating it
			% could change the semantics.

			% We use the number of semicolons in the code
			% as an indication how many C statements it has
			% and thus how big its object code is likely to be.
		{
			Treat = duplicate
		;
			Treat = automatic,
			\+ pred_info_requested_no_inlining(PredInfo),
			CountSemis = lambda([Char::in, Count0::in, Count::out]
				is det,
				( Char = (;) ->
					Count is Count0 + 1
				;
					Count = Count0
				)
			),
			string__foldl(CountSemis, Shared, 0, Semis),
			Semis < 32
		}
	->
		{
		CallDecls = [SaveStructDecl | Decls],
		CallComponents = [
			pragma_c_inputs(InputDescs),
			pragma_c_raw_code(InitSaveStruct),
			pragma_c_raw_code(SaveRegs),
			ProcLabelDefine,
			pragma_c_raw_code(CallDef1),
			pragma_c_raw_code(CallDef2),
			pragma_c_raw_code(CallDef3),
			pragma_c_user_code(FirstContext, First),
			pragma_c_user_code(SharedContext, Shared),
			pragma_c_raw_code(CallSuccessLabel),
			pragma_c_raw_code(RestoreRegs),
			pragma_c_outputs(OutputDescs),
			pragma_c_raw_code(Succeed),
			pragma_c_raw_code(CallLastSuccessLabel),
			pragma_c_raw_code(RestoreRegs),
			pragma_c_outputs(OutputDescs),
			pragma_c_raw_code(SucceedDiscard),
			pragma_c_raw_code(Undef1),
			pragma_c_raw_code(Undef2),
			pragma_c_raw_code(Undef3),
			ProcLabelUndef
		],
		CallBlockCode = node([
			pragma_c(CallDecls, CallComponents,
				MayCallMercury, no, no, yes)
				- "Call and shared pragma C inclusion"
		]),

		RetryDecls = [SaveStructDecl | OutDecls],
		RetryComponents = [
			pragma_c_raw_code(InitSaveStruct),
			pragma_c_raw_code(SaveRegs),
			ProcLabelDefine,
			pragma_c_raw_code(RetryDef1),
			pragma_c_raw_code(RetryDef2),
			pragma_c_raw_code(RetryDef3),
			pragma_c_user_code(LaterContext, Later),
			pragma_c_user_code(SharedContext, Shared),
			pragma_c_raw_code(RetrySuccessLabel),
			pragma_c_raw_code(RestoreRegs),
			pragma_c_outputs(OutputDescs),
			pragma_c_raw_code(Succeed),
			pragma_c_raw_code(RetryLastSuccessLabel),
			pragma_c_raw_code(RestoreRegs),
			pragma_c_outputs(OutputDescs),
			pragma_c_raw_code(SucceedDiscard),
			pragma_c_raw_code(Undef1),
			pragma_c_raw_code(Undef2),
			pragma_c_raw_code(Undef3),
			ProcLabelUndef
		],
		RetryBlockCode = node([
			pragma_c(RetryDecls, RetryComponents,
				MayCallMercury, no, no, yes)
				- "Retry and shared pragma C inclusion"
		]),

		Code =
			tree(ModFrameCode,
			tree(FirstDisjunctCode,
			tree(CallBlockCode,
			tree(RetryLabelCode, 
			tree(LaterDisjunctCode, 
			     RetryBlockCode)))))
		}
	;
		code_info__get_next_label(SharedLabel),
		{
		SharedLabelCode = node([
			label(SharedLabel) -
				"Start of the shared block"
		]),

		SharedDef1 = "#define\tSUCCEED     \tgoto MR_shared_success\n",
		SharedDef2 = "#define\tSUCCEED_LAST\tgoto MR_shared_success_last\n",
		SharedDef3 = "#define\tFAIL\tMR_fail()\n",

		SharedSuccessLabel     = "MR_shared_success:\n",
		SharedLastSuccessLabel = "MR_shared_success_last:\n",

		llds_out__get_label(SharedLabel, yes, LabelStr),
		string__format("\tGOTO_LABEL(%s);\n", [s(LabelStr)],
			GotoSharedLabel),

		CallDecls = [SaveStructDecl | Decls],
		CallComponents = [
			pragma_c_inputs(InputDescs),
			pragma_c_raw_code(InitSaveStruct),
			pragma_c_raw_code(SaveRegs),
			ProcLabelDefine,
			pragma_c_raw_code(CallDef1),
			pragma_c_raw_code(CallDef2),
			pragma_c_raw_code(CallDef3),
			pragma_c_user_code(FirstContext, First),
			pragma_c_raw_code(GotoSharedLabel),
			pragma_c_raw_code(CallSuccessLabel),
			pragma_c_raw_code(RestoreRegs),
			pragma_c_outputs(OutputDescs),
			pragma_c_raw_code(Succeed),
			pragma_c_raw_code(CallLastSuccessLabel),
			pragma_c_raw_code(RestoreRegs),
			pragma_c_outputs(OutputDescs),
			pragma_c_raw_code(SucceedDiscard),
			pragma_c_raw_code(Undef1),
			pragma_c_raw_code(Undef2),
			pragma_c_raw_code(Undef3),
			ProcLabelUndef
		],
		CallBlockCode = node([
			pragma_c(CallDecls, CallComponents,
				MayCallMercury, yes(SharedLabel), no, yes)
				- "Call pragma C inclusion"
		]),

		RetryDecls = [SaveStructDecl | OutDecls],
		RetryComponents = [
			pragma_c_raw_code(InitSaveStruct),
			pragma_c_raw_code(SaveRegs),
			ProcLabelDefine,
			pragma_c_raw_code(RetryDef1),
			pragma_c_raw_code(RetryDef2),
			pragma_c_raw_code(RetryDef3),
			pragma_c_user_code(LaterContext, Later),
			pragma_c_raw_code(GotoSharedLabel),
			pragma_c_raw_code(RetrySuccessLabel),
			pragma_c_raw_code(RestoreRegs),
			pragma_c_outputs(OutputDescs),
			pragma_c_raw_code(Succeed),
			pragma_c_raw_code(RetryLastSuccessLabel),
			pragma_c_raw_code(RestoreRegs),
			pragma_c_outputs(OutputDescs),
			pragma_c_raw_code(SucceedDiscard),
			pragma_c_raw_code(Undef1),
			pragma_c_raw_code(Undef2),
			pragma_c_raw_code(Undef3),
			ProcLabelUndef
		],
		RetryBlockCode = node([
			pragma_c(RetryDecls, RetryComponents,
				MayCallMercury, yes(SharedLabel), no, yes)
				- "Retry pragma C inclusion"
		]),

		SharedDecls = [SaveStructDecl | OutDecls],
		SharedComponents = [
			pragma_c_raw_code(InitSaveStruct),
			pragma_c_raw_code(SaveRegs),
			ProcLabelDefine,
			pragma_c_raw_code(SharedDef1),
			pragma_c_raw_code(SharedDef2),
			pragma_c_raw_code(SharedDef3),
			pragma_c_user_code(SharedContext, Shared),
			pragma_c_raw_code(SharedSuccessLabel),
			pragma_c_raw_code(RestoreRegs),
			pragma_c_outputs(OutputDescs),
			pragma_c_raw_code(Succeed),
			pragma_c_raw_code(SharedLastSuccessLabel),
			pragma_c_raw_code(RestoreRegs),
			pragma_c_outputs(OutputDescs),
			pragma_c_raw_code(SucceedDiscard),
			pragma_c_raw_code(Undef1),
			pragma_c_raw_code(Undef2),
			pragma_c_raw_code(Undef3),
			ProcLabelUndef
		],
		SharedBlockCode = node([
			pragma_c(SharedDecls, SharedComponents,
				MayCallMercury, no, no, yes)
				- "Shared pragma C inclusion"
		]),

		Code =
			tree(ModFrameCode,
			tree(FirstDisjunctCode,
			tree(CallBlockCode,
			tree(RetryLabelCode, 
			tree(LaterDisjunctCode, 
			tree(RetryBlockCode,
			tree(SharedLabelCode, 
			     SharedBlockCode)))))))
		}
	).

%---------------------------------------------------------------------------%

:- type c_arg
	--->	c_arg(
			prog_var,
			maybe(string),	% name
			type,		% original type before
					% inlining/specialization
					% (the actual type may be an instance
					% of this type, if this type is
					% polymorphic).
			arg_info
		).

:- pred make_c_arg_list(list(prog_var)::in, list(maybe(pair(string, mode)))::in,
		list(type)::in, list(arg_info)::in, list(c_arg)::out) is det.

make_c_arg_list(Vars, ArgDatas, Types, ArgInfos, ArgList) :-
	(
		Vars = [],
		ArgDatas = [],
		Types = [],
		ArgInfos = []
	->
		ArgList = []
	;
		Vars = [V|Vs],
		ArgDatas = [MN|Ns],
		Types = [T|Ts],
		ArgInfos = [A|As]
	->
		(
			MN = yes(Name - _),
			N = yes(Name)
		;
			MN = no,
			N = no
		),
		Arg = c_arg(V, N, T, A),
		make_c_arg_list(Vs, Ns, Ts, As, Args),
		ArgList = [Arg | Args]
	;
		error("pragma_c_gen:make_c_arg_list - length mismatch")
	).

:- pred get_c_arg_list_vars(list(c_arg)::in, list(prog_var)::out) is det.

get_c_arg_list_vars([], []).
get_c_arg_list_vars([Arg | Args], [Var | Vars]) :-
	Arg = c_arg(Var, _, _, _),
	get_c_arg_list_vars(Args, Vars).

%---------------------------------------------------------------------------%

% pragma_select_out_args returns the list of variables which are outputs for
% a procedure

:- pred pragma_select_out_args(list(c_arg)::in, list(c_arg)::out) is det.

pragma_select_out_args([], []).
pragma_select_out_args([Arg | Rest], Out) :-
        pragma_select_out_args(Rest, Out0),
	Arg = c_arg(_, _, _, ArgInfo),
	ArgInfo = arg_info(_Loc, Mode),
        (
                Mode = top_out
        ->
                Out = [Arg | Out0]
        ;
                Out = Out0
        ).

% pragma_select_in_args returns the list of variables which are inputs for
% a procedure

:- pred pragma_select_in_args(list(c_arg)::in, list(c_arg)::out) is det.

pragma_select_in_args([], []).
pragma_select_in_args([Arg | Rest], In) :-
        pragma_select_in_args(Rest, In0),
	Arg = c_arg(_, _, _, ArgInfo),
	ArgInfo = arg_info(_Loc, Mode),
        (
                Mode = top_in
        ->
		In = [Arg | In0]
        ;
                In = In0
        ).

%---------------------------------------------------------------------------%

% var_is_not_singleton determines whether or not a given pragma_c variable
% is singleton (i.e. starts with an underscore) or anonymous (in which case
% it's singleton anyway, it just doesn't necessarily have a singleton name).
%
% Singleton vars should be ignored when generating the declarations for
% pragma_c arguments because:
%
%	- they should not appear in the C code
% 	- they could clash with the system name space
%

:- pred var_is_not_singleton(maybe(string), string) is semidet.
:- mode var_is_not_singleton(in, out) is semidet.

var_is_not_singleton(yes(Name), Name) :-
	\+ string__first_char(Name, '_', _).

%---------------------------------------------------------------------------%

% make_pragma_decls returns the list of pragma_decls for the pragma_c
% data structure in the LLDS. It is essentially a list of pairs of type and
% variable name, so that declarations of the form "Type Name;" can be made.

:- pred make_pragma_decls(list(c_arg)::in, list(pragma_c_decl)::out) is det.

make_pragma_decls([], []).
make_pragma_decls([Arg | Args], Decls) :-
	Arg = c_arg(_Var, ArgName, OrigType, _ArgInfo),
	(
		var_is_not_singleton(ArgName, Name)
	->
		Decl = pragma_c_arg_decl(OrigType, Name),
		make_pragma_decls(Args, Decls1),
		Decls = [Decl | Decls1]
	;
		% if the variable doesn't occur in the ArgNames list,
		% it can't be used, so we just ignore it
		make_pragma_decls(Args, Decls)
	).

%---------------------------------------------------------------------------%

% get_pragma_input_vars returns a list of pragma_c_inputs for the pragma_c
% data structure in the LLDS. It is essentially a list of the input variables,
% and the corresponding rvals assigned to those (C) variables.

:- pred get_pragma_input_vars(list(c_arg)::in, list(pragma_c_input)::out,
		code_tree::out, code_info::in, code_info::out) is det.

get_pragma_input_vars([], [], empty) --> [].
get_pragma_input_vars([Arg | Args], Inputs, Code) -->
	{ Arg = c_arg(Var, MaybeName, Type, _ArgInfo) },
	(
		{ var_is_not_singleton(MaybeName, Name) }
	->
		code_info__produce_variable(Var, Code0, Rval),
		{ Input = pragma_c_input(Name, Type, Rval) },
		get_pragma_input_vars(Args, Inputs1, Code1),
		{ Inputs = [Input | Inputs1] },
		{ Code = tree(Code0, Code1) }
	;
		% if the variable doesn't occur in the ArgNames list,
		% it can't be used, so we just ignore it
		get_pragma_input_vars(Args, Inputs, Code)
	).

%---------------------------------------------------------------------------%

% pragma_acquire_regs acquires a list of registers in which to place each
% of the given arguments.

:- pred pragma_acquire_regs(list(c_arg)::in, list(lval)::out,
	code_info::in, code_info::out) is det.

pragma_acquire_regs([], []) --> [].
pragma_acquire_regs([Arg | Args], [Reg | Regs]) -->
	{ Arg = c_arg(Var, _, _, _) },
	code_info__acquire_reg_for_var(Var, Reg),
	pragma_acquire_regs(Args, Regs).

%---------------------------------------------------------------------------%

% place_pragma_output_args_in_regs returns a list of pragma_c_outputs, which
% are pairs of names of output registers and (C) variables which hold the
% output value.

:- pred place_pragma_output_args_in_regs(list(c_arg)::in, list(lval)::in,
	list(pragma_c_output)::out, code_info::in, code_info::out) is det.

place_pragma_output_args_in_regs([], [], []) --> [].
place_pragma_output_args_in_regs([Arg | Args], [Reg | Regs], Outputs) -->
	{ Arg = c_arg(Var, MaybeName, OrigType, _ArgInfo) },
	code_info__release_reg(Reg),
	code_info__set_var_location(Var, Reg),
	{
		var_is_not_singleton(MaybeName, Name)
	->
		Outputs = [pragma_c_output(Reg, OrigType, Name) | Outputs0]
	;
		Outputs = Outputs0
	},
	place_pragma_output_args_in_regs(Args, Regs, Outputs0).
place_pragma_output_args_in_regs([_|_], [], _) -->
	{ error("place_pragma_output_args_in_regs: length mismatch") }.
place_pragma_output_args_in_regs([], [_|_], _) -->
	{ error("place_pragma_output_args_in_regs: length mismatch") }.

%---------------------------------------------------------------------------%

% input_descs_from_arg_info returns a list of pragma_c_inputs, which
% are pairs of rvals and (C) variables which receive the input value.

:- pred input_descs_from_arg_info(list(c_arg)::in, list(pragma_c_input)::out)
	is det.

input_descs_from_arg_info([], []).
input_descs_from_arg_info([Arg | Args], Inputs) :-
	Arg = c_arg(_Var, MaybeName, OrigType, ArgInfo),
	(
		var_is_not_singleton(MaybeName, Name)
	->
		ArgInfo = arg_info(N, _),
		Reg = reg(r, N),
		Input = pragma_c_input(Name, OrigType, lval(Reg)),
		Inputs = [Input | Inputs1],
		input_descs_from_arg_info(Args, Inputs1)
	;
		input_descs_from_arg_info(Args, Inputs)
	).

%---------------------------------------------------------------------------%

% output_descs_from_arg_info returns a list of pragma_c_outputs, which
% are pairs of names of output registers and (C) variables which hold the
% output value.

:- pred output_descs_from_arg_info(list(c_arg)::in, list(pragma_c_output)::out)
	is det.

output_descs_from_arg_info([], []).
output_descs_from_arg_info([Arg | Args], Outputs) :-
	Arg = c_arg(_Var, MaybeName, OrigType, ArgInfo),
	(
		var_is_not_singleton(MaybeName, Name)
	->
		ArgInfo = arg_info(N, _),
		Reg = reg(r, N),
		Outputs = [pragma_c_output(Reg, OrigType, Name) | Outputs0]
	;
		Outputs = Outputs0
	),
	output_descs_from_arg_info(Args, Outputs0).

%---------------------------------------------------------------------------%

pragma_c_gen__struct_name(ModuleName, PredName, Arity, ProcId, StructName) :-
	llds_out__sym_name_mangle(ModuleName, MangledModuleName),
	llds_out__name_mangle(PredName, MangledPredName),
	proc_id_to_int(ProcId, ProcNum),
	string__int_to_string(Arity, ArityStr),
	string__int_to_string(ProcNum, ProcNumStr),
	string__append_list(["mercury_save__", MangledModuleName, "__",
		MangledPredName, "__", ArityStr, "_", ProcNumStr], StructName).

%---------------------------------------------------------------------------%
