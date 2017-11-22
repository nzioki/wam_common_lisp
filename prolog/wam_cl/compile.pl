/*******************************************************************
 *
 * A Common Lisp compiler/interpretor, written in Prolog
 *
 * (lisp_compiler.pl)
 *
 *
 * Douglas'' Notes:
 *
 * (c) Douglas Miles, 2017
 *
 * The program is a *HUGE* common-lisp compiler/interpreter. It is written for YAP/SWI-Prolog (YAP 4x faster).
 *
 * Changes since 2001:
 *
 *
 *******************************************************************/
:- module(comp, []).
:- set_module(class(library)).
:- include('header.pro').

%new_compile_ctx(Ctx):- new_assoc(Ctx)put_attr(Ctx,type,ctx).
new_compile_ctx(Ctx):- list_to_rbtree([type-ctx],Ctx0),put_attr(Ctx,tracker,Ctx0).

lisp_compiled_eval(SExpression):-
  notrace(as_sexp(SExpression,Expression)),
  lisp_compiled_eval(Expression,Result),
  dbmsg(result(Result)).

lisp_compiled_eval(SExpression,Result):-
  notrace(as_sexp(SExpression,Expression)),
  dbmsg(lisp_compiled_eval(Expression)),
  lisp_compile(Result,Expression,Code),
  dbmsg(Code),
  must_or_rtrace(call(Code)),!.

%lisp_compile(SExpression):- source_location(_,_),!,dbmsg((:-lisp_compile(SExpression))).
lisp_compile(SExpression):-
  notrace(as_sexp(SExpression,Expression)),
  dbmsg(lisp_compile(Expression)),
  lisp_compile(Expression,Code),!,
  dbmsg(Code).

lisp_compile(Expression,Body):-
   debug_var('_Ignored',Result),
   lisp_compile(Result,Expression,Body).

lisp_compile(Result,SExpression,Body):-
   debug_var('TLEnv',Env),
   lisp_compile(Env,Result,SExpression,Body).

lisp_compile(Env,Result,Expression,Body):-
   new_compile_ctx(Ctx),
   must_or_rtrace(lisp_compile(Ctx,Env,Result,Expression,Body)).

lisp_compile(Ctx,Env,Result,SExpression,Body):-
   notrace(as_sexp(SExpression,Expression)),
   must_or_rtrace(compile_forms(Ctx,Env,Result,[Expression],Body)).


compile_forms(Ctx,Env,Result,FunctionBody,Code):-
   must_compile_progn(Ctx,Env,Result,FunctionBody, [], Body),!,
   body_cleanup(Ctx,Body,Code).

:- nop( debug_var('FirstForm',Var)),
   nb_linkval('$compiler_PreviousResult',the(Var)).


:- nb_setval('$labels_suffix','').
suffix_by_context(Atom,SuffixAtom):- nb_current('$labels_suffix',Suffix),atom_concat(Atom,Suffix,SuffixAtom).
suffixed_atom_concat(L,R,LRS):- atom_concat(L,R,LR),suffix_by_context(LR,LRS).
push_labels_context(Atom):- suffix_by_context(Atom,SuffixAtom),b_setval('$labels_suffix',SuffixAtom).
within_labels_context(Label,G):- nb_current('$labels_suffix',Suffix),
   setup_call_cleanup(b_setval('$labels_suffix',Label),G,b_setval('$labels_suffix',Suffix)).
gensym_in_labels(Stem,GenSym):- suffix_by_context(Stem,SuffixStem),gensym(SuffixStem,GenSym).
  

show_ctx_info(Ctx):- term_attvars(Ctx,CtxVars),maplist(del_attr_rev2(freeze),CtxVars),show_ctx_info2(Ctx).
show_ctx_info2(Ctx):- ignore((get_attr(Ctx,tracker,Ctx0),in_comment(show_ctx_info3(Ctx0)))).
show_ctx_info3(Ctx):- is_rbtree(Ctx),!,forall(rb_in(Key, Value, Ctx),fmt9(Key=Value)).
show_ctx_info3(Ctx):- fmt9(ctx=Ctx).
     

% same_symbol(OP1,OP2):-!, OP1=OP2.
same_symbol(OP1,OP2):- notrace(same_symbol0(OP1,OP2)).
same_symbol0(OP1,OP2):- var(OP1),var(OP2),trace_or_throw(same_symbol(OP1,OP2)).
same_symbol0(OP1,OP2):- var(OP2),atom(OP1),!,same_symbol(OP2,OP1).
same_symbol0(OP2,OP1):- var(OP2),atom(OP1),!,prologcase_name(OP1,OP3),!,freeze(OP2,((atom(OP2),same_symbol(OP2,OP3)))).
same_symbol0(OP1,OP2):-
  (atom(OP1),atom(OP2),(
   OP1==OP2 -> true;  
   prologcase_name(OP1,N1),
   (OP2==N1 -> true ;
   (prologcase_name(OP2,N2),
     (OP1==N2 -> true ; N1==N2))))).
:- '$hide'(same_symbol/2).



get_value_or_default(Ctx,Name,Value,IfMissing):- oo_get_attr(Ctx,Name,Value)->true;Value=IfMissing.

get_alphas(Ctx,Alphas):- get_attr(Ctx,tracker,Ctx0),get_alphas0(Ctx0,Alphas).
get_alphas0(Ctx,Alphas):- get_value_or_default(Ctx,alphas,Alphas,[]).

add_alphas(Ctx,Alphas):- must_or_rtrace((get_attr(Ctx,tracker,Ctx0),add_alphas0(Ctx0,Alphas))).
add_alphas0(Ctx,Alpha):- atom(Alpha),!,get_value_or_default(Ctx,alphas,Alphas,[]),oo_put_attr(Ctx,alphas,[Alpha|Alphas]).
add_alphas0(_Ctx,Alphas):- \+ compound(Alphas),!.
add_alphas0(Ctx,Alphas):- Alphas=..[_|ARGS],maplist(add_alphas0(Ctx),ARGS).

f_sys_memq(E,L,R):- t_or_nil((member(Q,L),Q==E),R).



must_compile_progn(Ctx,Env,Result,FormsIn, PreviousResult, Body):-
  notrace((maybe_debug_var('_rCtx',Ctx),
  maybe_debug_var('_rEnv',Env),
  maybe_debug_var('_rResult',Result),
  maybe_debug_var('_rPrevRes',PreviousResult),
  maybe_debug_var('_rForms',Forms),
  maybe_debug_var('_rBody',Body))),
  resolve_reader_macros(FormsIn,Forms),!,
   must_or_rtrace(compile_progn(Ctx,Env,Result,Forms, PreviousResult,Body0)),
   notrace((sanitize_true(Body0,Body))).

compile_progn(_Cx,_Ev,Result,Var,_PreviousResult,Out):- notrace(is_ftVar(Var)),!,Out=cl_eval([progn|Var],Result).
compile_progn(_Cx,_Ev,Result,[], PreviousResult,true):-!, PreviousResult = Result.
compile_progn(Ctx,Env,Result,[Form | Forms], _PreviousResult, Body):-  !,
   %locally(
     %local_override('$compiler_PreviousResult',the(PreviousResult)),
	must_compile_body(Ctx,Env,FormResult, Form,FormBody), %),
	must_compile_progn(Ctx,Env,Result, Forms, FormResult, FormSBody),
        Body = (FormBody,FormSBody).
compile_progn(Ctx,Env,Result, Form , _PreviousResult, Body):-
        % locally(
  % local_override('$compiler_PreviousResult',the(PreviousResult)),
	     must_compile_body(Ctx,Env,Result,Form, Body).




tst:is_local_test("
(defun sum_with_map (xs)
  (let (( running_total 0))
    (let ((summer
    (function
       (lambda (n)
        (setq running_total (+ running_total n))))))
       (mapcar summer  xs) running_total)))
 "
  ).

tst:is_local_test("(defun accumulate (op seq &optional (init 0)) (if (null seq) init (funcall op (car seq) (accumulate op (cdr seq) init))))").


:- fixup_exports.
