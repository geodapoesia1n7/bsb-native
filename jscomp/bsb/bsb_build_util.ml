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

let flag_concat flag xs = 
  xs 
  |> Ext_list.flat_map (fun x -> [flag ; x])
  |> String.concat Ext_string.single_space
let (//) = Ext_filename.combine


    
(* we use lazy $src_root_dir *)




let convert_and_resolve_path = 
  if Sys.unix then Bsb_config.proj_rel  
  else 
  if Ext_sys.is_windows_or_cygwin then 
    fun (p:string) -> 
      let p = Ext_string.replace_slash_backward p in
      Bsb_config.proj_rel p 
  else failwith ("Unknown OS :" ^ Sys.os_type)
(* we only need convert the path in the begining*)


(* Magic path resolution:
   foo => foo
   foo/ => /absolute/path/to/projectRoot/node_modules/foo
   foo/bar => /absolute/path/to/projectRoot/node_modules/foo.bar
   /foo/bar => /foo/bar
   ./foo/bar => /absolute/path/to/projectRoot/./foo/bar
   Input is node path, output is OS dependent path
*)
let resolve_bsb_magic_file ~cwd ~desc p =
  let p_len = String.length p in
  let no_slash = Ext_string.no_slash p in
  if no_slash then
    p
  else if Filename.is_relative p &&
     p_len > 0 &&
     String.unsafe_get p 0 <> '.' then
    let p = if Ext_sys.is_windows_or_cygwin then Ext_string.replace_slash_backward p else p in
    match Bs_pkg.resolve_npm_package_file ~cwd p with
    | None -> failwith (p ^ " not found when resolving " ^ desc)
    | Some v -> v
  else
    convert_and_resolve_path p



(** converting a file from Linux path format to Windows *)

(**
   if [Sys.executable_name] gives an absolute path, 
   nothing needs to be done
   if it is a relative path 

   there are two cases: 
   - bsb.exe
   - ./bsb.exe 
   The first should also not be touched
   Only the latter need be adapted based on project root  
*)

let get_bsc_dir cwd = 
  Filename.dirname (Ext_filename.normalize_absolute_path (cwd // Sys.executable_name))
let get_bsc_bsdep cwd = 
  let dir = get_bsc_dir cwd in    
  dir // "bsc.exe", dir // "bsb_helper.exe"

(** 
{[
mkp "a/b/c/d"
]}
*)
let rec mkp dir = 
  if not (Sys.file_exists dir) then 
    let parent_dir  = Filename.dirname dir in
    if  parent_dir = Filename.current_dir_name then 
      Unix.mkdir dir 0o777 (* leaf node *)
    else 
      begin 
        mkp parent_dir ; 
        Unix.mkdir dir 0o777 
      end
  else if not  @@ Sys.is_directory dir then 
    failwith ( dir ^ " exists but it is not a directory, plz remove it first")
  else ()


let get_list_string_acc s acc = 
  Ext_array.to_list_map_acc  (fun (x : Ext_json_types.t) ->
      match x with 
      | `Str x -> Some x.str
      | _ -> None
    ) s  acc 

let get_list_string s = get_list_string_acc s []   

let bsc_group_1_includes = "bsc_group_1_includes"
let bsc_group_2_includes = "bsc_group_2_includes"
let bsc_group_3_includes = "bsc_group_3_includes"
let bsc_group_4_includes = "bsc_group_4_includes"
let string_of_bsb_dev_include i = 
  match i with 
  | 1 -> bsc_group_1_includes 
  | 2 -> bsc_group_2_includes
  | 3 -> bsc_group_3_includes
  | 4 -> bsc_group_4_includes
  | _ -> 
    "bsc_group_" ^ string_of_int i ^ "_includes"

(* Key is the path *)
let (|?)  m (key, cb) =
  m  |> Ext_json.test key cb



(**
  TODO: check duplicate package name
   ?use path as identity?
*)
let rec walk_all_deps top dir cb =
  let bsconfig_json =  (dir // Literals.bsconfig_json) in
  match Ext_json_parse.parse_json_from_file bsconfig_json with
  | `Obj map ->
    map
    |?
    (Bsb_build_schemas.bs_dependencies,
      `Arr (fun (new_packages : Ext_json_types.t array) ->
         new_packages
         |> Array.iter (fun (js : Ext_json_types.t) ->
          begin match js with
          | `Str {str = new_package} ->
            begin match Bs_pkg.resolve_bs_package ~cwd:dir new_package with
            | None -> 
              Bsb_exception.error (Bsb_exception.Package_not_found (new_package, Some bsconfig_json))
            | Some package_dir  ->
              walk_all_deps  false package_dir cb  ;
            end;
          | _ -> () (* TODO: add a log framework, warning here *)
          end
      )))
    |> ignore ;
    cb top dir
  | _ -> ()
  | exception _ -> failwith ( "failed to parse" ^ bsconfig_json ^ " properly")
    
