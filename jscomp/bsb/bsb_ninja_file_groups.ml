(* Copyright (C) 2017 Authors of BuckleScript
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

let (//) = Ext_filename.combine

type info =
  { all_config_deps : string list  ; (* Figure out [.d] files *)
  }

let zero : info =
  { all_config_deps = [] ;
  }

let (++) (us : info) (vs : info) =
  if us == zero then vs else
  if vs == zero then us
  else
    {
      all_config_deps  = us.all_config_deps @ vs.all_config_deps;
    }



let handle_generators oc 
    (group : Bsb_parse_sources.file_group) custom_rules =   
  let map_to_source_dir = 
    (fun x -> Bsb_config.proj_rel (group.dir //x )) in
  group.generators
  |> List.iter (fun  ({output; input; command}  : Bsb_parse_sources.build_generator)-> 
      begin match String_map.find_opt command custom_rules with 
        | None -> Ext_pervasives.failwithf ~loc:__LOC__ "custom rule %s used but  not defined" command
        | Some rule -> 
          begin match output, input with
            | output::outputs, input::inputs -> 
              Bsb_ninja_util.output_build oc 
                ~outputs:(List.map map_to_source_dir  outputs)
                ~inputs:(List.map map_to_source_dir inputs) 
                ~output:(map_to_source_dir output)
                ~input:(map_to_source_dir input)
                ~rule
            | [], _ 
            | _, []  -> Ext_pervasives.failwithf ~loc:__LOC__ "either output or input can not be empty in rule %s" command
          end
      end
    )


let make_common_shadows package_specs dirname dir_index 
  : Bsb_ninja_util.shadow list 
  =
  { key = Bsb_ninja_global_vars.bs_package_flags;
    op = 
      Bsb_ninja_util.Append
        (String_set.fold (fun s acc ->
             Ext_string.inter2 acc (Bsb_config.package_flag ~format:s dirname )

           ) package_specs Ext_string.empty)
  } ::
  (if Bsb_dir_index.is_lib_dir dir_index  then [] else
     [{
       key = "bs_package_includes"; 
       op = Append "$bs_package_dev_includes"
     }
      ;
      { key = "bsc_extra_includes";
        op = Overwrite
            ("${" ^ Bsb_dir_index.string_of_bsb_dev_include dir_index  ^ "}")

      }
     ]
  )   

type file_kind = 
  | Ml  
  | Re 
  | Mli 
  | Rei  

let handle_module_info 
    (group : Bsb_parse_sources.file_group)
    package_specs js_post_build_cmd
    oc  module_name 
    ( module_info : Binary_cache.module_info)
    info  =
  let emit_build (kind : file_kind)  file_input : info =

    let filename_sans_extension = Filename.chop_extension file_input in
    let input = Bsb_config.proj_rel file_input in
    let output_file_sans_extension = filename_sans_extension in
    let output_mlast = output_file_sans_extension  ^ Literals.suffix_mlast in
    let output_mlastd = output_file_sans_extension ^ Literals.suffix_mlastd in
    let output_mliast = output_file_sans_extension ^ Literals.suffix_mliast in
    let output_mliastd = output_file_sans_extension ^ Literals.suffix_mliastd in
    let output_cmi = output_file_sans_extension ^ Literals.suffix_cmi in
    let output_cmj =  output_file_sans_extension ^ Literals.suffix_cmj in
    let output_js =
      String_set.fold (fun s acc ->
          Bsb_config.package_output ~format:s (Ext_filename.output_js_basename output_file_sans_extension)
          :: acc
        ) package_specs []
    in
    let common_shadows = 
      make_common_shadows package_specs
        (Filename.dirname output_cmi)
        group.dir_index in
    begin match kind with
      | Ml
      | Re ->
        let input, rule  =
          if kind = Re then
            input, Bsb_rule.build_ast_and_deps_from_reason_impl
          else
            input, Bsb_rule.build_ast_and_deps
        in
        begin
          Bsb_ninja_util.output_build oc
            ~output:output_mlast
            ~input
            ~rule;
          Bsb_ninja_util.output_build
            oc
            ~output:output_mlastd
            ~input:output_mlast
            ~rule:Bsb_rule.build_bin_deps
            ?shadows:(if Bsb_dir_index.is_lib_dir group.dir_index then None
                      else Some [{Bsb_ninja_util.key = Bsb_build_schemas.bsb_dir_group ; 
                                  op = 
                                    Overwrite (string_of_int (group.dir_index :> int)) }])
          ;
          let rule_name , cm_outputs, deps =
            if module_info.mli = Mli_empty then
              Bsb_rule.build_cmj_cmi_js, [output_cmi], []
            else  Bsb_rule.build_cmj_js, []  , [output_cmi]

          in
          let shadows =
            match js_post_build_cmd with
            | None -> common_shadows
            | Some cmd ->
              {key = "postbuild";
               op = Overwrite ("&& " ^ cmd ^ Ext_string.single_space ^ String.concat Ext_string.single_space output_js)} 
              :: common_shadows
          in
          Bsb_ninja_util.output_build oc
            ~output:output_cmj
            ~shadows
            ~outputs:  (output_js @ cm_outputs)
            ~input:output_mlast
            ~implicit_deps:deps
            ~rule:rule_name ;
          {all_config_deps = [output_mlastd] }

        end
      | Mli
      | Rei ->
        let rule =
          if kind = Mli then Bsb_rule.build_ast_and_deps
          else Bsb_rule.build_ast_and_deps_from_reason_intf  in
        Bsb_ninja_util.output_build oc
          ~output:output_mliast
          ~input
          ~rule;
        Bsb_ninja_util.output_build oc
          ~output:output_mliastd
          ~input:output_mliast
          ~rule:Bsb_rule.build_bin_deps
          ?shadows:(if Bsb_dir_index.is_lib_dir group.dir_index  then None
                    else Some [{
                        key = Bsb_build_schemas.bsb_dir_group; 
                        op = 
                          Overwrite (string_of_int (group.dir_index :> int )) }])
        ;
        Bsb_ninja_util.output_build oc
          ~shadows:common_shadows
          ~output:output_cmi
          ~input:output_mliast
          ~rule:Bsb_rule.build_cmi;
        {
          all_config_deps = [output_mliastd];
        }

    end
  in
  begin match module_info.ml with
    | Ml input -> emit_build Ml input
    | Re input -> emit_build Re input
    | Ml_empty -> zero
  end ++
  begin match module_info.mli with
    | Mli mli_file  ->
      emit_build Mli mli_file
    | Rei rei_file ->
      emit_build Rei rei_file
    | Mli_empty -> zero
  end ++
  info


let handle_file_group oc ~custom_rules 
    ~package_specs ~js_post_build_cmd  
    (files_to_install : String_hash_set.t) acc (group: Bsb_parse_sources.file_group) : info =

  handle_generators oc group custom_rules ;
  String_map.fold (fun  module_name module_info  acc ->
      let installable =
        match group.public with
        | Export_all -> true
        | Export_none -> false
        | Export_set set ->  String_set.mem module_name set in
      if installable then 
        String_hash_set.add files_to_install (Binary_cache.basename_of_module_info module_info);
      handle_module_info group 
        package_specs js_post_build_cmd 
        oc module_name module_info acc
    ) group.sources  acc 


let handle_file_groups
    oc ~package_specs ~js_post_build_cmd
    ~files_to_install ~custom_rules
    (file_groups  :  Bsb_parse_sources.file_group list) st =
  List.fold_left 
  (handle_file_group oc ~package_specs ~custom_rules ~js_post_build_cmd files_to_install ) 
  st  file_groups
