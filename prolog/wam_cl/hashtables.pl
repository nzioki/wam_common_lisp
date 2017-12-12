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
 * The program is a *HUGE* common-lisp compiler/interpreter. It is written for YAP/SWI-Prolog .
 *
 *******************************************************************/
:- module(hashts, []).

:- set_module(class(library)).

:- include('header').

cl_make_hash_table(X):- create_struct(claz_hash_table,X).
  
:- fixup_exports.

end_of_file.

