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


let config_file_bak = "bsconfig.json.bak"

let bsdeps = ".bsdeps"



(* Key is the path *)
let (|?)  m (key, cb) =
  m  |> Ext_json.test key cb

let (//) = Ext_filename.combine

let bs_file_groups = ref []

let sourcedirs_meta = ".sourcedirs"
let merlin = ".merlin"
let merlin_header = "####{BSB GENERATED: NO EDIT"
let merlin_trailer = "####BSB GENERATED: NO EDIT}"
let merlin_trailer_length = String.length merlin_trailer

(** [new_content] should start end finish with newline *)
let revise_merlin new_content =
  if Sys.file_exists merlin then
    let merlin_chan = open_in_bin merlin in
    let size = in_channel_length merlin_chan in
    let s = really_input_string merlin_chan size in
    let () =  close_in merlin_chan in

    let header =  Ext_string.find s ~sub:merlin_header  in
    let tail = Ext_string.find s ~sub:merlin_trailer in
    if header < 0  && tail < 0 then (* locked region not added yet *)
      let ochan = open_out_bin merlin in
      output_string ochan s ;
      output_string ochan "\n";
      output_string ochan merlin_header;
      Buffer.output_buffer ochan new_content;
      output_string ochan merlin_trailer ;
      output_string ochan "\n";
      close_out ochan
    else if header >=0 && tail >= 0  then 
      (* there is one, hit it everytime,
         should be fixed point
      *)
      let ochan = open_out_bin merlin in
      output_string ochan (String.sub s 0 header) ;
      output_string ochan merlin_header;
      Buffer.output_buffer ochan new_content;
      output_string ochan merlin_trailer ;
      output_string ochan (Ext_string.tail_from s (tail +  merlin_trailer_length));
      close_out ochan
    else failwith ("the .merlin is corrupted, locked region by bsb is not consistent ")
  else
    let ochan = open_out_bin merlin in
    output_string ochan merlin_header ;
    Buffer.output_buffer ochan new_content;
    output_string ochan merlin_trailer ;
    output_string ochan "\n";
    close_out ochan
(*TODO: it is a little mess that [cwd] and [project dir] are shared*)
(** *)
let write_ninja_file bsc_dir cwd =
  let builddir = Bsb_config.lib_bs in
  let () = Bsb_build_util.mkp builddir in
    let bsc, bsdep, bsppx =
    bsc_dir // "bsc.exe",
    bsc_dir // "bsb_helper.exe",
    bsc_dir // "bsppx.exe" in

  let update_queue = ref [] in
  let globbed_dirs = ref [] in
  (* ATTENTION: order matters here, need resolve global properties before
     merlin generation
  *)
  let handle_bsb_build_ui (res : Bsb_build_ui.t) =
    let ochan = open_out_bin (builddir // sourcedirs_meta) in
    let lib_ocaml_dir = (bsc_dir // ".."//"lib"//"ocaml") in
    let buffer = Buffer.create 100 in
    let () =
      Bsb_default.get_ppx_flags ()
      |> List.iter (fun x ->
          Buffer.add_string buffer (Printf.sprintf "\nFLG -ppx %s" x )
        )
    in
    let () = Buffer.add_string buffer
        (Printf.sprintf "\n\
                         S %s\n\
                         B %s\n\
                         FLG -ppx %s\n\
                       " lib_ocaml_dir lib_ocaml_dir bsppx
        ) in
    let () = 
      match Bsb_default.get_bsc_flags () with 
      | [] -> ()
      | xs -> 
        Buffer.add_string buffer 
          (Printf.sprintf "\nFLG %s" (String.concat " " xs) ) in 
    let () =
      Bsb_default.get_bs_dependencies ()
      |> List.iter (fun package ->
          let path = (Bsb_default.resolve_bsb_magic_file ~cwd ~desc:"dependecies"
                         (package ^ "/")// "lib"//"ocaml") in
          Buffer.add_string buffer "\nS ";
          Buffer.add_string buffer path ;
          Buffer.add_string buffer "\nB ";
          Buffer.add_string buffer path ;
          Buffer.add_string buffer "\n";

        )
    in
    res.files |> List.iter
      (fun (x : Bsb_build_ui.file_group) ->
         output_string ochan x.dir; (* to [.sourcedirs] *)
         output_string ochan "\n" ;
         Buffer.add_string buffer "\nS ";
         Buffer.add_string buffer x.dir ;
         Buffer.add_string buffer "\nB ";
         Buffer.add_string buffer ("lib"//"bs"//x.dir) ;
         Buffer.add_string buffer "\n"
      ) ;
    close_out ochan;
    bs_file_groups := res.files ;
    update_queue := res.intervals;
    globbed_dirs := res.globbed_dirs;
    if Bsb_default.get_generate_merlin () then
      revise_merlin buffer ;
  in
  let config_json_chan = open_in_bin Literals.bsconfig_json in
  let global_data = Ext_json.parse_json_from_chan config_json_chan  in

  let () =
    match global_data with
    | `Obj map ->
      map
      |? (Bsb_build_schemas.generate_merlin, `Bool (fun b ->
          Bsb_default.set_generate_merlin b
        ))
      |?  (Bsb_build_schemas.name, `Str Bsb_default.set_package_name)
      |? (Bsb_build_schemas.package_specs, `Arr Bsb_default.set_package_specs_from_array )
      |? (Bsb_build_schemas.js_post_build, `Obj begin fun m ->
          m |? (Bsb_build_schemas.cmd , `Str (Bsb_default.set_js_post_build_cmd ~cwd)
               )
          |> ignore
        end)
      |? (Bsb_build_schemas.ocamllex, `Str (Bsb_default.set_ocamllex ~cwd))
      |? (Bsb_build_schemas.ninja, `Str (Bsb_default.set_ninja ~cwd))
      |? (Bsb_build_schemas.bs_dependencies, `Arr Bsb_default.set_bs_dependencies)
      (* More design *)
      |? (Bsb_build_schemas.bs_external_includes, `Arr Bsb_default.set_bs_external_includes)
      |? (Bsb_build_schemas.bsc_flags, `Arr Bsb_default.set_bsc_flags)
      |? (Bsb_build_schemas.ppx_flags, `Arr (Bsb_default.set_ppx_flags ~cwd))
      |? (Bsb_build_schemas.refmt, `Str (Bsb_default.set_refmt ~cwd))

      |? (Bsb_build_schemas.sources, `Obj (fun x ->
          let res : Bsb_build_ui.t =  
            Bsb_build_ui.parsing_source
              Bsb_build_ui.lib_dir_index
              Filename.current_dir_name x in
          handle_bsb_build_ui res
        ))
      |?  (Bsb_build_schemas.sources, `Arr (fun xs ->

          let res : Bsb_build_ui.t  =
            Bsb_build_ui.parsing_sources 
              Bsb_build_ui.lib_dir_index
              Filename.current_dir_name xs
          in
          handle_bsb_build_ui res
        ))

      |> ignore
    | _ -> ()
  in
  begin match List.sort Ext_file_pp.interval_compare  !update_queue with
    | [] -> ()
    | queue ->
      let file_size = in_channel_length config_json_chan in
      let oc = open_out_bin config_file_bak in
      let () =
        Ext_file_pp.process_wholes
          queue file_size config_json_chan oc in
      close_out oc ;
      close_in config_json_chan ;
      Unix.unlink Literals.bsconfig_json;
      Unix.rename config_file_bak Literals.bsconfig_json
  end;

  Bsb_gen.output_ninja
    ~builddir
    ~cwd
    ~js_post_build_cmd: Bsb_default.(get_js_post_build_cmd ())
    ~package_specs:(Bsb_default.get_package_specs())
    bsc
    bsdep
    (Bsb_default.get_package_name ())
    (Bsb_default.get_ocamllex ())
    (Bsb_default.get_bs_external_includes ())
    !bs_file_groups
    Bsb_default.(get_bsc_flags ())
    Bsb_default.(get_ppx_flags ())
    Bsb_default.(get_bs_dependencies ())
    Bsb_default.(get_refmt ())

  ;
  !globbed_dirs






let force_regenerate = ref false
let exec = ref false
let targets = String_vec.make 5

let cwd = Sys.getcwd ()

let create_bs_config () =
  ()
let watch () =
  let bsb_watcher =
    Bsb_build_util.get_bsc_dir cwd // "bsb_watcher.js" in
  let bsb_watcher =
    (*FIXME *)
    if Sys.win32 then Filename.quote bsb_watcher
    else bsb_watcher in
  Unix.execvp "node"
    [| "node" ;
       bsb_watcher
    |]

let no_dev = "-no-dev"
let regen = "-regen"
let separator = "--"

let build_bs_deps ()   = 
    let bsc_dir = Bsb_build_util.get_bsc_dir cwd in 
    let bsb_exe = bsc_dir // "bsb.exe" in 
    Bsb_default.walk_all_deps true cwd 
    (fun top cwd -> 
      if top then 
        Bsb_unix.run_command_execv false { cmd = bsb_exe ; cwd ; args = [|bsb_exe ; regen ; separator|]}
      else 
        Bsb_unix.run_command_execv true
        {cmd = bsb_exe; cwd = cwd; args  = [| bsb_exe ; no_dev; regen; separator |]})

let clean_bs_deps () = 
  let bsc_dir = Bsb_build_util.get_bsc_dir cwd in 
    let bsb_exe = bsc_dir // "bsb.exe" in 
    Bsb_default.walk_all_deps true cwd 
    (fun top cwd -> Bsb_unix.run_command_execv (not top)
      {cmd = bsb_exe; cwd = cwd; args  = [| bsb_exe ; separator; "-t" ; "clean"|]})
let annoymous filename =
  String_vec.push  filename targets




let bsb_main_flags =
  [
    "-w", Arg.Unit watch,
    " Watch mode" ;
    no_dev, Arg.Unit (fun _ -> Bsb_config.no_dev := true), 
    " (experimental)Build dev dependencies in make-world and dev group";
    " -no-dev", Arg.Set Bsb_config.no_dev, 
    " (experimental)Don't build dev directories(internal for -make-world)" ; 
    (*    "-init", Arg.Unit create_bs_config ,
          " Create an simple bsconfig.json"
          ;
    *)   
     regen, Arg.Set force_regenerate,
     " Always regenerate build.ninja no matter bsconfig.json is changed or not (for debugging purpose)"
    ;
    "-clean-world", Arg.Unit clean_bs_deps,
    " Clean all bs dependencies";
    "-make-world", Arg.Unit build_bs_deps,
    " Build all dependencies and itself "
  ]

let regenerate_ninja cwd bsc_dir forced =
  let output_deps = Bsb_config.lib_bs // bsdeps in
  let reason =
    if forced then "Regenerating ninja (triggered by command line -regen)"
    else
      Bsb_dep_infos.check ~cwd  output_deps in
  if String.length reason <> 0 then
    begin
      print_endline reason ;
      print_endline "Regenrating build spec";
      let globbed_dirs = write_ninja_file bsc_dir cwd in
      Literals.bsconfig_json :: globbed_dirs
      |> List.map
        (fun x ->
           { Bsb_dep_infos.dir_or_file = x ;
             stamp = (Unix.stat x).st_mtime
           }
        )
      |> (fun x -> Bsb_dep_infos.store ~cwd output_deps (Array.of_list x))

    end

let ninja_error_message = "ninja (required for bsb build system) is not installed, \n\
please visit https://github.com/ninja-build/ninja to have it installed\n"
let () = 
  Printexc.register_printer (function 
  | Unix.Unix_error(Unix.ENOENT, "execvp", "ninja") -> 
    Some ninja_error_message
  | _ -> None
  )

  
(* Note that [keepdepfile] only makes sense when combined with [deps] for optimizatoin *)
let ninja_command ninja ninja_args = 
  let ninja_args_len = Array.length ninja_args in
  if ninja_args_len = 0 then     
    Unix.execvp ninja [|"ninja"; "-C"; Bsb_config.lib_bs |]    
  else 
    let fixed_args_length = 3 in 
    begin Unix.execvp ninja 
    (Array.init (fixed_args_length + ninja_args_len)
     (fun i -> match i with 
     | 0 -> "ninja"
     | 1 -> "-C"
     | 2 -> Bsb_config.lib_bs
     | _ -> Array.unsafe_get ninja_args (i - fixed_args_length) ))
     end 
    
(**
   Cache files generated:
   - .bsdircache in project root dir
   - .bsdeps in builddir

   What will happen, some flags are really not good
   ninja -C _build
*)
let usage = "Usage : bsb.exe <bsb-options> <files> -- <ninja_options>\n\
             For ninja options, try ninja -h \n\
             ninja will be loaded either by just running `bsb.exe' or `bsb.exe .. -- ..`\n\
             It is always recommended to run ninja via bsb.exe \n\
             Bsb options are:"

let () =
  let bsc_dir = Bsb_build_util.get_bsc_dir cwd in
  let ninja = 
    if Sys.win32 then 
      bsc_dir // "ninja.exe"
    else 
      "ninja" 
    in 
  (* try *)
    (* see discussion #929 *)
    if Array.length Sys.argv <= 1 then
      begin
        regenerate_ninja cwd bsc_dir false;
        ninja_command ninja [||]
      end
    else
      begin
        match Ext_array.find_and_split Sys.argv Ext_string.equal "--" with
        | `No_split
          ->
          begin
            Arg.parse bsb_main_flags annoymous usage;
            regenerate_ninja cwd bsc_dir !force_regenerate;
            (* String_vec.iter (fun s -> print_endline s) targets; *)
            (* ninja is not triggered in this case *)
          end
        | `Split (bsb_args,ninja_args)
          ->
          begin
            Arg.parse_argv bsb_args bsb_main_flags annoymous usage ;
            (* String_vec.iter (fun s -> print_endline s) targets; *)
            regenerate_ninja cwd bsc_dir !force_regenerate;
            ninja_command ninja ninja_args
          end
      end
  (*with x ->
    prerr_endline @@ Printexc.to_string x ;
    exit 2*)
  (* with [try, with], there is no stacktrace anymore .. *)  