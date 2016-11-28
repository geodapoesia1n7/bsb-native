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


module Rules = struct

  let rule_id = ref 0
  let rule_names = ref String_set.empty
  let ask_name name = 
    let current_id = !rule_id in
    let () = incr rule_id in
    match String_set.find name !rule_names with
    | exception Not_found ->
      rule_names := String_set.add name !rule_names ;
      name
    | _ ->
      begin (* could be improved later
               1. instead of having a global id, having a unique id per rule name
               2. the rule id is increased only when actually used
            *)
        let new_name =  (name ^ Printf.sprintf "_%d" current_id) in
        rule_names := String_set.add new_name  !rule_names ;
        new_name
      end
  type t = { mutable used : bool; rule_name : string  ; name : out_channel -> string }
  let get_name (x : t) oc = x.name oc
  let print_rule oc ~description ?restat ?depfile ~command   name  = 
    output_string oc "rule "; output_string oc name ; output_string oc "\n";
    output_string oc "  command = "; output_string oc command; output_string oc "\n";
    begin match depfile with
      | None -> ()
      | Some f ->
        output_string oc "  depfile = "; output_string oc f; output_string oc  "\n"
    end;
    begin match restat with
      | None -> ()
      | Some () ->
        output_string oc "  restat = 1"; output_string oc  "\n"
    end;

    output_string oc "  description = " ; output_string oc description; output_string oc "\n"


  let define
      ~command
      ?depfile
      ?restat
      ?(description = "Building ${out}")
      name
    = 
    let rec self = {
      used  = false;
      rule_name = ask_name name ; 
      name = fun oc -> 
        if not self.used then 
          begin 
            print_rule oc ~description ?depfile ?restat ~command name; 
            self.used <- true
          end ;
          self.rule_name
    } in self


  let build_ast_and_deps = 
    define
      ~command:"${bsc}  ${pp_flags} ${ppx_flags} ${bsc_flags} -c -o ${out} -bs-syntax-only -bs-binary-ast ${in}"
      "build_ast_and_deps"

  let build_ast_and_deps_from_reason_impl =
    define
      ~command:"${bsc} -pp ${refmt} ${ppx_flags} ${bsc_flags} -c -o ${out} -bs-syntax-only -bs-binary-ast -impl ${in}"
      "build_ast_and_deps_from_reason_impl"

  let build_ast_and_deps_from_reason_intf =
    (* we have to do this way,
       because it need to be ppxed by bucklescript
    *)
    define
      ~command:"${bsc} -pp ${refmt} ${ppx_flags} ${bsc_flags} -c -o ${out} -bs-syntax-only -bs-binary-ast -intf ${in}"
      "build_ast_and_deps_from_reason_intf"


  let build_bin_deps =
    define
      ~command:"${bsdep}  -bs-bin-MD ${in}"
      "build_deps"

  let reload =
    define
      ~command:"${bsbuild} -init"
      "reload"
  let copy_resources =
    define
      ~command:"cp ${in} ${out}"
      "copy_resources"


  let ocaml_bin_install =
    define ~command:"cp ${in} ${out}"
      "ocaml_bin_install"
  (* only generate mll no mli generated *)
  (* actually we would prefer generators in source ?
     generator are divided into two categories:
     1. not system dependent (ocamllex,ocamlyacc)
     2. system dependent - has to be run on client's machine
  *)

  let build_ml_from_mll =
    define
      ~command:"${ocamllex} -o ${out} ${in}"
      "build_ml_from_mll"
  (**************************************)
  (* below are rules not local any more *)
  (**************************************)
  let build_cmj_js =
    define
      ~command:"${bsc} ${bs_package_flags} -bs-no-builtin-ppx-ml -bs-no-implicit-include  \
                ${bs_package_includes} ${bsc_includes} ${bsc_flags} -o ${in} -c  ${in} ${postbuild}"

      ~depfile:"${in}.d"
      "build_cmj_only"

  let build_cmi_cmj_js =
    define
      ~command:"${bsc} ${bs_package_flags} -bs-assume-no-mli -bs-no-builtin-ppx-ml -bs-no-implicit-include \
                ${bs_package_includes} ${bsc_includes} ${bsc_flags} -o ${in} -c  ${in} ${postbuild}"
      ~depfile:"${in}.d"
      "build_cmj_cmi"
  let build_cmi =
    define
      ~command:"${bsc} ${bs_package_flags} -bs-no-builtin-ppx-mli -bs-no-implicit-include \
                ${bs_package_includes} ${bsc_includes} ${bsc_flags} -o ${out} -c  ${in}"
      ~depfile:"${in}.d"
      "build_cmi"
end

let output_build
    ?(order_only_deps=[])
    ?(implicit_deps=[])
    ?(outputs=[])
    ?(implicit_outputs=[])
    ?(inputs=[])
    ?(shadows=[])
    ?restat
    ~output
    ~input
    ~rule
    oc =
  let rule = Rules.get_name rule  oc in
  output_string oc "build ";
  output_string oc output ;
  outputs |> List.iter (fun s -> output_string oc " " ; output_string oc s  );
  begin match implicit_outputs with 
  | [] -> ()
  | _ ->
    output_string oc " | ";
    implicit_outputs |> List.iter (fun s -> output_string oc " " ; output_string oc s)
  end;
  output_string oc " : ";
  output_string oc rule;
  output_string oc " ";
  output_string oc input;
  inputs |> List.iter (fun s ->   output_string oc " " ; output_string oc s);
  begin match implicit_deps with
    | [] -> ()
    | _ ->
      begin
        output_string oc " | ";
        implicit_deps
        |>
        List.iter (fun s -> output_string oc " "; output_string oc s )
      end
  end;
  begin match order_only_deps with
    | [] -> ()
    | _ ->
      begin
        output_string oc " || ";
        order_only_deps
        |>
        List.iter (fun s -> output_string oc " " ; output_string oc s)
      end
  end;
  output_string oc "\n";
  begin match shadows with
    | [] -> ()
    | xs ->
      List.iter (fun (k,v) ->
          output_string oc "  " ;
          output_string oc k ;
          output_string oc " = ";
          match v with
          | `Overwrite s -> output_string oc s ; output_string oc "\n"
          | `Append s ->
            output_string oc "$" ;
            output_string oc k;
            output_string oc " ";
            output_string oc s ; output_string oc "\n"
        ) xs
  end;
begin match restat with
| None -> ()
| Some () ->
  output_string oc " " ;
  output_string oc "restat = 1 \n"
end


let phony ?(order_only_deps=[]) ~inputs ~output oc =
  output_string oc "build ";
  output_string oc output ;
  output_string oc " : ";
  output_string oc "phony";
  output_string oc " ";
  inputs |> List.iter (fun s ->   output_string oc " " ; output_string oc s);
  begin match order_only_deps with
    | [] -> ()
    | _ ->
      begin
        output_string oc " || ";
        order_only_deps
        |>
        List.iter (fun s -> output_string oc " " ; output_string oc s)
      end
  end;
  output_string oc "\n"

let output_kv key value oc  =
  output_string oc key ;
  output_string oc " = ";
  output_string oc value ;
  output_string oc "\n"

let output_kvs kvs oc =
  List.iter (fun (k,v) -> output_kv k v oc) kvs



let (//) = Ext_filename.combine
type info = string list  * string list

let zero : info = ([],[])

let (++) (us : info) (vs : info) =
  if us == zero then vs else
  if vs == zero then us
  else
    let (xs,ys) = us in
    let (xxs,yys) = vs in
    (xs @ xxs, ys @ yys)




let handle_file_group oc ~js_post_build_cmd  acc (group: Bsb_build_ui.file_group) =
  let handle_module_info  oc  module_name
      ( module_info : Binary_cache.module_info)
      bs_dependencies
      info  =
    let installable =
      match group.public with
      | Export_all -> true
      | Export_none -> false
      | Export_set set ->  String_set.mem module_name set in
    let emit_build (kind : [`Ml | `Mll | `Re | `Mli | `Rei ])  input  =
      let filename_sans_extension = Filename.chop_extension input in
      let input = Bsb_config.proj_rel input in
      let output_file_sans_extension = filename_sans_extension in
      let output_ml = output_file_sans_extension ^ Literals.suffix_ml in
      let output_mlast = output_file_sans_extension  ^ Literals.suffix_mlast in
      let output_mlastd = output_file_sans_extension ^ Literals.suffix_mlastd in
      let output_mliast = output_file_sans_extension ^ Literals.suffix_mliast in
      let output_mliastd = output_file_sans_extension ^ Literals.suffix_mliastd in
      let output_cmi = output_file_sans_extension ^ Literals.suffix_cmi in
      let output_cmj =  output_file_sans_extension ^ Literals.suffix_cmj in
      let output_js = Bsb_config.proj_rel @@ Bsb_config.common_js_prefix
          output_file_sans_extension ^ Literals.suffix_js in
      (* let output_mldeps = output_file_sans_extension ^ Literals.suffix_mldeps in  *)
      (* let output_mlideps = output_file_sans_extension ^ Literals.suffix_mlideps in  *)
      let shadows =
        let package_flags =
          [ "bs_package_flags",
            `Append ("-bs-package-output commonjs:"^
                     Bsb_config.common_js_prefix @@ Filename.dirname output_cmi)
            (* FIXME: assume that output is calculated correctly*)
          ]
        in

        match bs_dependencies with
        | [] -> package_flags
        | _ ->
          (
            "bs_package_includes",
            `Append 
              (Bsb_build_util.flag_concat "-bs-package-include" bs_dependencies)
          )
          :: package_flags
      in
      if kind = `Mll then
        output_build oc
          ~output:output_ml
          ~input
          ~rule: Rules.build_ml_from_mll ;
      begin match kind with
        | `Mll
        | `Ml
        | `Re ->
          let input, rule  =
            if kind = `Re then
              input, Rules.build_ast_and_deps_from_reason_impl
            else if kind = `Mll then
              output_ml, Rules.build_ast_and_deps
            else
              input, Rules.build_ast_and_deps
          in
          begin
            output_build oc
              ~output:output_mlast 
              (* ~implicit_outputs:[output_mldeps] *)
              ~input
              ~rule;
            output_build 
              oc
              ~output:output_mlastd
              ~input:output_mlast
              ~rule:Rules.build_bin_deps ;
            let rule_name , cm_outputs, deps =
              if module_info.mli = Mli_empty then
                Rules.build_cmj_js,
                [  output_cmi]  , []
              else Rules.build_cmi_cmj_js, [], [output_cmi]
            in
            let shadows = 
              match js_post_build_cmd with 
              | None -> shadows 
              | Some cmd -> 
                ("postbuild", 
                `Overwrite ("&& " ^ cmd ^ " " ^ output_js)) :: shadows
            in 
            output_build oc
              ~output:output_cmj
              ~shadows
              ~outputs:  (output_js:: cm_outputs)
              ~input:output_mlast 
              ~implicit_deps:deps
              ~rule:rule_name ;
            if installable then
              begin
                output_cmj :: cm_outputs
                |> List.iter
                  (
                    fun x ->
                      output_build oc
                        ~output:(Bsb_config.proj_rel @@
                                 Bsb_config.ocaml_bin_install_prefix @@ Filename.basename x)
                        ~input:x
                        ~rule:Rules.copy_resources
                  )
              end;
            ([output_mlastd] , [output_cmi])
          end
        | `Mli
        | `Rei ->
          let rule =
            if kind = `Mli then Rules.build_ast_and_deps
            else Rules.build_ast_and_deps_from_reason_intf  in
          output_build oc
            ~output:output_mliast
            (* ~implicit_outputs:[output_mlideps] *)
            ~input
            ~rule;
          output_build oc
            ~output:output_mliastd
            ~input:output_mliast
            ~rule:Rules.build_bin_deps  ;
          output_build oc
            ~shadows
            ~output:output_cmi
            ~input:output_mliast
            (* ~implicit_deps:[output_mliastd] *)
            ~rule:Rules.build_cmi;
          if installable then
            begin
              output_build oc
                ~output:(Bsb_config.proj_rel @@
                         Bsb_config.ocaml_bin_install_prefix @@
                         Filename.basename output_cmi)
                ~input:output_cmi
                ~rule:Rules.copy_resources
            end;
          ([output_mliastd] ,
           [output_cmi]  )
      end
    in
    begin match module_info.ml with
      | Ml input -> emit_build `Ml input
      | Re input -> emit_build `Re input
      | Ml_empty -> zero
    end ++
    begin match module_info.mli with
      | Mli mli_file  ->
        emit_build `Mli mli_file
      | Rei rei_file ->
        emit_build `Rei rei_file
      | Mli_empty -> zero
    end ++
    begin match module_info.mll with
      | Some mll_file ->
        begin match module_info.ml with
          | Ml_empty -> emit_build `Mll mll_file
          | Ml input | Re input ->
            failwith ("both "^ mll_file ^ " and " ^ input ^ " are found in source listings" )
        end
      | None -> zero
    end ++ info

  in
  String_map.fold (fun  k v  acc ->
      handle_module_info  oc k v group.bs_dependencies acc
    ) group.sources  acc


let handle_file_groups oc ~js_post_build_cmd (file_groups  :  Bsb_build_ui.file_group list) st =
      List.fold_left (handle_file_group oc ~js_post_build_cmd ) st  file_groups
