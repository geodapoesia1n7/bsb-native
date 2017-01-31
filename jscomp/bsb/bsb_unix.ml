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



type command = 
  { 
    cmd : string ;
    cwd : string ; 
    args : string array 
  }  



let run_command_execv_unix  cmd =
  match Unix.fork () with 
  | 0 -> 
    print_endline ( "* Entering " ^ cmd.cwd);
    print_string "* " ; 
    for i = 0 to Array.length cmd.args - 1 do
      print_string cmd.args.(i);
      print_string " "
    done;
    print_newline ();
    Unix.chdir cmd.cwd;
    Unix.execv cmd.cmd cmd.args 
  | pid -> 
    match Unix.waitpid [] pid  with 
    | pid, process_status ->       
      match process_status with 
      | Unix.WEXITED eid ->
        if eid <> 0 then 
          begin 
            prerr_endline ("* Failure : " ^ cmd.cmd ^ "\n* Location: " ^ cmd.cwd);
            exit eid    
          end;

      | Unix.WSIGNALED _ | Unix.WSTOPPED _ -> 
        begin 
          prerr_endline (cmd.cmd ^ " interrupted");
          exit 2 
        end        


(** TODO: the args are not quoted, here 
  we are calling a very limited set of `bsb` commands, so that 
  we are safe
*)
let run_command_execv_win (cmd : command) =
  let old_cwd = Unix.getcwd () in 
  print_endline ( "* Entering " ^ cmd.cwd ^ " from  "  ^ old_cwd);
  print_string "* " ; 
  for i = 0 to Array.length cmd.args - 1 do
    print_string cmd.args.(i);
    print_string " "
  done;
  print_newline ();
  
  Unix.chdir cmd.cwd;
  let eid = Sys.command (String.concat " " (Array.to_list cmd.args)) in 
  if eid <> 0 then 
    begin 
      prerr_endline ("* Failure : " ^ cmd.cmd ^ "\n* Location: " ^ cmd.cwd);
      exit eid    
    end
  else  begin 
    print_endline ("* Leaving " ^ cmd.cwd ^ " into " ^ old_cwd );
    Unix.chdir old_cwd
  end


let run_command_execv = 
    if Ext_sys.is_windows_or_cygwin then 
      run_command_execv_win
    else run_command_execv_unix  
(** it assume you have permissions, so always catch it to fail 
    gracefully
*)

let rec remove_dir_recursive dir = 
  if Sys.is_directory dir then 
    begin 
      let files = Sys.readdir dir in 
      for i = 0 to Array.length files - 1 do 
        remove_dir_recursive (Filename.concat dir (Array.unsafe_get files i))
      done ;
      Unix.rmdir dir 
    end
  else Sys.remove dir 
