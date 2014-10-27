type treasure = StarBox | NameBox of string;;

type key = Bar
    | Node of key * key
;;

type map = End of treasure
    | Branch of map * map
    | Guide of string * map
;;

type operand = I
    | Fn of operand * operand
    | V of string
;;

type equation = Equation of operand * operand
;;

type solution = Map of operand * operand
;;

module Env =
struct
    type id =
        string
    type  env_entry =
        Value of operand | Null
	type env =
        E of (id -> env_entry)

	let empty = E(fun x -> Null)
	let lookup (E(env)) id = env id
	let bind (E(env)) id loc = E(fun x -> if x = id then loc else env x)
end;;

let counter =
  let count = ref (-1) in
    fun () -> incr count; string_of_int(!count)

exception IMPOSSIBLE
;;

let rec getEquations (env, map, operand) =
    match map with
    | (End StarBox) -> [Equation (operand, I)]
    | (End (NameBox name)) ->
        (match (Env.lookup env name) with
            | (Env.Null) -> [Equation (operand, (V name))]
            | (Env.Value operand1) -> [Equation (operand, operand1)])
    | (Branch (map1, map2)) ->
        let var1 = (V (counter())) in
        (List.append (getEquations (env, map1, Fn(var1, operand))) (getEquations (env, map2, var1)))
    | (Guide (name, map1)) ->
        let var1 = (V (counter())) in
        let var2 = (V (counter())) in
	        Equation(operand, (Fn (var1, var2)))::getEquations((Env.bind env name (Env.Value var1)), map1, var2)
;;

(*
(solution * operand) -> operand
*)
let rec applySolution (solution, operand) =
    match operand with
    | I -> I
    | (Fn (operand1, operand2)) -> Fn ((applySolution (solution, operand1)), (applySolution (solution, operand2)))
    | (V x) ->
    (match solution with
        | (Map (operand1, operand2)) -> if operand = operand1
            then operand2
            else operand)
;;

let rec applySolutionList (solutionList, operand) =
    let helper operand solution = applySolution(solution, operand) in
    (List.fold_left
        helper
        operand
        solutionList)
;;

(* solutionList * solutionList -> solutionList *)
let rec applySolutionListToSolutionList (solutionList1, solutionList2) =
	let rec applySolutionToSolutionList (solution, solutionList) =
	    solution::(List.map
	        (function (Map (operand1, operand2)) ->
	            Map (operand1, applySolution(solution, operand2)))
	        solutionList) in

    let helper result solution = (List.append (applySolutionToSolutionList(solution, solutionList2)) result) in
    (List.fold_left
        helper
        []
        solutionList1)
;;

let rec applySolutionListToEquationList (solutionList, equationList) =
	let rec applySolutionToEqautionList (solution, equationList) =
	    (List.map
	        (function (Equation (operand1, operand2)) ->
	            Equation (applySolution(solution, operand1), applySolution(solution, operand2)))
	        equationList) in

    let helper result solution = (List.append (applySolutionToEqautionList(solution, equationList)) result) in
    (List.fold_left
        helper
        []
        solutionList)
;;

(* operand * operand -> solutionList *)
let rec unify (operand1, operand2) =
    if (operand1 = operand2)
        then []
        else
            (match (operand1, operand2) with
            | (Fn (t1, t2), Fn (t3, t4)) ->
                let s1 = unify(t1, t3) in
                let s2 = unify(applySolutionList(s1, t2), applySolutionList(s1, t4)) in
                applySolutionListToSolutionList(s2, s1)
           | (V a, t) -> [Map ((V a), t)]
           | (t, V a) -> [(Map ((V a), t))]
           | _ -> raise IMPOSSIBLE)
(*
let rec unify (operand1, operand2, solutionList) =
    if (operand1 = operand2)
        then solutionList
        else
            (match (operand1, operand2) with
            | (Fn (t1, t2), Fn (t3, t4)) ->
                let s1 = unify(t1, t3, solutionList) in
                let s2 = unify(t2, t4, solutionList) in
                let newSolutionList = applySolutionToSolutionList((List.hd s1), solutionList) in
                applySolutionToSolutionList((List.hd s2), newSolutionList)
           | (V a, t) -> print_string a;applySolutionToSolutionList((Map ((V a), t)), solutionList)
           | (t, V a) -> print_string a;applySolutionToSolutionList((Map ((V a), t)), solutionList)
           | _ -> raise IMPOSSIBLE)
;;
*)

(* equationList * solutionList -> solutionList *)
let rec unifyAll(equationList, solutionList) =
    match equationList with
    | [] -> []
    | (Equation (operand1, operand2))::[] -> unify(operand1, operand2)
    | hd::tl ->  let newSolutionList = unifyAll([hd], solutionList) in
        unifyAll(applySolutionListToEquationList(newSolutionList, equationList), newSolutionList)
;;


let m1 = (Branch (End (NameBox "x"), End(NameBox "x")))
;;
let m2 = (Guide  ("x", End(NameBox "x")))
;;
let m3 = (Branch ((Guide  ("x", End(NameBox "x"))), End StarBox))
;;
let m4 = (Branch (End (NameBox "x"),
    (Branch (End (NameBox "y"),
        (Branch (End (NameBox "z"),
            End (StarBox)))))))
;;

let eq1 = getEquations (Env.empty, m1, (V "TAU"))
;;
let eq2 = getEquations (Env.empty, m2, (V "TAU"))
;;
let eq3 = getEquations (Env.empty, m3, (V "TAU"))
;;
let eq4 = getEquations (Env.empty, m4, (V "TAU"))
;;


let ans1 = unifyAll(eq1, [])
let ans2 = unifyAll(eq2, [])
let ans3 = unifyAll(eq3, [])
let ans4 = unifyAll(eq4, [])
(*
if (Env.lookup Env.empty "x") = Env.Null
    then print_int 10
    else print_int 0
        ;;
if (Env.lookup (Env.bind Env.empty "x" (Env.Value (V "x"))) "x") = Env.Value (V "x")
    then print_int 10
    else print_int 0

let _ = print_int( getTerms(0, (End StarBox), 0));;
let _ = print_int( getTerms(0, (End (NameBox "x")), 0));;
let _ = print_int( getTerms(0, (Branch ((End StarBox), (End StarBox))), 0));;
let _ = print_int( getTerms(0, (Guide ("x", (End StarBox))), 0));;

let ap1 = applySolutionToSolutionList ((Map ((V "X"), (V "Y"))), [Map ((V "A"), (V "X"))])
let ap1 = applySolution (Map ((V "X"), (V "Y"))) (V "X")
;;
let ap2 = applySolution (Map ((V "X"), (V "Y"))) I
;;
let ap3 = applySolution (Map ((V "X"), (V "Y"))) (Fn ((V "X"), (V "X")))
;;
*)
