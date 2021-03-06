open Core.Miscs
open Core.Gset      
open Tl_ast

(** Used to make reference a string owned by a node in tl_ast, with deduplication
    needed because ocaml code can be owned by several tl_ast node for instance 
    when there is a ocaml code "type a = and b ="
    @param - namespace of the file(string) to avoid to share code between different files
    @param - code(string)
    @return a reference on code
*)  
let ptr = let db = Hashtbl.create 1024 in fun (np:string) (x:string)->
    (* db: (string, ref string) Hashtbl.t)*)
    if (Hashtbl.mem db np) = false then Hashtbl.add db np (Hashtbl.create 1024);
    let tmp = Hashtbl.find db np in 
    
    if (Hashtbl.mem tmp x) = false then Hashtbl.add tmp x (ref x); 
    Hashtbl.find tmp x 

(** Transform a Tl_ast.class_element to c_ast node
    @param np - namespace of the file
    @param cl_elmt - Tl_ast.class_element
    @return a list of Core.misc.c_ast
    @raise Bad_tl_ast if the cl_elmt represents a corrupted ocaml code*)
let rec cl_elmt_to_core (np:string) cl_elmt=
    let meta = new tags in 
    match cl_elmt with  
    |Cl_attribut tl_s->(
        meta#add_tag "plg_ast" [TStr "Cl_attribut"];
        match tl_s with
        |Tl_var(name, body)->(
            meta#add_tag "plg_desc" [ TStr "Tl_var"];
            [Node {
                name=name;
                header="";
                body= ptr np body;
                children=[];
                meta=meta;
            }]
        )
        |Tl_constraint(name, body)->(
            meta#add_tag "plg_desc" [ TStr "Tl_constraint"];
            [Node{
                name = name;
                header = "";
                body = ptr np body;
                children = [];
                meta = meta;
            }]
        )
        |_-> bad_tl_ast "cl_elmt_to_core : Cl_attribut"
    )           
    |Cl_method(tl_s, tl_v)->(
        let header = match tl_v with|Tl_private->"private"|Tl_public->"public" in
        meta#add_tag "plg_ast" [ TStr "Cl_method"];
        match tl_s with
        |Tl_fun(name, body)->(
            meta#add_tag "plg_desc" [ TStr "Tl_fun"];
            [Node {
                name=name;
                header=header;
                body= ptr np body;
                children=[];
                meta=meta;
            }]
        )
        |Tl_constraint(name, body)->(
            meta#add_tag "plg_desc" [ TStr "Tl_constraint"];
            [Node{
                name = name;
                header = header;
                body = ptr np body;
                children = [];
                meta = meta;
            }]
        )
        |_->bad_tl_ast "cl_elmt_to_core : Cl_method"                       
    )     
    |Cl_init(body)->(
        meta#add_tag "plg_ast" ([TStr "Cl_init"]:gset tag);
        [Node({
        name="";
        header="";
        body=ptr np body;
        children=[];
        meta=meta})]
    )
    |Cl_inherit(name, as_str)->(
        meta#add_tag "plg_ast" [TStr "Cl_inherit"];
        [Node({
            name=name;
            header= (match as_str with |Some s->s|None->"");
            body=ref "";
            children=[];
            meta=meta;
        })]
    )
 
(** Transform a Tl_ast.tl_struct to Core.Misc.c_ast node
    @param np - namespace of the file
    @param tl_struct - Tl_ast.tl_struct
    @return a list of Core.misc.c_ast
    @raise Bad_tl_ast if tl_struct represents a corrupted ocaml code*)
and tl_struct_to_core np tl_struct=
    let meta = new tags in
    match tl_struct with
    |Tl_none -> []    
    |Tl_open(modules, body) ->( 
        meta#add_tag "plg_ast" [TStr "Tl_open"];
        [Node({
            name = List.fold_left (fun x y->x^"."^y) "" modules;
            header="";
            body=ptr np body;
            children=[];
            meta=meta})]
    )                               
    |Tl_var(name, body) ->(
        meta#add_tag "plg_ast" [TStr "Tl_var"];
        [Node({
            name =name;
            header="";
            body=ptr np body;
            children=[];
            meta=meta})]
    )                          
    |Tl_constraint(name, body) ->(
        meta#add_tag "plg_ast" [TStr "Tl_constraint"];    
        [Node({
            name = name;
            header="";
            body=ptr np body;
            children=[];
            meta=meta})]
    )      
    |Tl_fun(name, body) ->(
        meta#add_tag "plg_ast" [TStr "Tl_fun"];
        [Node({
            name =name;
            header="";
            body=ptr np body;
            children=[];
            meta=meta})]
    )      
    |Tl_exception(name, body) ->(
        meta#add_tag "plg_ast" [TStr "Tl_exception"];
        [Node({
            name = name;
            header="";
            body=ptr np body;
            children=[];
            meta=meta})]
    )      
    |Tl_type(names, body) ->(
        meta#add_tag "plg_ast" [TStr "Tl_type"];
        let meta_leaf = new tags in 
        meta_leaf#add_tag "plg_ast" [TStr "Tl_type_leaf"];
        [Node({
            name="";
            header="";
            body=ptr np body;
            children=List.map (function name-> Node({
                name =name;
                header="";
                body=ptr np body;
                children=[];
                meta=meta_leaf})) names;
            meta=meta})]  
    )       
    |Tl_module(name, ast) ->(
        meta#add_tag "plg_ast" [TStr "Tl_module"];
        [Node({
            name = name;
            header = "";
            body = ref "";
            children = _tl_ast_to_c_ast (np^"."^name) ast;
            meta=meta})]    
    )      
    |Tl_sign(name, ast) ->(
        meta#add_tag "plg_ast" [TStr "Tl_sign"];
        [Node({
            name = name;
            header = "";
            body = ref "";
            children = _tl_ast_to_c_ast (np^"."^name) ast;
            meta=meta})]  
    )      
    |Tl_module_constraint(name, m, m_t) ->(
        let fct value = List.iter( function
            |Nil->()
            |Node {meta=meta;_}->meta#add_tag "plg_desc" [TStr value]) in

        meta#add_tag "plg_ast" [TStr "Tl_module_constraint"];
        let m_t_children = (tl_struct_to_core np m_t) 
        and m_children = (tl_struct_to_core np m)in
        fct "module_type_item" m_t_children; 
        fct "module_item" m_children;
          
        [Node({
            name = name;
            header = "";
            body = ref "";
            children = m_t_children @ m_children; 
            meta=meta})]
    )      
    |Tl_functor(name, header, ast) ->(
        meta#add_tag "plg_ast" [TStr "Tl_functor"];
        [Node({
            name = name;
            header = header;
            body = ref "";
            children = _tl_ast_to_c_ast (np^"."^name) ast;
            meta=meta})]
    )      
    |Tl_recmodule(modules, body) ->(
        meta#add_tag "plg_ast" [TStr "Tl_recmodule"];
        [Node({
            name = "";
            header = "";
            body = ptr np body;
            children = _tl_ast_to_c_ast np modules;
            meta=meta})]
    )      
    |Tl_class cl->( 
        let fct value = List.iter( function
            |Nil->()
            |Node {meta=meta;_}->meta#add_tag "plg_desc" [TStr value]) in

        let fct1 items = List.concat( List.map (function x-> 
                                  cl_elmt_to_core (np^"#"^cl.name) x) items) in  
          
        meta#add_tag "plg_ast" [TStr "Tl_class"];
        meta#add_tag "plg_virt" [TStr (if cl.virt then "true" else "false")];
        meta#add_tag "plg_self" [TStr ((match cl.self with |None->""|Some(s)->s))];

        let c_t, c = fct1 cl.c_elmts, fct1 cl.elmts in
        fct "class_type_item" c_t;
        fct "class_item" c;

        [Node({
            name = cl.name;
            header = cl.header;
            body = ref "";
            children = (c_t @ c);
            meta=meta})]
    )                  
    |Tl_class_and(cls, body) ->(
        meta#add_tag "plg_ast" [TStr "Tl_class_and"];
        [Node({
            name = "";
            header = "";
            body = ptr np body;
            children = _tl_ast_to_c_ast np cls;
            meta=meta})]
    ) 
(** Transform a Tl_ast.tl_ast to Core.Misc.c_ast node
    @param np - namespace of the file
    @param tl_ast - Tl_ast.tl_ast
    @return a list of Core.misc.c_ast
    @raise Bad_tl_ast if tl_ast represents a corrupted ocaml code*)
and _tl_ast_to_c_ast np = function tl_ast -> 
    List.concat (List.map (tl_struct_to_core np) tl_ast)

(** Transform a Tl_ast.tl_ast to Core.Misc.c_ast node,
    external version of _tl_ast_to_c_ast
    @param tl_ast - Tl_ast.tl_ast
    @return a list of Core.misc.c_ast
    @raise Bad_tl_ast if tl_ast represents a corrupted ocaml code*)     
let tl_ast_to_c_ast = _tl_ast_to_c_ast ""

(* *** BEGIN *)

(** Transform a Core.misc.c_ast representing a ocaml type 
    @param - Core.Misc.internal_node
    @return string representing the type
    @raise Not_define if internal_node represents 
    a corrupted ocaml code*)
let c_type_to_tl_type =function
|Nil->not_define "Bad core node for type_leaf"
|Node node->(    
    match node.meta#get_value "plg_ast" with
    |Some [TStr "Tl_type_leaf"]->node.name
    |_->not_define "Bad core node for type_leafoo"
 )

(** Split a list of c_node into sublist, according to the "plg_desc" tag
    Usefull for spliting type definition from implementation,
    in a Tl_module_constraint for instance.
    @param prefix - a string used to separate nodes
    @return two sublists (type nodes, implem nodes)
    @raise Not_define if internal_node represents 
    a corrupted ocaml code*)
let rec split_c_constraint prefix=function
|[]-> [], []   
|Nil::_-> not_define "not def"
|(Node child)::children->(
    let (t_items:c_node list), items = split_c_constraint prefix children in   
    let t_label, label = prefix^"_type_item", prefix^"_item" in 
      
    match child.meta#get_value "plg_desc" with
    |Some [TStr l] when l=t_label-> (Node child)::t_items, items
    |Some [TStr l] when l=label->t_items, (Node child)::items
    |_->not_define "not def"
)

(** Transform a Core.Misc.internal_node to Tl_ast.class_elmt
    @param - Core.Misc.internal_node
    @return Tl_ast.class_elmt
    @raise Not_define if internal_node represents 
    a corrupted ocaml code*)
let rec c_ast_to_cl_elmt=function
|Nil ->not_define "bas ast c_ast_to_cl_elmt" 
|Node node->(  
    match node.meta#get_value "plg_ast" with
    |Some [TStr "Cl_attribut"]->(
        match node.meta#get_value "plg_desc" with
        |Some [TStr "class_item"]->
            Cl_attribut(Tl_var(node.name, !(node.body)))
        |Some [TStr "class_type_item"]->
            Cl_attribut(Tl_constraint(node.name, !(node.body))) 
        |_->bad_cnode "c_ast_to_cl_elmt Cl_attribut"    
    )      
    |Some [TStr "Cl_method"]->(
        let f_visibility = match node.header with 
            |"public"->Tl_public
            |"private"->Tl_private
            |_->not_define "c_ast_to_cl_elmt Cl_method f_visibility"
        in               

        match node.meta#get_value "plg_desc" with
        |Some [TStr "class_item"]->
            Cl_method(Tl_fun(node.name, !(node.body)), f_visibility)  
        |Some [TStr "class_type_item"]->
            Cl_method(Tl_constraint(node.name, !(node.body)), f_visibility) 
        |_->bad_cnode "c_ast_to_cl_elmt Cl_method"                             
    )                                
    |Some [TStr "Cl_init"]->Cl_init(!(node.body))
    |Some [TStr "Cl_inherit"]->Cl_inherit(node.name, match node.header with
        |""->None
        |s->Some s)
    |_->bad_cnode "c_ast_to_cl_elmt"                             
)

(** Transform a Core.Misc.internal_node to Tl_ast.Tl_struct
    @param - Core.Misc.internal_node
    @return Tl_ast.Tl_struct
    @raise Not_define if internal_node represents 
    a corrupted ocaml code*)
and c_node_to_tl_ast=function
|Nil -> Tl_none
|Node node->(          
    match node.meta#get_value "plg_ast" with
    |None -> not_define "bad core tree"
    |Some [TStr "Tl_open"]->
        Tl_open(String.split_on_char '.' node.name, !(node.body))
    |Some [TStr "Tl_var"]->
        Tl_var(node.name, !(node.body))
    |Some [TStr "Tl_constraint"]->
        Tl_constraint(node.name, !(node.body))
    |Some [TStr "Tl_fun"]->
        Tl_fun(node.name, !(node.body))
    |Some [TStr "Tl_exception"]->
        Tl_exception(node.name, !(node.body))      
    |Some [TStr "Tl_type"]->
        Tl_type( List.map c_type_to_tl_type node.children, !(node.body))
    |Some [TStr "Tl_module"]->
        Tl_module(node.name, c_ast_to_tl_ast node.children)
    |Some [TStr "Tl_sign"]->
        Tl_sign(node.name, c_ast_to_tl_ast node.children)           
    |Some [TStr "Tl_module_constraint"]->(
        let m_t, m = match split_c_constraint "module" node.children with 
            |m_t::[], m::[]->m_t, m
            |_->not_define "kfsdh"
        in
        Tl_module_constraint(node.name, c_node_to_tl_ast m, c_node_to_tl_ast m_t)  
    )
    |Some [TStr "Tl_functor"]->
        Tl_functor(node.name, node.header, c_ast_to_tl_ast node.children)
    |Some [TStr "Tl_recmodule"]->
        Tl_recmodule(c_ast_to_tl_ast node.children, !(node.body))
    |Some [TStr "Tl_class"]->( 
        let f_virt = match (node.meta)#get_value "plg_virt" with
        |Some [TStr "true"]->true
        |Some [TStr "false"]->false
        |_->not_define "not def" in
        
        let self_v = match (node.meta)#get_value "plg_self" with
        |Some([TStr ""])->None
        |Some([TStr s])->Some s             
        |_->not_define "cnc" in

        let c_t, c = split_c_constraint "class" node.children in

        Tl_class({
            name=node.name;
            header=node.header;
            virt=f_virt;
            self=self_v;
            elmts=List.map c_ast_to_cl_elmt c;
            c_elmts=List.map c_ast_to_cl_elmt c_t;  
        })
    )
    |Some [TStr "Tl_class_and"]->
        Tl_class_and(c_ast_to_tl_ast node.children, !(node.body))
    |_->not_define "not yet"                                      
)

(** Transform a Core.Misc.c_ast into a Tl_ast.tl_ast
    @param x - Core.Misc.c_ast(a list of nodes)
    @return a Tl_ast.tl_ast
    @raise Not_define if c_ast  represents 
    a corrupted ocaml code*)
and c_ast_to_tl_ast x= List.map c_node_to_tl_ast x

open OUnit2
let unittests () = 
    let bodies = [
        ("tree", "type 'a tree=Nil|Node of 'a tree*'a tree*'a and \
        'a forest='a tree list");

        ("helloc_c", "class hello = object(self) \
            val hello:string=\"hello\" \
            val alpha = 12 \
            val arf = ref true \
            method set (key:string) = 12 \
            initializer(arf:=false) \
        end");

        ("even_m", "module Even = struct \
            type t = Zero | Succ of int \
            let alpha = Zero \
            let hello () = print_endline \"Even\" \
        end");

        ("even_m_t", "module type Even = sig \
            type t = Zero | Succ of int \
            val alpha : t \
        end");

        ("even_m_c", "module Even : sig \
            type t = Zero | Succ of int \
            val alpha : t \
        end = struct \
            type t = Zero | Succ of int \
            let alpha = Zero \
            let hello () = print_endline \"Even\" \
        end");

        ("even_odd", "module rec Even : sig \
            type t = Zero | Succ of Odd.t \
        end = struct \
            type t = Zero | Succ of Odd.t \
        end \
        and Odd : sig \
            type t = Succ of Even.t \
        end = struct \
            type t = Succ of Even.t \
        end");

        ("comparable", "module type Comparable = sig \
            type t \
            val compare : t -> t -> int \
        end");

        ("OrderList", "module OrderList (T:Comparable) = struct \
            exception Empty \
            type content = T.t \
            type t = content list ref \
            let comp = T.compare \
        end");

        ("ptr_ast", "class ptr_ast x: object \
            val p_ast : c_ast ref \
            method ast : c_ast \
        end = object \
            val p_ast = ref Nil \
            method ast = Nil \
        end");

        ("top-level constraint", "val troll : int -> int");
    ] in
    "Tl_to_c" >:::[
        "Import-Export">:::( List.map (function name,body->(
            let tl_ast = Ml_to_tl.str_to_tl_ast body in
            name>::function _-> assert_equal tl_ast (c_ast_to_tl_ast 
                (tl_ast_to_c_ast tl_ast))
        )) bodies)]
                        
