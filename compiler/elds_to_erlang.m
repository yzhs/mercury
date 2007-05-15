%-----------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sw=4 et
%-----------------------------------------------------------------------------%
% Copyright (C) 2007 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%
% 
% File: elds_to_erlang.m.
% Main authors: wangp.
% 
% Convert ELDS to Erlang code.
% 
%-----------------------------------------------------------------------------%

:- module erl_backend.elds_to_erlang.
:- interface.

:- import_module erl_backend.elds.
:- import_module hlds.hlds_module.

:- import_module io.

%-----------------------------------------------------------------------------%

    % output_elds(ELDS, !IO):
    %
    % Output Erlang code to the appropriate .erl file.  The file names are
    % determined by the module name.
    %
:- pred output_elds(module_info::in, elds::in, io::di, io::uo) is det.

    % Output a Erlang function definition to the current output stream.
    % This is exported for debugging purposes. 
    %
:- pred output_defn(module_info::in, elds_defn::in, io::di, io::uo)
    is det.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module backend_libs.rtti.
:- import_module hlds.hlds_pred.
:- import_module hlds.hlds_rtti.
:- import_module hlds.passes_aux.
:- import_module hlds.special_pred.
:- import_module libs.compiler_util.
:- import_module mdbcomp.prim_data.
:- import_module parse_tree.modules.
:- import_module parse_tree.prog_data.
:- import_module parse_tree.prog_type.
:- import_module parse_tree.prog_util.

:- import_module bool.
:- import_module char.
:- import_module int.
:- import_module library.
:- import_module list.
:- import_module maybe.
:- import_module pair.
:- import_module string.
:- import_module term.
:- import_module varset.

%-----------------------------------------------------------------------------%

output_elds(ModuleInfo, ELDS, !IO) :-
    ELDS = elds(ModuleName, _),
    %
    % The Erlang interactive shell doesn't like "." in filenames so we use "__"
    % instead.
    %
    module_name_to_file_name_sep(ModuleName, "__", ".erl", yes,
        SourceFileName, !IO),
    output_to_file(SourceFileName, output_erl_file(ModuleInfo, ELDS,
        SourceFileName), !IO).

:- pred output_erl_file(module_info::in, elds::in, string::in,
    io::di, io::uo) is det.

output_erl_file(ModuleInfo, elds(ModuleName, Defns), SourceFileName, !IO) :-
    % Output intro.
    library.version(Version),
    io.write_strings([
        "%\n",
        "% Automatically generated from `", SourceFileName, "'\n",
        "% by the Mercury compiler,\n",
        "% version ", Version, ".\n",
        "% Do not edit.\n",
        "%\n",
        "\n"
    ], !IO),

    % Write module annotations.
    io.write_string("-module(", !IO),
    output_atom(erlang_module_name_to_str(ModuleName), !IO),
    io.write_string(").\n", !IO),

    io.write_string("-export([", !IO),
    output_exports(ModuleInfo, Defns, no, !IO),
    io.write_string("]).\n", !IO),

    % Useful for debugging.
    io.write_string("% -compile(export_all).\n", !IO),

    list.foldl(output_defn(ModuleInfo), Defns, !IO).

:- pred output_exports(module_info::in, list(elds_defn)::in, bool::in,
    io::di, io::uo) is det.

output_exports(_ModuleInfo, [], _NeedComma, !IO).
output_exports(ModuleInfo, [Defn | Defns], NeedComma, !IO) :-
    Defn = elds_defn(PredProcId, Arity, _, _),
    PredProcId = proc(PredId, _ProcId),
    module_info_pred_info(ModuleInfo, PredId, PredInfo),
    pred_info_get_import_status(PredInfo, ImportStatus),
    IsExported = status_is_exported(ImportStatus),
    (
        IsExported = yes,
        (
            NeedComma = yes,
            io.write_char(',', !IO)
        ;
            NeedComma = no
        ),
        nl_indent_line(1, !IO),
        output_pred_proc_id(ModuleInfo, PredProcId, !IO),
        io.write_char('/', !IO),
        io.write_int(Arity, !IO),
        output_exports(ModuleInfo, Defns, yes, !IO)
    ;
        IsExported = no,
        output_exports(ModuleInfo, Defns, NeedComma, !IO)
    ).

output_defn(ModuleInfo, Defn, !IO) :-
    Defn = elds_defn(PredProcId, _Arity, VarSet, Clause),
    io.nl(!IO),
    output_pred_proc_id(ModuleInfo, PredProcId, !IO),
    Indent = 0,
    output_clause(ModuleInfo, VarSet, Indent, Clause, !IO),
    io.write_string(".\n", !IO).

:- pred output_clause(module_info::in, prog_varset::in, indent::in,
    elds_clause::in, io::di, io::uo) is det.

output_clause(ModuleInfo, VarSet, Indent, Clause, !IO) :-
    Clause = elds_clause(Pattern, Expr),
    io.write_string("(", !IO),
    io.write_list(Pattern, ", ",
        output_term(ModuleInfo, VarSet, Indent), !IO),
    io.write_string(") -> ", !IO),
    output_expr(ModuleInfo, VarSet, Indent + 1, Expr, !IO).

%-----------------------------------------------------------------------------%
%
% Code to output expressions
%

:- pred output_exprs_with_nl(module_info::in, prog_varset::in,
    indent::in, list(elds_expr)::in, io::di, io::uo) is det.

output_exprs_with_nl(_ModuleInfo, _VarSet, _Indent, [], !IO).
output_exprs_with_nl(ModuleInfo, VarSet, Indent, [Expr | Exprs], !IO) :-
    output_expr(ModuleInfo, VarSet, Indent, Expr, !IO),
    (
        Exprs = []
    ;
        Exprs = [_ | _],
        io.write_char(',', !IO),
        nl_indent_line(Indent, !IO),
        output_exprs_with_nl(ModuleInfo, VarSet, Indent, Exprs, !IO)
    ).

:- pred output_exprs(module_info::in, prog_varset::in, indent::in,
    list(elds_expr)::in, io::di, io::uo) is det.

output_exprs(ModuleInfo, VarSet, Indent, Exprs, !IO) :-
    io.write_list(Exprs, ", ",
        output_expr(ModuleInfo, VarSet, Indent), !IO).

:- pred output_expr(module_info::in, prog_varset::in, indent::in,
    elds_expr::in, io::di, io::uo) is det.

output_expr(ModuleInfo, VarSet, Indent, Expr, !IO) :-
    (
        Expr = elds_block(Exprs),
        nl_indent_line(Indent, !IO),
        io.write_string("(begin", !IO),
        nl_indent_line(Indent + 1, !IO),
        output_exprs_with_nl(ModuleInfo, VarSet, Indent + 1, Exprs, !IO),
        nl_indent_line(Indent, !IO),
        io.write_string("end)", !IO)
    ;
        Expr = elds_term(Term),
        output_term(ModuleInfo, VarSet, Indent, Term, !IO)
    ;
        Expr = elds_eq(ExprA, ExprB),
        output_expr(ModuleInfo, VarSet, Indent, ExprA, !IO),
        io.write_string("= ", !IO),
        output_expr(ModuleInfo, VarSet, Indent, ExprB, !IO)
    ;
        Expr = elds_unop(Unop, ExprA),
        io.write_string(elds_unop_to_string(Unop), !IO),
        output_expr(ModuleInfo, VarSet, Indent, ExprA, !IO)
    ;
        Expr = elds_binop(Binop, ExprA, ExprB),
        output_expr(ModuleInfo, VarSet, Indent, ExprA, !IO),
        output_elds_binop(Binop, !IO),
        output_expr(ModuleInfo, VarSet, Indent, ExprB, !IO)
    ;
        Expr = elds_call(PredProcId, Args),
        output_pred_proc_id(ModuleInfo, PredProcId, !IO),
        io.write_string("(", !IO),
        output_exprs(ModuleInfo, VarSet, Indent, Args, !IO),
        io.write_string(") ", !IO)
    ;
        Expr = elds_call_ho(Closure, Args),
        output_expr(ModuleInfo, VarSet, Indent, Closure, !IO),
        io.write_string("(", !IO),
        output_exprs(ModuleInfo, VarSet, Indent, Args, !IO),
        io.write_string(") ", !IO)
    ;
        Expr = elds_fun(Clause),
        io.write_string("fun", !IO),
        output_clause(ModuleInfo, VarSet, Indent, Clause, !IO),
        io.write_string("end ", !IO)
    ;
        Expr = elds_case_expr(ExprA, Cases),
        io.write_string("(case ", !IO),
        nl_indent_line(Indent + 1, !IO),
        output_expr(ModuleInfo, VarSet, Indent + 1, ExprA, !IO),
        nl_indent_line(Indent, !IO),
        io.write_string("of ", !IO),
        io.write_list(Cases, "; ",
            output_case(ModuleInfo, VarSet, Indent + 1), !IO),
        nl_indent_line(Indent, !IO),
        io.write_string("end)", !IO)
    ).

:- pred output_case(module_info::in, prog_varset::in, indent::in,
    elds_case::in, io::di, io::uo) is det.

output_case(ModuleInfo, VarSet, Indent, elds_case(Pattern, Expr), !IO) :-
    nl_indent_line(Indent, !IO),
    output_term(ModuleInfo, VarSet, Indent, Pattern, !IO),
    io.write_string("->", !IO),
    nl_indent_line(Indent + 1, !IO),
    output_expr(ModuleInfo, VarSet, Indent + 1, Expr, !IO).

%-----------------------------------------------------------------------------%

:- pred output_term(module_info::in, prog_varset::in, indent::in,
    elds_term::in, io::di, io::uo) is det.

output_term(ModuleInfo, VarSet, Indent, Term, !IO) :-
    (
        Term = elds_int(Int),
        io.write_int(Int, !IO),
        space(!IO)
    ;
        Term = elds_float(Float),
        io.write_float(Float, !IO),
        space(!IO)
    ;
        Term = elds_string(String),
        io.write_char('"', !IO),
        write_with_escaping(in_string, String, !IO),
        io.write_char('"', !IO),
        space(!IO)
    ;
        Term = elds_char(Char),
        Int = char.to_int(Char),
        (if char.is_alnum(Char) then
            io.write_char('$', !IO),
            io.write_char(Char, !IO)
        else if escape(Esc, Int) then
            io.write_char('$', !IO),
            io.write_string(Esc, !IO)
        else
            io.write_int(Int, !IO)
        ),
        space(!IO)
    ;
        Term = elds_atom_raw(Atom),
        output_atom(Atom, !IO),
        space(!IO)
    ;
        Term = elds_atom(SymName),
        output_atom(unqualify_name(SymName), !IO),
        space(!IO)
    ;
        Term = elds_tuple(Args),
        output_tuple(ModuleInfo, VarSet, Indent, Args, !IO)
    ;
        Term = elds_var(Var),
        output_var(VarSet, Var, !IO)
    ;
        Term = elds_anon_var,
        io.write_string("_ ", !IO)
    ).

:- pred output_tuple(module_info::in, prog_varset::in, indent::in,
    list(elds_expr)::in, io::di, io::uo) is det.

output_tuple(ModuleInfo, VarSet, Indent, Args, !IO) :-
    % Treat lists and tuples specially.
    (
        Args = [elds_term(elds_atom(SymName))],
        unqualify_name(SymName) = "[]"
    ->
        io.write_string("[] ", !IO)
    ;
        Args = [elds_term(elds_atom(SymName)), A, B],
        unqualify_name(SymName) = "[|]"
    ->
        io.write_char('[', !IO),
        output_expr(ModuleInfo, VarSet, Indent, A, !IO),
        io.write_string("| ", !IO),
        output_expr(ModuleInfo, VarSet, Indent, B, !IO),
        io.write_string("] ", !IO)
    ;
        Args = [elds_tuple | Args1]
    ->
        io.write_char('{', !IO),
        output_exprs(ModuleInfo, VarSet, Indent, Args1, !IO),
        io.write_char('}', !IO)
    ;
        io.write_char('{', !IO),
        output_exprs(ModuleInfo, VarSet, Indent, Args, !IO),
        io.write_char('}', !IO)
    ).

:- func elds_tuple = elds_expr. 
elds_tuple = elds_term(elds_atom(unqualified("{}"))).

:- pred output_var(prog_varset::in, prog_var::in, io::di, io::uo) is det.

output_var(VarSet, Var, !IO) :-
    varset.lookup_name(VarSet, Var, VarName),
    term.var_to_int(Var, VarNumber),
    % XXX this assumes all Mercury variable names are a subset of Erlang
    % variable names
    io.write_string(VarName, !IO),
    io.write_char('_', !IO),
    io.write_int(VarNumber, !IO),
    space(!IO).

:- pred output_pred_proc_id(module_info::in, pred_proc_id::in,
    io::di, io::uo) is det.

output_pred_proc_id(ModuleInfo, PredProcId, !IO) :-
    erlang_proc_name(ModuleInfo, PredProcId, MaybeExtModule, Name),
    (
        MaybeExtModule = yes(ExtModule),
        output_atom(ExtModule, !IO),
        io.write_char(':', !IO)
    ;
        MaybeExtModule = no
    ),
    output_atom(Name, !IO).

%-----------------------------------------------------------------------------%

:- pred erlang_proc_name(module_info::in, pred_proc_id::in,
    maybe(string)::out, string::out) is det.

erlang_proc_name(ModuleInfo, PredProcId, MaybeExtModule, ProcNameStr) :-
    PredProcId = proc(PredId, ProcId), 
    RttiProcName = make_rtti_proc_label(ModuleInfo, PredId, ProcId),
    RttiProcName = rtti_proc_label(PredOrFunc, ThisModule, PredModule,
        PredName, PredArity, _ArgTypes, _PredId, _ProcId,
        _HeadVarsWithNames, _ArgModes, _Detism,
        PredIsImported, _PredIsPseudoImported,
        Origin, _ProcIsExported, _ProcIsImported),

    ( Origin = origin_special_pred(SpecialPred) ->
        erlang_special_proc_name(ThisModule, PredName, ProcId, SpecialPred,
            MaybeExtModule, ProcNameStr)
    ;
        erlang_nonspecial_proc_name(ThisModule, PredModule, PredName,
            PredOrFunc, PredArity, ProcId, PredIsImported,
            MaybeExtModule, ProcNameStr)
    ).

:- pred erlang_nonspecial_proc_name(sym_name::in, sym_name::in, string::in,
    pred_or_func::in, arity::in, proc_id::in, bool::in,
    maybe(string)::out, string::out) is det.

erlang_nonspecial_proc_name(ThisModule, PredModule, PredName, PredOrFunc,
        PredArity, ProcId, PredIsImported, MaybeExtModule, ProcNameStr) :-
    ( ThisModule \= PredModule ->
        MaybeExtModule = yes(erlang_module_name_to_str(PredModule))
    ;
        MaybeExtModule = no
    ),

    (
        PredOrFunc = pf_predicate,
        Suffix = "p",
        OrigArity = PredArity
    ;
        PredOrFunc = pf_function,
        Suffix = "f",
        OrigArity = PredArity - 1
    ),

    PredLabelStr0 = PredName ++ "_" ++ string.from_int(OrigArity) ++
        "_" ++ Suffix,
    (
        % Work out which module supplies the code for the predicate.
        ThisModule \= PredModule,
        PredIsImported = no
    ->
        % This predicate is a specialized version of a pred from a `.opt' file.
        PredLabelStr = PredLabelStr0 ++ "_in__" ++
            erlang_module_name_to_str(PredModule)
    ;
        % The predicate was declared in the same module that it is defined in.
        PredLabelStr = PredLabelStr0
    ),

    proc_id_to_int(ProcId, ModeNum),
    ProcNameStr = PredLabelStr ++ "_" ++ string.from_int(ModeNum).

:- pred erlang_special_proc_name(sym_name::in, string::in, proc_id::in,
    special_pred::in, maybe(string)::out, string::out) is det.

erlang_special_proc_name(ThisModule, PredName, ProcId, SpecialPred - TypeCtor,
        MaybeExtModule, ProcNameStr) :-
    (
        % All type_ctors other than tuples here should be module qualified,
        % since builtin types are handled separately in polymorphism.m.
        TypeCtor = type_ctor(TypeCtorSymName, TypeArity),
        (
            TypeCtorSymName = unqualified(TypeName),
            type_ctor_is_tuple(TypeCtor),
            TypeModule = mercury_public_builtin_module
        ;
            TypeCtorSymName = qualified(TypeModule, TypeName)
        )
    ->
        ProcNameStr0 = PredName ++ "__",
        TypeModuleStr = erlang_module_name_to_str(TypeModule),
        (
            ThisModule \= TypeModule,
            SpecialPred = spec_pred_unify,
            \+ hlds_pred.in_in_unification_proc_id(ProcId)
        ->
            % This is a locally-defined instance of a unification procedure
            % for a type defined in some other module.
            ProcNameStr1 = ProcNameStr0 ++ TypeModuleStr,
            MaybeExtModule = no
        ;
            % The module declaring the type is the same as the module
            % defining this special pred.
            ProcNameStr1 = ProcNameStr0,
            ( TypeModule \= ThisModule ->
                MaybeExtModule = yes(TypeModuleStr)
            ;
                MaybeExtModule = no
            )
        ),
        ProcNameStr = ProcNameStr1 ++ TypeName ++ "_" ++
            string.from_int(TypeArity)
    ;
        unexpected(this_file,
            "erlang_special_proc_name: cannot make label for special pred " ++
            PredName)
    ).

:- func erlang_module_name_to_str(module_name) = string.

erlang_module_name_to_str(ModuleName) = Str :-
    % To avoid namespace collisions between Mercury standard modules and
    % Erlang standard modules, we pretend the Mercury standard modules are
    % in a "mercury" supermodule.
    %
    (if mercury_std_library_module_name(ModuleName) then
        Mod = add_outermost_qualifier("mercury", ModuleName)
    else
        Mod = ModuleName
    ),
    Str = sym_name_to_string_sep(Mod, "__").

%-----------------------------------------------------------------------------%

:- pred output_atom(string::in, io::di, io::uo) is det.

output_atom(String, !IO) :-
    (if 
        string.index(String, 0, FirstChar),
        char.is_lower(FirstChar),
        string.is_all_alnum_or_underscore(String),
        not requires_atom_quoting(String)
    then
        io.write_string(String, !IO)
    else
        io.write_char('\'', !IO),
        write_with_escaping(in_atom, String, !IO),
        io.write_char('\'', !IO)
    ).

:- pred requires_atom_quoting(string::in) is semidet.

requires_atom_quoting("and").
requires_atom_quoting("andalso").
requires_atom_quoting("band").
requires_atom_quoting("bnot").
requires_atom_quoting("bor").
requires_atom_quoting("bsl").
requires_atom_quoting("bsr").
requires_atom_quoting("bxor").
requires_atom_quoting("div").
requires_atom_quoting("not").
requires_atom_quoting("or").
requires_atom_quoting("orelse").
requires_atom_quoting("query").
requires_atom_quoting("rem").
requires_atom_quoting("xor").

%-----------------------------------------------------------------------------%

:- func elds_unop_to_string(elds_unop) = string.

elds_unop_to_string(plus)        = "+".
elds_unop_to_string(minus)       = "-".
elds_unop_to_string(bnot)        = "bnot ".
elds_unop_to_string(logical_not) = "not ".

:- pred output_elds_binop(elds_binop::in, io::di, io::uo) is det.

output_elds_binop(Binop, !IO) :-
    io.write_string(elds_binop_to_string(Binop), !IO),
    space(!IO).

:- func elds_binop_to_string(elds_binop) = string.

elds_binop_to_string(mul)       = "*".
elds_binop_to_string(float_div) = "/".
elds_binop_to_string(int_div)   = "div".
elds_binop_to_string(rem)       = "rem".
elds_binop_to_string(band)      = "band".
elds_binop_to_string(add)       = "+".
elds_binop_to_string(sub)       = "-".
elds_binop_to_string(bor)       = "bor".
elds_binop_to_string(bxor)      = "bxor".
elds_binop_to_string(bsl)       = "bsl".
elds_binop_to_string(bsr)       = "bsr".
elds_binop_to_string(=<)        = "=<".
elds_binop_to_string(<)         = "<".
elds_binop_to_string(>=)        = ">=".
elds_binop_to_string(>)         = ">".
elds_binop_to_string(=:=)       = "=:=".
elds_binop_to_string(=/=)       = "=/=".
elds_binop_to_string(andalso)   = "andalso".
elds_binop_to_string(orelse)    = "orelse".

%-----------------------------------------------------------------------------%

:- type string_or_atom
    --->    in_string
    ;       in_atom.

:- pred write_with_escaping(string_or_atom::in, string::in, io::di, io::uo)
    is det.

write_with_escaping(StringOrAtom, String, !IO) :-
    string.foldl(write_with_escaping_2(StringOrAtom), String, !IO).

:- pred write_with_escaping_2(string_or_atom::in, char::in, io::di, io::uo)
    is det.

write_with_escaping_2(StringOrAtom, Char, !IO) :-
    char.to_int(Char, Int),
    (
        32 =< Int, Int =< 126,
        Char \= ('\\'),
        (
            StringOrAtom = in_string,
            Char \= '"'
        ;
            StringOrAtom = in_atom,
            Char \= '\''
        )
    ->
        io.write_char(Char, !IO)
    ;
        escape(Esc, Int)
    ->
        io.write_string(Esc, !IO)
    ;
        string.int_to_base_string(Int, 8, OctalString),
        io.write_char('\\', !IO),
        io.write_string(OctalString, !IO)
    ).

:- pred escape(string, int).
:- mode escape(out, in) is semidet.

escape("\\b", 8).
escape("\\d", 127).
escape("\\e", 27).
escape("\\f", 12).
escape("\\n", 10).
escape("\\r", 13).
escape("\\s", 32).
escape("\\t", 9).
escape("\\v", 11).
escape("\\^a", 1).
escape("\\^b", 2).
escape("\\^c", 3).
escape("\\^d", 4).
escape("\\^e", 5).
escape("\\^f", 6).
escape("\\^g", 7).
% escape("\\^h", 8).    % alternative exists
% escape("\\^i", 9).
% escape("\\^j", 10).
% escape("\\^k", 11).
% escape("\\^l", 12).
% escape("\\^m", 13).
escape("\\^n", 14).
escape("\\^o", 15).
escape("\\^p", 16).
escape("\\^q", 17).
escape("\\^r", 18).
escape("\\^s", 19).
escape("\\^t", 20).
escape("\\^u", 21).
escape("\\^v", 22).
escape("\\^w", 23).
escape("\\^x", 24).
escape("\\^y", 25).
escape("\\^z", 26).
escape("\\'", 39).
escape("\\\"", 34).
escape("\\\\", 92).

%-----------------------------------------------------------------------------%

:- type indent == int.

:- pred nl_indent_line(indent::in, io::di, io::uo) is det.

nl_indent_line(N, !IO) :-
    io.nl(!IO),
    indent_line(N, !IO).

:- pred indent_line(indent::in, io::di, io::uo) is det.

indent_line(N, !IO) :-
    ( N =< 0 ->
        true
    ;
        io.write_string("  ", !IO),
        indent_line(N - 1, !IO)
    ).

%-----------------------------------------------------------------------------%

:- pred space(io::di, io::uo) is det.

space(!IO) :-
    io.write_char(' ', !IO).

%-----------------------------------------------------------------------------%

:- func this_file = string.

this_file = "elds_to_erlang.m".

%-----------------------------------------------------------------------------%
