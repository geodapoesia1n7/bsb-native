(***********************************************************************)
(*                                                                     *)
(*                                OCaml                                *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the Q Public License version 1.0.               *)
(*                                                                     *)
(***********************************************************************)
(* Adapted for Javascript backend: Hongbo Zhang,                       *)


(** A pass used to optimize the exit code compilation, adaped from the compiler's
    [simplif] module
 *)

val count_helper : Lambda.lambda -> (int, int ref) Hashtbl.t

type subst_tbl = (int, Ident.t list * Lambda.lambda) Hashtbl.t

val subst_helper : subst_tbl -> (int -> int) -> Lambda.lambda -> Lambda.lambda

val simplify_exits : Lambda.lambda -> Lambda.lambda
