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



type t = 
  | Unsafe_ffi_bool_type

  | Unsafe_poly_variant_type
  (* for users write code like this:
     {[ external f : [`a of int ] -> string = ""]}
     Here users forget about `[@bs.string]` or `[@bs.int]`
  *)    



let to_string t =
  match t with
  | Unsafe_ffi_bool_type
    ->   
    "You are passing a OCaml bool type into JS, probabaly you want to pass Js.boolean"
  | Unsafe_poly_variant_type 
    -> 
    "Here a OCaml polymorphic variant type passed into JS, probably you forgot annotations like `[@bs.int]` or `[@bs.string]`  "

let warning_formatter = Format.err_formatter

let print_string_warning loc x = 
  Location.print warning_formatter loc ; 
  Format.pp_print_string warning_formatter "Warning: ";
  Format.pp_print_string warning_formatter x

let prerr_warning loc x =
  if not (!Js_config.no_warn_ffi_type ) then
    print_string_warning loc (to_string x) 

let warn_unused_attribute loc txt =
  print_string_warning loc ("Unused attribute " ^ txt ^ " \n" )
