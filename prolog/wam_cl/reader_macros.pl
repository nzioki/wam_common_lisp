/*******************************************************************
 *
 * A Common Lisp compiler/interpretor, written in Prolog
 *
 * (xxxxx.pl)
 *
 *
 * Douglas'' Notes:
 *
 * (c) Douglas Miles, 2017
 *
 * The program is a *HUGE* common-lisp compiler/interpreter. It is written for YAP/SWI-Prolog (YAP 4x faster).
 *
 *******************************************************************/
:- module(rm, []).
:- set_module(class(library)).
:- include('header.pro').

:- use_module(sreader).

str_to_expression(Str, Expression):- lisp_add_history(Str),parse_sexpr_untyped_read(string(Str), Expression),!.
str_to_expression(Str, Expression):- with_input_from_string(Str,read_and_parse(Expression)),!.

remove_comments(IO,IO):- \+ compound(IO),!.
remove_comments([I|II],O):- is_comment(I,_),!,remove_comments(II,O).
remove_comments([I|II],[O|OO]):-remove_comments(I,O),!,remove_comments(II,OO).
remove_comments(IO,IO).

resolve_reader_macros(I,O):- remove_comments(I,M),resolve_inlines(M,M2),remove_comments(M2,O).

resolve_inlines(IO,IO):- \+ compound(IO),!.
/*
% #+
resolve_inlines([A,[OP,Flag,Form]|MORE], Code):- same_symbol(OP,'#+'),!, 
   must_or_rtrace(( symbol_value(xx_features_xx,FEATURES),
                    (  member(Flag,FEATURES) -> resolve_inlines([A,Form|MORE], Code) ; resolve_inlines([A,'$COMMENT'(flag_removed(+Flag,Form))|MORE], Code)))).
% #-
resolve_inlines([A,[OP,Flag,Form]|MORE], Code):- same_symbol(OP,'#-'),!, 
   must_or_rtrace(( symbol_value(xx_features_xx,FEATURES),
                    ( \+ member(Flag,FEATURES) -> resolve_inlines([A,Form|MORE], Code) ; resolve_inlines([A,'$COMMENT'(flag_removed(-Flag,Form))|MORE], Code)))).

*/
% #+
resolve_inlines([OP,Flag,Form], Code):- same_symbol(OP,'#+'),!, 
   must_or_rtrace(( symbol_value(xx_features_xx,FEATURES),
                    (  member(Flag,FEATURES) -> resolve_inlines(Form, Code) ; resolve_inlines('$COMMENT'(flag_removed(+Flag,Form)), Code)))).
% #-
resolve_inlines([OP,Flag,Form], Code):- same_symbol(OP,'#-'),!, 
   must_or_rtrace(( symbol_value(xx_features_xx,FEATURES),
                    (  \+ member(Flag,FEATURES) -> resolve_inlines(Form, Code) ; resolve_inlines('$COMMENT'(flag_removed(+Flag,Form)), Code)))).

resolve_inlines([I|II],O):- is_comment(I,_),!,resolve_inlines(II,O).
resolve_inlines([I|II],[O|OO]):-resolve_inlines(I,O),!,resolve_inlines(II,OO).
resolve_inlines(IO,IO).

as_sexp(I,O):- as_sexp1(I,M),resolve_reader_macros(M,M2),remove_comments(M2,O).

as_sexp1(Var,Var):-var(Var).
as_sexp1(NIL,NIL):-NIL==[],!.
as_sexp1(Stream,Expression):- is_stream(Stream),!,must(parse_sexpr_untyped(Stream,SExpression)),!,as_sexp2(SExpression,Expression).
as_sexp1(s(Str),Expression):- !, must(parse_sexpr_untyped(string(Str),SExpression)),!,as_sexp2(SExpression,Expression).
as_sexp1(Str,Expression):- notrace(catch(text_to_string(Str,String),_,fail)),!, 
    must_or_rtrace(parse_sexpr_untyped(string(String),SExpression)),!,as_sexp2(SExpression,Expression).
as_sexp1(Str,Expression):- as_sexp2(Str,Expression),!.

as_sexp2(Str,Expression):- is_list(Str),!,maplist(expand_pterm_to_sterm,Str,Expression).
as_sexp2(Str,Expression):- expand_pterm_to_sterm(Str,Expression),!.







expand_pterm_to_sterm(VAR,VAR):- notrace(is_ftVar(VAR)),!.
expand_pterm_to_sterm('NIL',[]):-!.
expand_pterm_to_sterm(nil,[]):-!.
expand_pterm_to_sterm(VAR,VAR):- \+ compound(VAR),!.
expand_pterm_to_sterm(ExprI,ExprO):- ExprI=..[F|Expr],atom_concat('$',_,F),must_maplist(expand_pterm_to_sterm,Expr,TT),ExprO=..[F|TT].
expand_pterm_to_sterm([X|L],[Y|Ls]):-!,expand_pterm_to_sterm(X,Y),expand_pterm_to_sterm(L,Ls),!.
expand_pterm_to_sterm(X,STerm):- compound_name_arguments(X,F,L),expand_pterm_to_sterm(L,Y),!,maybe_sterm(F,Y,STerm).
expand_pterm_to_sterm(X,X).
maybe_sterm(F,Y,PTerm):- keep_as_compund(F),PTerm=..[F|Y].
maybe_sterm(F,Y,[F|Y]).
keep_as_compund(function).
keep_as_compund(closure).
keep_as_compund(prolog).
keep_as_compund(ugly).
keep_as_compund('$OBJ').
keep_as_compund('$CHAR').
keep_as_compund(v).
keep_as_compund(obj).
keep_as_compund(D):-atom_concat('$',_,D).






:- fixup_exports.


