open GMain
open GdkKeysyms
module Gset = Core.Gset

let locale = GtkMain.Main.init ();;

let notimp_callback = (fun () -> prerr_endline "Not Implemented");;

(* Pops up a "Do you want to quit" dialog and returns the answer *)
let confirm_quit () =
    let dialog = GToolbox.question_box
        ~title:"Confirm"
        ~buttons:["Yes";"No"]
        "Do you really want to quit ?" in
    match dialog with
    | 0 | 2 -> false
    | 1 -> true
    | _ -> false
;;


(** This function is the actual main function, that handles the gui loop *)
let main () =
    let window = GWindow.window ~resizable:true ~width:1280 ~height:720
                                    ~title:"Awesome Ocaml IDE"
                                    ~position:`CENTER () in
    let vbox = GPack.vbox ~homogeneous:false ~spacing:0 ~packing:window#add () in
    ignore (
        window#event#connect#delete
        ~callback: (fun _ -> false (* not (confirm_quit ())*))
    );
    ignore (window#connect#destroy ~callback: Main.quit);

    (* Menu bar *)
    let menubar = GMenu.menu_bar ~packing:vbox#pack () in
    let factory = new GMenu.factory menubar in
    let accel_group = factory#accel_group in
    let file_menu = factory#add_submenu "File" in
    let edit_menu = factory#add_submenu "Edit" in

    let test_set =
        let a = new Gset.set("A")
        and aa = new Gset.set("AA")
        and ab = new Gset.set("AB") in
        a#add_child aa;
        a#add_child ab;
        let b = new Gset.set("B")
        and ba = new Gset.set("BA") in
        b#add_child ba;
        a
    in
    (* Edit menu *)
    let factory = new GMenu.factory edit_menu ~accel_group in
    ignore(factory#add_item "Find" ~key:_F
        ~callback: (fun () -> ignore(GuiFindDialog.find_dialog window test_set)));

    (* Navlist *)
    let navlist = new GuiNavlist.navlist ~packing:vbox#add in

    (* Import callback *)
    (* This function opens a folder chooser dialog and imports the
     * project there *)
    let import_callback () : unit =
        let file_chooser =
            GWindow.file_chooser_dialog ~parent:window
                                        ~action:`SELECT_FOLDER
                                        ~show:true () in
        file_chooser#add_select_button_stock `CANCEL `CANCEL;
        file_chooser#add_select_button "Open" `SELECT_FOLDER;
        let _import () : unit =
            let path = match file_chooser#filename with
            | Some p -> p
            | None -> "No file"
            in
            Printf.printf "Loading with first plugin at %s\n%!" path;
            let plugin = List.hd (Plugins.Factory.get_plugins ()) in
            let ast = plugin#path_to_c_ast path in
            Core.Miscs.print_c_ast (fst ast);
            navlist#set_root (fst ast)
        in
        begin
            match file_chooser#run () with
            | `SELECT_FOLDER -> _import ()
            | `CANCEL -> ()
            | _ -> ()
        end;
        file_chooser#destroy ()
    in

    (* File menu *)
    let factory = new GMenu.factory file_menu ~accel_group in
    ignore(factory#add_item "Import" ~key:_I ~callback: import_callback);
    ignore(factory#add_item "Export" ~key:_E ~callback: notimp_callback);
    ignore(factory#add_item "Quit" ~key:_Q
        ~callback: (fun () -> if confirm_quit () then Main.quit ()));

    (* Frame *)
    let frame = GBin.frame ~label:"Code" ~packing:vbox#add () in

    (* Text view *)
    ignore(GText.view ~packing:frame#add ());

    (* Display the windows and enter Gtk+ main loop *)
    window#add_accel_group accel_group;
    window#show ();
    Main.main ()
;;

let () =
    ignore(locale)
;;
