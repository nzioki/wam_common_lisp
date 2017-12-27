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
 * The program is a *HUGE* common-lisp compiler/interpreter. It is written for YAP/SWI-Prolog .
 *
 * Changes since 2001:
 *
 *
 *******************************************************************/
:- module(v4rZ, []).
:- set_module(class(library)).
:- include('header').

% local symbol?
rw_add(Ctx,Var,RW):- atom(Var),!,  get_var_tracker(Ctx,Var,Dict),arginfo_incr(RW,Dict).
rw_add(_Ctx,_Var,_RW).

%rwstate:attr_unify_hook(_,_):-!,fail.
%rwstate:attr_unify_hook(_,V):-always(var(V)),fail.

% actual var
add_tracked_var(Ctx,Atom,Var):-
   get_var_tracker(Ctx,Atom,Dict),
   Vars=Dict.vars,
   sort([Var|Vars],NewVars),
   b_set_dict(vars,Dict,NewVars).

%get_var_tracker(_,Atom,rw{name:Atom,r:0,w:0,p:0,ret:0,u:0,vars:[]}):-!. % mockup
get_var_tracker(Ctx0,Atom,Dict):- get_tracker(Ctx0,Ctx), always(sanity(atom(Atom))),get_env_attribute(Ctx,var_tracker(Atom),Dict),(is_dict(Dict)->true;(trace,oo_get_attr(Ctx,var_tracker(Atom),_SDict))).
get_var_tracker(Ctx0,Atom,Dict):- get_tracker(Ctx0,Ctx),Dict=rw{name:Atom,r:0,w:0,p:0,ret:0,u:0,vars:[]},set_env_attribute(Ctx,var_tracker(Atom),Dict),!.


%TODO Make it a constantp
deflexical(Env,defconstant, Var, Result):- 
   set_var(Env,Var,Result),
   set_opv(Var,declared_as,defconstant).
deflexical(Env,defconst, Var, Result):- 
  deflexical(Env,defconstant, Var, Result).

deflexical(Env,defparameter, Var, Result):- 
   set_opv(Var,declared_as,defparameter),
   set_var(Env,Var,Result).

deflexical(_Env,defvar, Var, Result):-   
   (get_opv(Var, value, _) -> true ; update_opv(Var, value, Result)),
   set_opv(Var,declared_as,defvar).

deflexical(Env,setq, Var, Result):- !, set_var(Env,Var,Result).

deflexical(Env,psetq, Var, Result):- !, set_var(Env,Var,Result).



op_return_type(Op,name):- is_def_nil(Op).
op_return_type(defconstant,name).
op_return_type(defconst,name).

is_def_nil(defparameter).
is_def_nil(defvar).

is_def_maybe_docs(defparameter).
is_def_maybe_docs(defvar).
is_def_maybe_docs(defconstant).
is_def_maybe_docs(defconst).

% catches an internal error in this compiler 
compile_symbol_getter(Ctx,Env,Result,Var, Body):- Var==mapcar,!, 
  dbginfo(compile_symbol_getter(Ctx,Env,Result,Var, Body)), lisp_dump_break.


compile_symbol_getter(Ctx,Env,Value, Var, Body):-  always((atom(Var),!,
        debug_var([Var,'_Get'],Value),
        add_tracked_var(Ctx,Var,Value),
        rw_add(Ctx,Var,r),
        %debug_var('_GEnv',Env),
        Body = get_var(Env, Var, Value))).


compile_symbol_setter(Ctx,Env,Result,[SetQ, Var, ValueForm, StringL], (Code,Body)):- 
        is_stringp(StringL),to_prolog_string(StringL,String),is_def_maybe_docs(SetQ),
        (atom(Var)->cl_symbol_package(Var,Package);reading_package(Package)),
        Code = assert_lsp(Var,doc:doc_string(Var,Package,variable,String)),
	!, compile_symbol_setter(Ctx,Env,Result,[SetQ, Var, ValueForm], Body).


compile_symbol_setter(Ctx,Env,Result,[SetQ, Var, ValueForm], Body):- is_symbol_setter(Env,SetQ),
        rw_add(Ctx,Var,w),
        debug_var('AEnv',Env),
        !,	
	must_compile_body(Ctx,Env,ResultV,ValueForm, ValueBody),
        ((op_return_type(SetQ,RT),RT=name) ->  =(Var,Result) ; =(ResultV,Result)),
        Body = (ValueBody, set_var(Env, Var, ResultV)).



extract_variable_value([Val|Vals], FoundVal, Hole):-
		var(Vals)
	->	FoundVal = Val,
		Hole = Vals
	;	extract_variable_value(Vals, FoundVal, Hole).


bind_dynamic_value(Env,Var,Result):- set_var(Env,Var,Result).

get_symbol_value(Env,Obj,Value):- get_var(Env,Obj,Value).

get_var(Var,Value):- current_env(Env), get_var(Env,Var,Value).
get_var(Env,Var,Value):-
  symbol_value_or(Env,Var,
    symbol_value_error(Env,Var,Value),Value).

symbol_value_or(Env,Var,G,Value):-
 ensure_env(Env), 
 (symbol_value0(Env,Var,Value) -> true ; G).

symbol_value0(Env,Var,Value):-  bvof(bv(Var, Value),_,Env).
symbol_value0(_Env,Var,_Value):- notrace((nonvar(Var),is_functionp(Var),dbginfo(is_functionp(Var)))),!,lisp_dump_break.
symbol_value0(_Env,Var,Result):- get_opv(Var, value, Result),!.
symbol_value0(_Env,Var,Result):- atom(Var),get_opv(Var,value,Result),!.
symbol_value0(Env,[Place,Obj],Result):- trace, set_place(Env,getf,[Place,Obj],[],Result).


symbol_value_error(_Env,Var,_Result):- lisp_error_description(unbound_atom, ErrNo, _),throw(ErrNo, Var).

reset_mv:- b_getval('$mv_return',[V1,_V2|_])->b_setval('$mv_return',[V1]);true.

push_values([V1|Push],V1):- always(nonvar(Push)),nb_setval('$mv_return',[V1|Push]).

bvof(_,_,T):- notrace(((var(T);T==[tl]))),!,fail.
bvof(E,M,T):-E=T,!,M=T.
bvof(E,M,[L|L2]):- ((nonvar(L),bvof(E,M,L))->true;(nonvar(L2),bvof(E,M,L2))).


set_var(Var,Val):- % ensure_env(Env),!,
       set_var(_Env,Var,Val).

set_var(Env,Var,Result):-var(Result),!,get_var(Env,Var,Result).
set_var(Env,Var,Result):- % ensure_env(Env),!,
     (bvof(bv(Var,_),BV,Env)
      -> nb_setarg(2,BV,Result)
      ;	( 
        (get_opv(Var, value, _Old) 
           -> update_opv(Var, value, Result) 
           ; set_symbol_value_last_chance(Env,Var,Result)))).

%set_symbol_value_last_chance(_Env,Var,Result):- nb_current(Var,_)-> nb_setval(Var,Result),!.
%set_symbol_value_last_chance(Env,Var,Result):- add_to_env(Env,Var,Result),!.
set_symbol_value_last_chance(_Env,Var,Result):- set_opv(Var, value, Result),!.
set_symbol_value_last_chance(_Env,Var,_Result):- 
  lisp_error_description(atom_does_not_exist, ErrNo, _),throw(ErrNo, Var).


cl_defparameter(Var, Result, Result):- 
   set_opv(Var,declared_as,defparameter),
   set_var(_Env,Var,Result).


env_sym_arg_val(Env,Var,InValue,Value):-
  set_var(Env,Var,InValue),
  Value=InValue,!.

env_sym_arg_val(Env,Var,InValue,Value):- !,
  symbol_value_or(Env,Var,(nonvar(InValue),InValue=Value),Value)-> true;
    lisp_error_description(unbound_atom, ErrNo, _),throw(ErrNo, Var).


set_with_prolog_var(Ctx,Env,SetQ,Var,Result,set_var(Env,SetQ, Var, Result)):-
  rw_add(Ctx,Var,w).

expand_ctx_env_forms(Ctx, Env,Forms,Body, Result):- 
   must_compile_body(Ctx,Env,Result,Forms, Body).


normalize_let1([Variable, Form],[bind, Variable, Form]).
normalize_let1([bind, Variable, Form],[bind, Variable, Form]).
normalize_let1( Variable,[bind, Variable, []]).


%  (LET  () .... )
compile_let(Ctx,Env,Result,[_LET, []| BodyForms], Body):- !, must_compile_progn(Ctx,Env,Result, BodyForms, Body).

%  (LET ((*package* (find-package :keyword))) *package*)
compile_let(Ctx,Env,Result,[let, [[Var,VarInit]]| BodyForms], (VarInitCode,locally_set(Var,Value,BodyCode))):-
 is_special_var(Var),!,
 must_compile_body(Ctx,Env,Value,VarInit,VarInitCode),
  must_compile_progn(Ctx,Env,Result,BodyForms,BodyCode).

%  (LET ((local 1)) local)
compile_let(Ctx,Env,Result,[let, [[Var,VarInit]]| BodyForms], (VarInitCode,locally_bind(Env,Var,Value,BodyCode))):- fail,
 atom(Var),
 must_compile_body(Ctx,Env,Value,VarInit,VarInitCode),
  must_compile_progn(Ctx,Env,Result,BodyForms,BodyCode).


%  (LET  (....) .... )
compile_let(Ctx,Env,Result,[LET, NewBindingsIn| BodyForms], Body):- !,
  always((
      debug_var("BEnv",BindingsEnvironment),
      debug_var('LetResult',Result),
      debug_var("LEnv",CEnv),
                         
        freeze(Var,ignore((var(Value),debug_var('_Init',Var,Value)))),
        freeze(Var,ignore((var(Value),add_tracked_var(Ctx,Var,Value)))),
        
        must_maplist(normalize_let1,NewBindingsIn,NewBindings),
	zip_with(Variables, ValueForms, [Variable, Form, [bind, Variable, Form]]^true, NewBindings),
	expand_arguments(Ctx,Env,'funcall',1,ValueForms, VarInitCode, Values),

        zip_with(Variables, Values, [Var, Value, BV]^make_letvar(LET,Var,Value,BV),Bindings),

        % rescue out special bindings
        partition(is_bv2,Bindings,LocalBindings,SpecialBindings),  

        ignore((member(VarN,[Variable,Var]),atom(VarN),var(Value),debug_var([VarN,'_Let'],Value),fail)),                
        add_alphas(Ctx,Variables),
        let_body(Env,BindingsEnvironment,LocalBindings,SpecialBindings,BodyFormsBody,MaybeSpecialBody),
          make_env_append(Ctx,Env,CEnv,[LocalBindings|Env],EnvAssign),
          must_compile_progn(Ctx,CEnv,BResult,BodyForms, BodyFormsBody),          
         Body = (VarInitCode, EnvAssign, MaybeSpecialBody,G))),
  ensure_assignment(Result=BResult,G).

is_bv2(BV):- \+ \+ BV=bv(_,_).
% No Locals
let_body(Env,BindingsEnvironment,[],SpecialBindings,BodyFormsBody,MaybeSpecialBody):- fail,!,
  Env=BindingsEnvironment, debug_var("LEnv",BindingsEnvironment),
  maybe_specials_in_body(SpecialBindings,BodyFormsBody,MaybeSpecialBody).

% Some Locals
let_body(_Env,_BindingsEnvironment,_LocalBindings,SpecialBindings,BodyFormsBody,(MaybeSpecialBody)):-!,
  
  %nb_set_last_tail(LocalBindings,Env),
  maybe_specials_in_body(SpecialBindings,BodyFormsBody,MaybeSpecialBody).
  

% No Specials
maybe_specials_in_body([],BodyFormsBody,BodyFormsBody).
% Some Specials
maybe_specials_in_body(SpecialBindings,BodyFormsBody,SpecialBody):-
  mize_prolog_code(maplist(save_special,SpecialBindings),PreCode),
  mize_prolog_code(maplist(restore_special,SpecialBindings),PostCode),
   SpecialBody = (PreCode, BodyFormsBody, PostCode). 
    % Some SAFE specials -> SpecialBody = setup_call_cleanup(PreCode, BodyFormsBody, PostCode).

is_special_var(Var):- atom(Var),!,get_opv_i(Var,value,_).

make_letvar(ext_letf,Place,Value,place(Place,Value,_OldValue)):- is_list(Place).
make_letvar(_,Var,Value,sv(Var,Value,value,_OldValue)):- is_special_var(Var),!.
make_letvar(_,Var,Value,bv(Var,Value)).
%make_letvar(_,Var,Value,vv(Var,Value)).


  % maybe_bind_local(Ctx,Env,[Var,ValueForm|_],Body,(VarInitCode,locally_bind(Env,Var,Value,Body))):- 

%save_special(vv(_,_)).
save_special(sv(Var,New,Prop,Old)):- get_opv(Var,Prop,Old),set_opv(Var,Prop,New).
save_special(place(Place,New,Old)):- get_place(Place,Old),set_place(Place,New).

%restore_special(vv(_,_)).
restore_special(sv(Var,_,Prop,Old)):- set_opv(Var,Prop,Old).
restore_special(place(Place,_New,Old)):- set_place(Place,Old).


/*
compile_let_9(Ctx,Env,Result,[let, [Bind1|NewBindingsIn]| BodyForms], Call):- 
  maybe_bind_special(Ctx,Env,Bind1,Body,Call),!,
  compile_let(Ctx,Env,Result,[let, NewBindingsIn| BodyForms], Body).
compile_let_9(Ctx,Env,Result,[let, [Bind1|NewBindingsIn]| BodyForms], Call):- 
  maybe_bind_local(Ctx,Env,Bind1,Body,Call),!,
  compile_let(Ctx,Env,Result,[let, NewBindingsIn| BodyForms], Body).
compile_let_9(Ctx,Env,Result,[let, NewBindingsIn| BodyForms], Body):- 
  compile_let(LET,Ctx,Env,Result,[let, NewBindingsIn| BodyForms], Body).

%maybe_bind_special(_Ctx,_Env,Var,Body,locally_let(Var=[],Body)):- is_sboundp(Var),!.
maybe_bind_special(Ctx,Env,Var,Body,Out):- is_sboundp(Var),!,maybe_bind_special(Ctx,Env,[Var,[]],Body,Out).
maybe_bind_special(Ctx,Env,[Var,ValueForm|_],Body,(VarInitCode,locally_set(Var,Value,Body))):- 
  debug_var([Var,'_SLet'],Value),
  is_sboundp(Var),!,must_compile_body(Ctx,Env,Value,ValueForm,VarInitCode).

maybe_bind_local(Ctx,Env,Var,Body,Out):- atom(Var),!,maybe_bind_local(Ctx,Env,[Var,[]],Body,Out).
maybe_bind_local(Ctx,Env,[Var,ValueForm|_],Body,(VarInitCode,locally_bind(Env,Var,Value,Body))):- 
    %debug_var("LEnv",BindingsEnvironment),
    debug_var([Var,'_Let'],Value),
    must_compile_body(Ctx,Env,Value,ValueForm,VarInitCode).
*/



%  current_env(Env),
  %set_var(Env,Var,Value).

%   zip_with(Xs, Ys, Pred, Zs)
%   is true if Pred(X, Y, Z) is true for all X, Y, Z.

zip_with([], [], _, []).
zip_with([X|Xs], [Y|Ys], Pred, [Z|Zs]):-
	lpa_apply(Pred, [X, Y, Z]),
	zip_with(Xs, Ys, Pred, Zs).



:- fixup_exports.

