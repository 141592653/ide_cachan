
type 'a tag_element = 
| TStr of string
| TRef of 'a
| TDepend of string list;;


type 'a tag =  'a tag_element list;;

class type set_read_only = 
object
  method to_string : string
  method name : string
end


class virtual toStringable = object
  method virtual to_string:string
end


class ['a] tags = object(self)
  inherit toStringable
  val tag_htbl: (string,'a tag) Hashtbl.t = Hashtbl.create 4
  method get_value str = 
    try 
      Some (Hashtbl.find tag_htbl str)
    with 
    |Not_found -> None

  method add_tag name values = 
    Hashtbl.replace tag_htbl name values 


  (*[Alice] Why this name ???*)
  method private tag_to_list values =  
    List.fold_left (fun prec -> function
    | TStr(x) -> prec ^ ", " ^ "S : " ^ x
    | TRef(_) -> prec ^ ", " ^ "Refx " 
    | TDepend _ -> "" (*[Alice] TODO*)
    ) "" values
    


  method to_string = 
    let s = ref "" in 
    Hashtbl.iter (fun _ values -> s := !s^(self#tag_to_list values)) tag_htbl;
    !s

end




and ['a] metaData = object
  inherit ['a] tags
end




and ['a] cSet (name_tmp:string) (*: ['a] set_read_only*)= object(self)
  inherit toStringable
  (*[Alice] I don't see the point of this line and the ide compiles 
    when I delete it. Are you sure you need this?*)
  (*inherit ['a] metaData*)

  val mutable children = []

  (**[Alice] tags used by the IDE*)
  method meta_data_sys : 'a metaData = new metaData

  (**[Alice] tags defined by the user*)
  method meta_data_usr : 'a metaData = new metaData
    
  method add_child (child: 'a) = children <- child::children

  method name = name_tmp
  
  (*[Alice] You never use the to_string method of tags. Is this normal?*)
  method to_string = match children with
  | [] -> "E(" ^ self#name ^ ")"
  | _ -> "S(" ^ self#name ^ ")"
end



type gset = gset cSet;;

let print = Printf.printf "%s\n";;


(*


exception No_child

type class_elt = Attr of string| Meth of string

class virtual class_element(name) = object
  inherit [gset] cSet(name)
  method virtual as_attr: attr option
  method virtual as_meth: meth option 
  val mutable name_class = ""
  method virtual type_class_elt : class_elt
  method name_class = name_class
  method change_name_class name_c = 
    name_class <-name_c;
end

and attr(name) = object(self)
  inherit class_element(name)
  method add_child _ = raise No_child
  method as_attr = Some (self:>attr)
  method as_meth = None
  method type_class_elt = Attr name
  method to_string =  "Attr(" ^ self#name ^ ")"
end

and meth(name) = object(self)
  inherit class_element(name) 
  method add_child _ = raise No_child
  method as_attr = None
  method as_meth = Some (self:>meth)
  method type_class_elt = Meth name
  method to_string = "Meth(" ^ self#name ^ ")"
end


class ['a] classe(name) = object(self)
  inherit [class_element] cSet(name)
  val mutable name_class = name
  method to_string = match children with
  | [] -> "C(" ^ self#name ^ ")"
  | a::b -> "C:" ^ self#name ^ "(" ^ a#to_string ^ ((List.fold_left (fun a b -> a ^ "," ^ b#to_string) "" b)) ^ ")" 
  method add_child (child: 'a) =
    child#change_name_class(name);
    children <- child::children
end



let get =function
  |Meth a|Attr a-> "Attr :"^a


(*il faut cast pour obtenir class1 :> gset*)


let () =
  let elt1 = new cSet("poussin") in
  let cSet1 = new cSet("poule") in
  let elt2 = new cSet("oeuf") in
  let cSet2 = new cSet("ferme") in
  let attr1 = new attr("foin") in
  let class1 = new classe("campagne") in
  cSet1#add_child elt1;
  cSet1#add_child elt2;
  cSet2#add_child cSet1;
  class1#add_child attr1;
  print cSet2#to_string;
  ignore ((class1:> cSet_read_only):>gset);
  Printf.printf "%s" (get (attr1#type_class_elt))
;;
*)
