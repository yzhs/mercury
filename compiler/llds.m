%-----------------------------------------------------------------------------%

% LLDS - The Low-Level Data Structure.

% Main authors: conway, fjh.

%-----------------------------------------------------------------------------%

:- module llds.		
:- interface.
:- import_module io, std_util, list, term, string, int.
		% and float, eventually.

%-----------------------------------------------------------------------------%

:- type c_file		--->	c_file(string, list(c_module)).
			%	filename, modules

:- type c_module	--->	c_module(string, list(c_procedure)).
			%	module name, code

:- type c_procedure	--->	c_procedure(string, int, llds__proc_id,
						list(instruction)).
			%	predicate name, arity, mode, code
:- type llds__proc_id == int.

:- type instruction	==	pair(instr, string).
			%	 instruction, comment

:- type instr		--->	comment(string)
			;	assign(lval, rval)
			;	call(code_addr, label)  % pred, continuation
			;	entrycall(code_addr, label) % pred, continuation
			;	unicall(unilabel, label)  % pred, continuation
			;	tailcall(code_addr)
			;	proceed
			;	succeed
			;	fail
			;	redo
			;	mkframe(string, int, maybe(label))
			;	modframe(maybe(label))
			;	label(label)
			;	unilabel(unilabel)	% XXX fixme!
			;	goto(label)
			;	c_code(string)	% insert arbitrary C code
			;	if_val(rval, label)
					% if rval evaluates to TRUE
					% then branch to label
			;	incr_sp(int)
			;	decr_sp(int)
			;	incr_hp(int).

:- type lval		--->	reg(reg)	% either an int or float reg
			;	stackvar(int)	% det stack slots
			;	framevar(int)	% nondet stack slots
			;	succip
			;	maxfr
			;	curredoip
			;	hp
			;	sp
			;	field(tag, lval, int)
			;	lvar(var).

:- type rval		--->	lval(lval)
			;	var(var)
			;	create(tag, list(rval))
			;	mkword(tag, rval)
			;	mktag(rval)
			;	tag(rval)
			;	mkbody(rval)
			;	body(rval)
			;	iconst(int)		% integer constants
			;	sconst(string)		% string constants
			;       field(tag, rval, int)
			;	binop(operator, rval, rval)
			;	not(rval)
			;	true
			;	false
			;	unused.

:- type operator	--->	(+)
			;	(-)
			;	(*)
			;	(/)
			;	(mod)
			;	and	% logical and
			;	or	% logical or
			;	eq	% ==
			;	ne	% !=
			;	streq	% string equality
			;	(<)
			;	(>)
			;	(<=)
			;	(>=).

:- type reg		--->	r(int)		% integer regs
			;	f(int).		% floating point regs

:- type code_addr 	--->	nonlocal(string, string, int, int)
				%	module, predicate, arity, mode #
			;	local(label).

:- type label 		--->	entrylabel(string, string, int, int)
				%	 module, predicate, arity, mode #
			;	label(string, string, int, int, int).
				% module, predicate, arity, mode #, #

:- type unilabel	--->	unilabel(string, string, int, int).
				% module, predicate, arity, mode #

:- type tag		==	int.

	% Given a 'c_file' structure, open the appropriate .mod file
	% and output the code into that file.

:- pred output_c_file(c_file, io__state, io__state).
:- mode output_c_file(in, di, uo) is det.

	% Convert an lval to a string description of that lval.

:- pred llds__lval_to_string(lval, string).
:- mode llds__lval_to_string(in, out) is semidet.

%-----------------------------------------------------------------------------%

:- implementation.
:- import_module require, globals, options.

%-----------------------------------------------------------------------------%

	% The following code is very straightforward and
	% unremarkable.  The only thing of note is that is
	% uses the logical io library, and that it uses DCGs
	% to avoid having to explicitly shuffle the state-of-the-world
	% arguments around all the time, as discussed in my hons thesis. -fjh.

output_c_file(c_file(Name, Modules)) -->
	{ string__append(Name, ".mod", FileName) },
	io__tell(FileName, Result),
	(
		{ Result = ok }
	->
		io__write_string("#include \"imp.h\"\n"),
		output_c_module_list(Modules),
		io__told
	;
		io__progname("llds.nl", ProgName),
		io__write_string("\n"),
		io__write_string(ProgName),
		io__write_string(": can't open `"),
		io__write_string(FileName),
		io__write_string("' for output\n")
	).

:- pred output_c_module_list(list(c_module), io__state, io__state).
:- mode output_c_module_list(in, di, uo) is det.

output_c_module_list([]) --> [].
output_c_module_list([M|Ms]) -->
	output_c_module(M),
	output_c_module_list(Ms).

:- pred output_c_module(c_module, io__state, io__state).
:- mode output_c_module(in, di, uo) is det.

output_c_module(c_module(Name,Predicates)) -->
	io__write_string("\n"),
	io__write_string("/* this code automatically generated - do no edit.*/\n"),
	io__write_string("\n"),
	io__write_string("BEGIN_MODULE("),
	io__write_string(Name),
	io__write_string(")\n"),
	io__write_string("\t/* no module initialization in automatically generated code */\n"),
	io__write_string("BEGIN_CODE\n"),
	io__write_string("\n"),
	output_c_procedure_list(Predicates),
	io__write_string("END_MODULE\n").

:- pred output_c_procedure_list(list(c_procedure), io__state, io__state).
:- mode output_c_procedure_list(in, di, uo) is det.

output_c_procedure_list([]) --> [].
output_c_procedure_list([P|Ps]) -->
	output_c_procedure(P),
	output_c_procedure_list(Ps).

:- pred output_c_procedure(c_procedure, io__state, io__state).
:- mode output_c_procedure(in, di, uo) is det.

output_c_procedure(c_procedure(Name,Arity,Mode,Instructions)) -->
	io__write_string("/*-------------------------------------"),
	io__write_string("------------------------------------*/\n"),
	io__write_string("/* code for predicate "),
	io__write_string(Name),
	io__write_string("/"),
	io__write_int(Arity),
	io__write_string(" in mode "),
	io__write_int(Mode),
	io__write_string(" */\n"),
	output_instruction_list(Instructions).

:- pred output_instruction_list(list(instruction), io__state, io__state).
:- mode output_instruction_list(in, di, uo) is det.

output_instruction_list([]) --> [].
output_instruction_list([Inst - Comment|Instructions]) -->
	output_instruction(Inst),
	io__write_string("\n"),
	globals__io_lookup_bool_option(mod_comments, PrintModComments),
	(
		{ Comment \= "" },
		{ PrintModComments = yes }
	->
		io__write_string("\t\t/* "),
		io__write_string(Comment),
		io__write_string(" */\n")
	;
		[]
	),
	output_instruction_list(Instructions).

:- pred output_instruction(instr, io__state, io__state).
:- mode output_instruction(in, di, uo) is det.

output_instruction(comment(Comment)) -->
	globals__io_lookup_bool_option(mod_comments, PrintModComments),
	(
		{ Comment \= "" },
		{ PrintModComments = yes }
	->
		io__write_strings(["/* ", Comment, " */"])
	;
		[]
	).

output_instruction(assign(Lval, Rval)) -->
	io__write_string("\t"),
	output_lval(Lval),
	io__write_string(" = "),
	output_rval(Rval),
	io__write_string(";").

output_instruction(call(CodeAddress, ContLabel)) -->
	io__write_string("\t"),
	io__write_string("call("),
	output_code_address(CodeAddress),
	io__write_string(", LABEL("),
	output_label(ContLabel),
	io__write_string("));").

output_instruction(entrycall(CodeAddress, ContLabel)) -->
	io__write_string("\t"),
	io__write_string("callentry("),
	output_code_address(CodeAddress),
	io__write_string(", LABEL("),
	output_label(ContLabel),
	io__write_string("));").

output_instruction(unicall(Label, ContLabel)) -->
	io__write_string("\t"),
	io__write_string("call(LABEL("),
	output_unilabel(Label),
	io__write_string("), LABEL("),
	output_label(ContLabel),
	io__write_string("));").

output_instruction(tailcall(CodeAddress)) -->
	io__write_string("\t"),
	io__write_string("tailcall("),
	output_code_address(CodeAddress),
	io__write_string(");").

output_instruction(proceed) -->
	io__write_string("\t"),
	io__write_string("proceed();").

output_instruction(succeed) -->
	io__write_string("\t"),
	io__write_string("succeed();").

output_instruction(redo) -->
	io__write_string("\t"),
	io__write_string("redo();").

output_instruction(fail) -->
	io__write_string("\t"),
	io__write_string("fail();").

output_instruction(c_code(C_Code_String)) -->
	io__write_string("\t"),
	io__write_string(C_Code_String).

output_instruction(mkframe(Str, Num, Maybe)) -->
	io__write_string("\t"),
	io__write_string("mkframe(\""),
	io__write_string(Str),
	io__write_string("\", "),
	io__write_int(Num),
	io__write_string(", "),
	(
		{ Maybe = yes(Label) }
	->
		io__write_string("LABEL("),
		output_label(Label),
		io__write_string(")")
	;
		io__write_string("dofail")
	),
	io__write_string(");").

output_instruction(modframe(Maybe)) -->
	io__write_string("\t"),
	io__write_string("modframe("),
	(
		{ Maybe = yes(Label) }
	->
		io__write_string("LABEL("),
		output_label(Label),
		io__write_string(")")
	;
		io__write_string("dofail")
	),
	io__write_string(");").

output_instruction(label(Label)) -->
	output_label(Label),
	io__write_string(":\n\t;").
	
output_instruction(unilabel(Label)) -->
	output_unilabel(Label),
	io__write_string(":\n\t;").

output_instruction(goto(Label)) -->
	io__write_string("\t"),
	io__write_string("GOTO_LABEL("),
	output_label(Label),
	io__write_string(");").

output_instruction(if_val(Rval, Label)) -->
	io__write_string("\t"),
	io__write_string("if( "),
	output_rval(Rval),
	io__write_string(" ) \n\t\tGOTO_LABEL("),
	output_label(Label),
	io__write_string(");").

output_instruction(incr_sp(N)) -->
	io__write_string("\t"),
	io__write_string("incr_sp("),
	io__write_int(N),
	io__write_string(");").
output_instruction(decr_sp(N)) -->
	io__write_string("\t"),
	io__write_string("decr_sp("),
	io__write_int(N),
	io__write_string(");").

output_instruction(incr_hp(N)) -->
	io__write_string("\t"),
	io__write_string("incr_hp("),
	io__write_int(N),
	io__write_string(");").

:- pred output_code_address(code_addr, io__state, io__state).
:- mode output_code_address(in, di, uo) is det.

output_code_address(local(Label)) -->
	io__write_string("LABEL("),
	output_label(Label),
	io__write_string(")").

	% XXX we need to do something with the module name.

output_code_address(nonlocal(_Module, Pred, Arity, Mode)) -->
	io__write_string("\t"),
	%%% io__write_string("ENTRY("),
	%%% io__write_string(Module),
	output_label_prefix,
	io__write_string(Pred),
	io__write_string("_"),
	io__write_int(Arity),
	io__write_string("_"),
	io__write_int(Mode).
	%%% io__write_string(")").

:- pred output_label(label, io__state, io__state).
:- mode output_label(in, di, uo) is det.

output_label(entrylabel(_Module, Pred, Arity, Mode)) -->
	output_label_prefix,
	%%% io__write_string(Module),
	io__write_string(Pred),
	io__write_string("_"),
	io__write_int(Arity),
	io__write_string("_"),
	io__write_int(Mode).
output_label(label(_Module, Pred, Arity, Mode, Num)) -->
	output_label_prefix,
	%%% io__write_string(Module),
	io__write_string(Pred),
	io__write_string("_"),
	io__write_int(Arity),
	io__write_string("_"),
	io__write_int(Mode),
	io__write_string("_i"),		% i for "internal" (not Intel ;-)
	io__write_int(Num).

:- pred output_unilabel(unilabel, io__state, io__state).
:- mode output_unilabel(in, di, uo) is det.

output_unilabel(unilabel(_Module, TypeName, TypeArity, ModeNum)) -->
	output_label_prefix,
	%%% io__write_string(Module),
	io__write_string(TypeName),
	io__write_string("_"),
	io__write_int(TypeArity),
	io__write_string("_"),
	io__write_int(ModeNum).

	% To ensure that Mercury labels don't clash with C symbols, we
	% prefix them with `mercury__'.

:- pred output_label_prefix(io__state, io__state).
:- mode output_label_prefix(di, uo) is det.

output_label_prefix -->
	io__write_string("mercury"),
	io__write_string("__").

:- pred output_reg(reg, io__state, io__state).
:- mode output_reg(in, di, uo) is det.

output_reg(r(N)) -->
	{ (N < 1, N > 32) ->
		error("Reg number out of range")
	;
		true
	},
	io__write_string("r"),
	io__write_int(N).
output_reg(f(_)) -->
	{ error("Floating point registers not implemented") }.

:- pred output_tag(tag, io__state, io__state).
:- mode output_tag(in, di, uo) is det.

output_tag(Tag) -->
	io__write_string("mktag("),
	io__write_int(Tag),
	io__write_string(")").

:- pred output_rval(rval, io__state, io__state).
:- mode output_rval(in, di, uo) is det.

output_rval(binop(Op, X, Y)) -->
	( { Op = streq } ->
		io__write_string("string_equal("),
		output_rval(X),
		io__write_string(", "),
		output_rval(Y),
		io__write_string(")")
	;
		io__write_string("("),
		output_rval(X),
		io__write_string(" "),
		output_operator(Op),
		io__write_string(" "),
		output_rval(Y),
		io__write_string(")")
	).
output_rval(iconst(N)) -->
	io__write_int(N).
output_rval(sconst(String)) -->
	io__write_string("string_const(\""),
	output_c_quoted_string(String),
	{ string__length(String, StringLength) },
	io__write_string("\", "),
	io__write_int(StringLength),
	io__write_string(")").
output_rval(mkword(Tag, Exprn)) -->
	io__write_string("mkword("),
	output_tag(Tag),
	io__write_string(", "),
	output_rval(Exprn),
	io__write_string(")").
output_rval(mktag(Exprn)) -->
	io__write_string("mktag("),
	output_rval(Exprn),
	io__write_string(")").
output_rval(tag(Exprn)) -->
	io__write_string("tag("),
	output_rval(Exprn),
	io__write_string(")").
output_rval(mkbody(Exprn)) -->
	io__write_string("mkbody("),
	output_rval(Exprn),
	io__write_string(")").
output_rval(body(Exprn)) -->
	io__write_string("body("),
	output_rval(Exprn),
	io__write_string(")").
output_rval(field(Tag, Rval, Field)) -->
	io__write_string("field("),
	output_tag(Tag),
	io__write_string(","),
	output_rval(Rval),
	io__write_string(","),
	io__write_int(Field),
	io__write_string(")").
output_rval(lval(Lval)) -->
	output_lval(Lval).
output_rval(not(Rval)) -->
	io__write_string("(! "),
	output_rval(Rval),
	io__write_string(")").
output_rval(true) -->
	io__write_string("TRUE").
output_rval(false) -->
	io__write_string("FALSE").
output_rval(create(_,_)) -->
	{ error("Cannot output a create(_,_) expression in code") }.
output_rval(var(_)) -->
	{ error("Cannot output a var(_) expression in code") }.
output_rval(unused) -->
	{ error("Cannot output a `unused' expression in code") }.

:- pred output_lval(lval, io__state, io__state).
:- mode output_lval(in, di, uo) is det.

output_lval(reg(R)) -->
	output_reg(R).
output_lval(field(Tag, Lval, FieldNum)) -->
	io__write_string("field("),
	output_tag(Tag),
	io__write_string(", "),
	output_lval(Lval),
	io__write_string(", "),
	io__write_int(FieldNum),
	io__write_string(")").
output_lval(succip) -->
	io__write_string("LVALUE_CAST(Word,succip)").
output_lval(sp) -->
	io__write_string("LVALUE_CAST(Word,sp)").
output_lval(hp) -->
	io__write_string("LVALUE_CAST(Word,hp)").
output_lval(maxfr) -->
	io__write_string("LVALUE_CAST(Word,maxfr)").
output_lval(curredoip) -->
	io__write_string("LVALUE_CAST(Word,curredoip)").
output_lval(stackvar(N)) -->
	{ (N < 0) ->
		error("stack var out of range")
	;
		true
	},
	io__write_string("detstackvar("),
	io__write_int(N),
	io__write_string(")").
output_lval(framevar(N)) -->
	{ (N < 0) ->
		error("stack var out of range")
	;
		true
	},
	io__write_string("framevar("),
	io__write_int(N),
	io__write_string(")").
output_lval(lvar(_)) -->
	{ error("Illegal to output an lvar") }.

%-----------------------------------------------------------------------------%

:- pred output_c_quoted_string(string, io__state, io__state).
:- mode output_c_quoted_string(in, di, uo) is det.

output_c_quoted_string(S0) -->
	( { string__first_char(S0, Char, S1) } ->
		( { quote_c_char(Char, QuoteChar) } ->
			io__write_char('\\'),
			io__write_char(QuoteChar)
		;
			io__write_char(Char)
		),
		output_c_quoted_string(S1)
	;
		[]
	).

:- pred quote_c_char(character, character).
:- mode quote_c_char(in, out) is semidet.

quote_c_char('\"', '"').
quote_c_char('\\', '\\').
quote_c_char('\n', 'n').
quote_c_char('\t', 't').
quote_c_char('\b', 'b').

%-----------------------------------------------------------------------------%

:- pred output_operator(operator, io__state, io__state).
:- mode output_operator(in, di, uo) is det.

output_operator(streq) -->
	io__write_string("streq").
output_operator(+) -->
	io__write_string("+").
output_operator(-) -->
	io__write_string("-").
output_operator(*) -->
	io__write_string("*").
output_operator(/) -->
	io__write_string("/").
output_operator(mod) -->
	io__write_string("%").
output_operator(eq) -->
	io__write_string("==").
output_operator(ne) -->
	io__write_string("!=").
output_operator(and) -->
	io__write_string("&&").
output_operator(or) -->
	io__write_string("||").
output_operator(<) -->
	io__write_string("<").
output_operator(>) -->
	io__write_string(">").
output_operator(<=) -->
	io__write_string("<=").
output_operator(>=) -->
	io__write_string(">=").

%-----------------------------------------------------------------------------%

:- pred clause_num_to_string(int::in, string::out) is det.

clause_num_to_string(N, Str) :-
	( clause_num_to_string_2(N, Str0) ->
		Str = Str0
	;
		error("clause_num_to_string failed")
	).

:- pred clause_num_to_string_2(int::in, string::out) is semidet.

clause_num_to_string_2(N, Str) :-
	(
		N < 26
	->
		int_to_letter(N, Str)
	;
		N_Low is N mod 26,
		N_High is N // 26,
		int_to_letter(N_Low, L),
		clause_num_to_string(N_High, S),
		string__append(S, L, Str)
	).

:- pred int_to_letter(int, string).
:- mode int_to_letter(in, out) is semidet.

	% This code is boring, but portable - it works even for EBCDIC ;-)

int_to_letter(0, "a").
int_to_letter(1, "b").
int_to_letter(2, "c").
int_to_letter(3, "d").
int_to_letter(4, "e").
int_to_letter(5, "f").
int_to_letter(6, "g").
int_to_letter(7, "h").
int_to_letter(8, "i").
int_to_letter(9, "j").
int_to_letter(10, "k").
int_to_letter(11, "l").
int_to_letter(12, "m").
int_to_letter(13, "n").
int_to_letter(14, "o").
int_to_letter(15, "p").
int_to_letter(16, "q").
int_to_letter(17, "r").
int_to_letter(18, "s").
int_to_letter(19, "t").
int_to_letter(20, "u").
int_to_letter(21, "v").
int_to_letter(22, "w").
int_to_letter(23, "x").
int_to_letter(24, "y").
int_to_letter(25, "z").

llds__lval_to_string(framevar(N), Description) :-
	string__int_to_string(N, N_String),
	string__append("framevar(", N_String, Tmp),
	string__append(Tmp, ")", Description).
llds__lval_to_string(stackvar(N), Description) :-
	string__int_to_string(N, N_String),
	string__append("stackvar(", N_String, Tmp),
	string__append(Tmp, ")", Description).
llds__lval_to_string(reg(Reg), Description) :-
	llds__reg_to_string(Reg, Reg_String),
	string__append("reg(", Reg_String, Tmp),
	string__append(Tmp, ")", Description).

:- pred llds__reg_to_string(reg, string).
:- mode llds__reg_to_string(in, out) is det.

llds__reg_to_string(r(N), Description) :-
	string__int_to_string(N, N_String),
	string__append("r(", N_String, Tmp),
	string__append(Tmp, ")", Description).
llds__reg_to_string(f(N), Description) :-
	string__int_to_string(N, N_String),
	string__append("f(", N_String, Tmp),
	string__append(Tmp, ")", Description).

:- end_module llds.

%-----------------------------------------------------------------------------%
