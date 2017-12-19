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
 * The program is a *HUGE* common-lisp compiler/interpreter. 
 *
 *******************************************************************/
:- module(fn, []).

:- set_module(class(library)).

:- include('header').

:- discontiguous compile_defun_ops/5.

% DEFUN
wl:init_args(2,cl_defun).
% (DEFUN (SETF CAR) ....)
cl_defun(Symbol,FormalParms,FunctionBody,Result):- is_setf_op(Symbol,Accessor),!,cl_defsetf(Accessor,[FormalParms|FunctionBody],Result).
cl_defun(Symbol,FormalParms,FunctionBody,Return):-
  reenter_lisp(Ctx,Env),
  compile_defun_ops(Ctx,Env,Return,[defun,Symbol,FormalParms|FunctionBody],Code),
  dbmsg_real(Code).

    

compile_defun_ops(Ctx,Env,Result,[defun,Symbol,FormalParms|FunctionBody], (Code,FunDef,Result=Symbol)):-
  compile_function(Ctx,Env,[Symbol,FormalParms|FunctionBody],Function,Code),
  debug_var('DefunResult',Result),
  FunDef = (set_opv(Function,classof,claz_function),set_opv(Symbol,compile_as,kw_function),set_opv(Symbol,function,Function)),   
  always((FunDef,Code)).  


% FLET
wl:init_args(1,cl_flet).
cl_flet(Inits,Progn,Result):-
  reenter_lisp(Ctx,Env),
  compile_defun_ops(Ctx,Env,Result,[flet,Inits|Progn],Code),
  always(Code).  

compile_defun_ops(Ctx,Env,Result,[flet,FLETS|Progn], CompileBody):- 
    %gensym(labels,Gensym),
    get_label_suffix(Ctx,Gensym),
    must_maplist(define_each(Ctx,Env,flet,Gensym),FLETS,_News,Decls),
    maplist(always,Decls),    
    compile_forms(Ctx,Env,Result,Progn, CompileBody).       

% LABELS
wl:init_args(1,cl_labels).
cl_labels(Inits,Progn,Result):-
  reenter_lisp(Ctx,Env),
  compile_defun_ops(Ctx,Env,Result,[labels,Inits|Progn],Code),
  always(Code).  

compile_defun_ops(Ctx,Env,Result,[labels,LABELS|Progn], CompileBody):- 
    %gensym(labels,Gensym),
    get_label_suffix(Ctx,Gensym),
    must_maplist(define_each(Ctx,Env,flet,Gensym),LABELS,_News,Decls),
    maplist(always,Decls),    
    compile_forms(Ctx,Env,Result,Progn, CompileBody).   


define_each(Ctx,Env,flet,_Gensym,DEFN,New,CompileBody)  :- compile_function(Ctx,Env,New,DEFN,CompileBody),always(CompileBody),dbmsg_real(CompileBody).

% undefine_each(Ctx,Env,What,Gensym,DEFN,New,CompileBody)  :- nop(wdmsg(undefine_each(Ctx,Env,What,Gensym,DEFN,New,CompileBody))).



varuse:attr_unify_hook(_,Other):- var(Other).


compile_function(Ctx,Env,[Symbol,FormalParms|FunctionBody0],Function,CompileBodyOpt):-
   combine_setfs(Symbol,Combined),
   suffix_by_context(Ctx,Combined,Symbol),
   always(find_function_or_macro_name(Ctx,Env,Symbol,_Len, Function)),
   within_labels_context(Ctx,Symbol,((
   always(maybe_get_docs(function,Function,FunctionBody0,FunctionBody,DocCode)),
   %FunctionHead=[Function|FormalParms],
   debug_var("Env",CallEnv),
   debug_var('FnResult',Result),   
     (expand_function_head(Ctx,CallEnv,Symbol,FormalParms,_Whole, HeadParms,_HeadEnv, HeadDefCode,HeadCode),
      must_compile_body(Ctx,CallEnv,Result,[block,Symbol|FunctionBody],BodyCode))),      
   append([Function|HeadParms],[Result],HeadV),
   CallableHead =.. HeadV,
 CompileBody = (
   DocCode,
   assert_lsp(Symbol,wl:lambda_def(defun,(Symbol),Function, FormalParms, FunctionBody)),
   HeadDefCode,
   assert_lsp(Symbol,CallableHead  :-  BodyCodeO)),
 debug_var('Result',Result), 
  body_cleanup_keep_debug_vars(Ctx,(HeadCode,BodyCode),BodyCodeO),
  body_cleanup_keep_debug_vars(Ctx,CompileBody,CompileBodyOpt))).

:- fixup_exports.
