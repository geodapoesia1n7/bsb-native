(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)





(** *)

type exception_block = string * nativeint 


let out_of_memory =  "Out_of_memory", 0n
let sys_error = "Sys_error", -1n
let failure =  "Failure", -2n
let invalid_argument =  "Invalid_argument", -3n
let end_of_file = "End_of_file",-4n
let division_by_zero =  "Division_by_zero", -5n
let not_found = "Not_found", -6n
let match_failure =  "Match_failure", -7n
let stack_overflow =  "Stack_overflow",-8n
let sys_blocked_io =  "Sys_blocked_io", -9n
let assert_failure =  "Assert_failure", -10n
let undefined_recursive_module =  "Undefined_recursive_module", -11n

(* TODO: 
   1. is it necessary to tag [248] here
   2. is it okay to remove the negative value
*)
