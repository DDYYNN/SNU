(*
 * SNU 4190.310 Programming Languages (Fall 2012)
 *
 * Low Fat M: static type checking + interpreter without dynamic type checking
 *)

open M
module M_SimChecker : M_SimTypeChecker = struct
(* Environment Implementation *)
    type type_var = TypeVar of string
    | TypeInt                     (* integer type *)
    | TypeBool                    (* boolean type *)
    | TypeString                  (* string type *)
    | TypePair of type_var * type_var   (* pair type *)
    | TypeLoc of type_var           (* location type *)
    | TypeArrow of type_var * type_var  (* function type *)

    type type_equations =
    | TypeEquation of type_var *type_var
    | TypeAnd of type_equations * type_equations

    module Env =
    struct
        type t = E of (id -> type_var)
        let empty = E(fun x -> raise (RuntimeError "not bound"))
        let lookup (E(env)) id = env id
        let bind (E(env)) id type_var = E(fun x -> if x = id then type_var else env x)
    end;;

    let eqTypeVarList = ref []
    let writeTypeVarList = ref []

    let counter =
    let count = ref (-1) in
      fun () -> incr count; "_" ^ string_of_int(!count)

    let rec change_type_var_to_types (var:type_var) : types =
        (match var with
        | TypeInt -> TyInt
        | TypeBool -> TyBool
        | TypeString -> TyString
        | TypeArrow (type_var1, type_var2) -> TyArrow ((change_type_var_to_types type_var1), (change_type_var_to_types type_var2))
        | TypePair (type_var1, type_var2) -> TyPair((change_type_var_to_types type_var1), (change_type_var_to_types type_var2))
        | TypeLoc type_var -> TyLoc (change_type_var_to_types type_var)
        | TypeVar x -> raise (TypeError "change_type_var_to_types TypeVar"))

    let rec generate_type_equations (env : Env.t) (exp : M.exp) (var : type_var) : type_equations =
        match exp with
        |CONST const ->
            (match const with
            | S str -> TypeEquation ((TypeString), var)
            | N num -> TypeEquation ((TypeInt), var)
            | B b -> TypeEquation ((TypeBool), var))
        | VAR id ->
            let new_type_var = (Env.lookup env id) in
            (TypeEquation (new_type_var, var))
        | FN (id, exp) ->
            let new_type_var1 = (TypeVar (counter())) in
            let new_type_var2 = (TypeVar (counter())) in
            let new_type_equation = (TypeEquation (var, (TypeArrow (new_type_var1, new_type_var2)))) in
            let new_env = (Env.bind env id new_type_var1) in
            TypeAnd (new_type_equation, (generate_type_equations new_env exp new_type_var2))
        | APP (exp1, exp2) ->
            let new_type_var1 = (TypeVar (counter())) in
            let type_equations_1 = (generate_type_equations env exp1 (TypeArrow (new_type_var1, var))) in
            let type_equations_2 = (generate_type_equations env exp2 new_type_var1) in
            TypeAnd (type_equations_1, type_equations_2)
        | LET (decl, exp2) ->
            (match decl with
                | NREC (id, exp1) ->
                    let new_type_var1 = (TypeVar (counter())) in
                    let type_equations_1 = (generate_type_equations env exp1 new_type_var1) in
                    let new_env = (Env.bind env id new_type_var1) in
                    let type_equations_2 = (generate_type_equations new_env exp2 var) in
                    TypeAnd (type_equations_1, type_equations_2)
                | REC (id, exp1) ->
                    let new_type_var1 = (TypeVar (counter())) in
                    let new_env = (Env.bind env id new_type_var1) in
                    let type_equations_1 = (generate_type_equations new_env exp1 new_type_var1) in
                    let type_equations_2 = (generate_type_equations new_env exp2 var) in
                    TypeAnd (type_equations_1, type_equations_2))
        | IF (exp1, exp2, exp3) ->
            let type_equations_1 = (generate_type_equations env exp1 TypeBool) in
            let type_equations_2 = (generate_type_equations env exp2 var) in
            let type_equations_3 = (generate_type_equations env exp3 var) in
            TypeAnd(type_equations_1, TypeAnd(type_equations_2, type_equations_3))
        | BOP (bop, exp1, exp2) ->
            (match bop with
            | ADD ->
                let type_equations_1 = TypeEquation (TypeInt, var) in
                let type_equations_2 = (generate_type_equations env exp1 TypeInt) in
                let type_equations_3 = (generate_type_equations env exp2 TypeInt) in
                TypeAnd (type_equations_1, TypeAnd(type_equations_2, type_equations_3))
            | SUB ->
                let type_equations_1 = TypeEquation (TypeInt, var) in
                let type_equations_2 = (generate_type_equations env exp1 TypeInt) in
                let type_equations_3 = (generate_type_equations env exp2 TypeInt) in
                TypeAnd (type_equations_1, TypeAnd(type_equations_2, type_equations_3))
            | AND ->
                let type_equations_1 = TypeEquation (TypeBool, var) in
                let type_equations_2 = (generate_type_equations env exp1 TypeBool) in
                let type_equations_3 = (generate_type_equations env exp2 TypeBool) in
                TypeAnd (type_equations_1, TypeAnd(type_equations_2, type_equations_3))
            | OR ->
                let type_equations_1 = TypeEquation (TypeBool, var) in
                let type_equations_2 = (generate_type_equations env exp1 TypeBool) in
                let type_equations_3 = (generate_type_equations env exp2 TypeBool) in
                TypeAnd (type_equations_1, TypeAnd(type_equations_2, type_equations_3))
            | EQ ->
                let type_equations_1 = TypeEquation (TypeBool, var) in
                let new_type_var1 = (TypeVar (counter())) in
                let type_equations_2 = (generate_type_equations env exp1 new_type_var1) in
                let type_equations_3 = (generate_type_equations env exp2 new_type_var1) in
                eqTypeVarList := (new_type_var1::(!eqTypeVarList));
                TypeAnd (type_equations_1, TypeAnd(type_equations_2, type_equations_3)))
        | READ ->
                TypeEquation (TypeInt, var)
        | WRITE exp ->
            writeTypeVarList := (var::(!writeTypeVarList));
            (generate_type_equations env exp var)
        | MALLOC exp ->
            let new_type_var1 = (TypeVar (counter())) in
            let type_equations_1 = (TypeEquation (var, (TypeLoc new_type_var1))) in
            let type_equations_2 = (generate_type_equations env exp new_type_var1) in
            TypeAnd (type_equations_1, type_equations_2)
        | ASSIGN (exp1, exp2) ->
            let type_equations_1 = (generate_type_equations env exp1 (TypeLoc var)) in
            let type_equations_2 = (generate_type_equations env exp2 var) in
            TypeAnd (type_equations_1, type_equations_2)
        | BANG exp ->
            (generate_type_equations env exp (TypeLoc var))
        | SEQ (exp1, exp2) ->       (*   e ; e    *)
            let new_type_var1 = (TypeVar (counter())) in
            let type_equations_1 = (generate_type_equations env exp1 new_type_var1) in
            let type_equations_2 = (generate_type_equations env exp2 var) in
            TypeAnd (type_equations_1, type_equations_2)
        | PAIR (exp1, exp2) ->      (*   (e, e)   *)
            let new_type_var1 = (TypeVar (counter())) in
            let new_type_var2 = (TypeVar (counter())) in
            let type_equations_1 = (TypeEquation (var, (TypePair (new_type_var1, new_type_var2)))) in
            let type_equations_2 = (generate_type_equations env exp1 new_type_var1) in
            let type_equations_3 = (generate_type_equations env exp2 new_type_var2) in
            TypeAnd (type_equations_1, TypeAnd(type_equations_2, type_equations_3))
        | SEL1 exp ->            (*   e.1      *)
            let new_type_var1 = (TypeVar (counter())) in
            let new_type_var2 = (TypeVar (counter())) in
            let type_equations_1 = (TypeEquation (var, new_type_var1)) in
            let type_equations_2 = (generate_type_equations env exp (TypePair (new_type_var1, new_type_var2))) in
            TypeAnd (type_equations_1, type_equations_2)
        | SEL2 exp ->           (*   e.2      *)
            let new_type_var1 = (TypeVar (counter())) in
            let new_type_var2 = (TypeVar (counter())) in
            let type_equations_1 = (TypeEquation (var, new_type_var2)) in
            let type_equations_2 = (generate_type_equations env exp (TypePair (new_type_var1, new_type_var2))) in
            TypeAnd (type_equations_1, type_equations_2)

    type substitution = Arrow of type_var * type_var
    type substitutions = substitution list

    let rec applySubToTypeVar (substitution:substitution) (var:type_var) : type_var =
        let Arrow (from_type_var, to_type_var) = substitution in
        match var with
        | TypeVar x ->
            (match from_type_var with
            | TypeVar y ->
                if x = y
                    then
                        to_type_var
                    else
                        var
            | _ -> var)
        | TypeInt -> TypeInt
        | TypeBool -> TypeBool
        | TypeString -> TypeString
        | TypePair (type_var1, type_var2) ->
            let new_type_var1 = (applySubToTypeVar substitution type_var1) in
            let new_type_var2 = (applySubToTypeVar substitution type_var2) in
            TypePair (new_type_var1, new_type_var2)
        | TypeLoc type_var ->
            let new_type_var = (applySubToTypeVar substitution type_var) in
            (TypeLoc new_type_var)
        | TypeArrow (type_var1, type_var2) ->
            let new_type_var1 = (applySubToTypeVar substitution type_var1) in
            let new_type_var2 = (applySubToTypeVar substitution type_var2) in
            TypeArrow (new_type_var1, new_type_var2)

    let rec applySubsToTypeVar (substitutions:substitutions) (var:type_var) : type_var =
        (List.fold_left (fun var substitution -> (applySubToTypeVar substitution var)) var substitutions)

    let rec applySubsToTypeEquations (substitutions:substitutions) (equations:type_equations) : type_equations =
    match equations with
    | TypeEquation (type_var1, type_var2) ->
        let new_type_var1 = (applySubsToTypeVar substitutions type_var1) in
        let new_type_var2 = (applySubsToTypeVar substitutions type_var2) in
        TypeEquation (new_type_var1, new_type_var2)
    | TypeAnd (type_equations1, type_equations2) ->
        TypeAnd((applySubsToTypeEquations substitutions type_equations1), (applySubsToTypeEquations substitutions type_equations2))

    let rec unify (type_var1:type_var) (type_var2:type_var) : substitutions =
    (match (type_var1, type_var2) with
    | (TypeInt, TypeInt) -> []
    | (TypeBool, TypeBool) -> []
    | (TypeString, TypeString) -> []
    | ((TypeVar x), _) -> [Arrow (type_var1, type_var2)]
    | (_, (TypeVar x)) -> [Arrow (type_var2, type_var1)]
    | ((TypeLoc new_type_var1), (TypeLoc new_type_var2)) -> (unify new_type_var1 new_type_var2)
    | ((TypePair (type_var1, type_var2)), (TypePair (type_var3, type_var4))) ->
        let new_subs = (unify type_var1 type_var3) in
        let new_type_var2 = (applySubsToTypeVar new_subs type_var2) in
        let new_type_var4 = (applySubsToTypeVar new_subs type_var4) in
        let new_subs2 = (unify new_type_var2 new_type_var4) in
        (List.append new_subs new_subs2)
    | ((TypeArrow (type_var1, type_var2)), (TypeArrow (type_var3, type_var4))) ->
        let new_subs = (unify type_var1 type_var3) in
        let new_type_var2 = (applySubsToTypeVar new_subs type_var2) in
        let new_type_var4 = (applySubsToTypeVar new_subs type_var4) in
        let new_subs2 = (unify new_type_var2 new_type_var4) in
        (List.append new_subs new_subs2)
    | _ -> raise (TypeError "fail"))

    let rec unify_all (equations:type_equations) (substitutions:substitutions) =
        match equations with
        | TypeEquation (type_var1, type_var2) -> (List.append substitutions (unify type_var1 type_var2))
        | TypeAnd (type_equations1, type_equations2) ->
            let new_subs = (unify_all type_equations1 substitutions) in
            (unify_all (applySubsToTypeEquations new_subs type_equations2) new_subs)

    let unification (equations:type_equations) : substitutions =
        (unify_all equations [])

    let checkEqList (solution:substitutions) =
        List.filter
            (fun eqTypeVar ->
                (match (applySubsToTypeVar solution eqTypeVar) with
                | TypePair _ -> raise (TypeError "EqList fail : Pair")
                | TypeArrow(_,_) -> raise (TypeError "EqList fail : Arrow")
                | _ -> false))
            (!eqTypeVarList)

    let checkWriteList (solution:substitutions) =
        List.filter
            (fun writeTypeVar ->
                (match (applySubsToTypeVar solution writeTypeVar) with
                | TypePair _ -> raise (TypeError "writeList fail : Pair")
                | TypeArrow _ -> raise (TypeError "writeList fail : Arrow")
                | TypeLoc _ -> raise (TypeError "writeList fail : Loc")
                | _ -> false))
            (!writeTypeVarList)

    let rec check exp =
        let result_var = (TypeVar "__result") in
        let equations = (generate_type_equations Env.empty exp result_var) in
        let solution = (unification equations) in
        let result_type_var = (applySubsToTypeVar solution result_var) in
        (checkEqList solution);
        (checkWriteList solution);
        (change_type_var_to_types result_type_var)
end
