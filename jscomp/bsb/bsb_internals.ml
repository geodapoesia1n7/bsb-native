(* build_script.exe vendor_dir ocaml_lib cwd root_project_dir -verbose *)

let _ = if Array.length Sys.argv != 5 && Array.length Sys.argv != 6 then begin
  print_endline "This binary is only for bsb's internal use";
  exit 1
end

let vendor_dir = Sys.argv.(1)
let ocaml_lib = Sys.argv.(2)
let cwd = Sys.argv.(3)
let root_project_dir = Sys.argv.(4)
let verbose = (6 = Array.length Sys.argv)

let ( // ) = Filename.concat

let mingw_dir = vendor_dir // "mingw32"
let node_modules = root_project_dir // "node_modules"

let _ = Sys.chdir cwd

let _ = if Ext_sys.is_windows_or_cygwin then
  Unix.putenv "Path" (mingw_dir ^ ";" ^ Unix.getenv("Path"))
 else ()

let checkInputTimestamps outfile_mtime includes srcs =
  let rec should_build = function 
    | [] -> false
    | file :: rest ->
      let path = if Filename.is_relative file then cwd // file else file in
      match (Unix.stat path) with
      | exception (Unix.Unix_error (Unix.ENOENT, _, _)) -> should_build rest
      | {Unix.st_mtime} -> 
        if st_mtime > outfile_mtime then 
          true
        else 
          should_build rest  
  in
  should_build srcs || should_build includes

let gcc ?c:(c=true) ?include_ocaml:(include_ocaml=true) ?flags:(flags=[]) ?includes:(includes=[]) outfile srcs = 
  let output = if Filename.is_relative outfile then cwd // outfile else outfile in
  let should_build = match (Unix.(stat output)) with
    | exception (Unix.Unix_error (Unix.ENOENT, _, _)) -> true
    | {Unix.st_mtime} -> checkInputTimestamps st_mtime includes srcs
  in
  if should_build then begin
    let dash_c = if c then "-c" else "" in
    let all_includes = if List.length includes > 0 then 
      "-I " ^ (String.concat " -I " (List.map (fun i -> 
        if Filename.is_relative i then cwd // i else i
      ) includes)) 
    else "" in
    let include_ocaml_flag = if include_ocaml then "-I " ^ ocaml_lib else "" in
    let compiler = if Ext_sys.is_windows_or_cygwin then "gcc.exe" else "gcc" in
    if Ext_sys.is_windows_or_cygwin then
      Sys.chdir mingw_dir;
    let cmd = compiler
      :: dash_c
      :: ("-o " ^ output)
      :: all_includes
      :: include_ocaml_flag
      :: (flags @ (List.map (fun s -> if Filename.is_relative s then cwd // s else s) srcs)) in
    
    if verbose then begin
      print_endline "Bsb_internal command:";
      print_endline ((String.concat " " cmd) ^ "\n");
    end;
    
    let err = Sys.command (String.concat " " cmd) in
    if Ext_sys.is_windows_or_cygwin then
      Sys.chdir cwd;
    if err != 0 then
      failwith ("gcc compilation failed for: " ^ outfile);
    err
  end else 0
