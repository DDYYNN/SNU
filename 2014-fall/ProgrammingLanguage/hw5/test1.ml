[Header]
open K
open Unix
open Translate
open Sm5

let test_run pgm_str = 
  let pgm = Parser.program Lexer.start (Lexing.from_string pgm_str) in
  let sm5_pgm = Translator.trans pgm in
  Sm5.run sm5_pgm

[Test]
(* 1. Arithmetic *)
let _ = test_run "let x :=0 in (read x; write (5 + 6 * x - 8 / 4))" 

[Input]
"7\n"

[Value]
"45\n"


[Test]
(* 2. Branches *)
let _ = test_run 

"let x := 0 in 
read x;
if (5 < x) then (
  if (false = false) then (
    if not(true = 3) then (write (21)) else (write (22))
  )
  else (write (23))
)
else (write (24))" 

[Input]
"6\n"

[Value]
"21\n"


[Test]
(* 3. Sequence *)
let _ = test_run 

"let x := 0 in
read x;
write(write(11); 12; x)" 

[Input]
"13\n"

[Value]
"11\n13\n"


[Test]
(* 4. Return value of write() *)
let _ = test_run 

"let x := 0 in
read x;
write((write((write(x)) + 5)) - 10)"

[Input]
"20\n"

[Value]
"20\n25\n15\n"

[Test]
(* 5. While + LetV *)
let _ = test_run 

"let x := 0 in
read x;
let i := 0 in
let sum := 0 in
while (i < x) do (
   sum := sum + i;
   i := i + 1
); 
write(sum)"

[Input]
"10\n"

[Value]
"45\n"


[Test]

(* 6. For loop corner case *)
let _ = test_run

"let x := 1 in
read x;
for i := 1 to x do ();
write 100"

[Input]
"-1\n"

[Value]
"100\n"

[Test]
(* 7. FOR loop *)
let _ = test_run 

"let x := 1 in
let  y := 1 in
let z := 0 in
let sum := 0 in
read z;
for x := 1 to z do (
  for y := 1 to x do (
    sum := sum + y
  )
);
write sum"

[Input]
"10\n"

[Value]
"220\n"

[Test]
(* 8.  LetF + CallV *)
let _ = test_run

"let proc f (x) = x * 7 in
let x := 0 in
read x;
(write (f (x)))"

[Input]
"7\n"

[Value]
"49\n"

[Test]
(* 9. Recursive call *)
let _ = test_run 

"let proc f (x) = 
  if (x < 1) then 1 else (x + f (x-1)) in
let x:= 0 in
read x;
(write (f (x)))"

[Input]
"10\n"

[Value]
"56\n"

[Test]
(* 10. LetF + CallV + CallR *)
let _ = test_run 
"let proc f (x) = (x := 3) in
let proc g (x) = (x := 3) in
let x := 1 in
let y := 2 in
f <x>; g (y); (write (x+y))"

[Input]
"1\n2\n"

[Value]
"5\n"

[Test]
(* 11. Read and write *)
let _ = test_run "let x := 0 in while (0 < (read x)) do (write x)" 

[Input]
"3\n2\n5\n0\n"

[Value]
"3\n2\n5\n"

[Test]
(* 12. Simple bonus *)
let _ = test_run "let x := 1 in if x = 1 then (write 3) else (write 4)" 

[Input]
""

[Value]
"3\n"

[Test]
(* 13. Assign, revisited *)
let _ = test_run 

"let x := () in
let y := () in
let z := () in
let w := 0 in
read w;
if ( (x := 1) + (y := 2) + (z := 3) = 6 ) then (write (w *10)) else (write 0)"

[Input]
"10\n"

[Value]
"100\n"

[Test]
(* 14. Scope *)
let _ = test_run 
"let x := 0 in
write(
  (let x := 1 in (x := 5); ((x := x + 1) * (let x := 2 in (x := x + 1)))) +
  (let y := 2 in 2 * x)
)"

[Input]
""

[Value]
"18\n"


[Test]
(* 15. Assignment in FOR loop *)
let _ = test_run 
"let x := 1 in
let sum := 0 in
let k := 0 in
read k;
for x := 1 to k do (
  x := 2 * x;
  sum := sum + x
); (write sum)"

[Input]
"10\n"

[Value]
"110\n"


[Test]
(* 16. Arguments in CallF *)
let _ = test_run 

"let y := 2 in
let z := 0 in
let proc f (x) = x + y + z in
read z;
write (f (1))"

[Input]
"3\n"

[Value]
"6\n"


[Test]
(* 17. Arguments in CallR *)
let _ = test_run 

"let x := 1 in
let y := 2 in
let z := 3 in
let proc f (x) = (x := x + (y := y + 1) + (z := z + 1)) in
f <x>; (write (x+y+z))"

[Input]
""

[Value]
"15\n"

[Test]
(* 18. Scope case II *)
let _ = test_run
"let a := 0 in
let proc f (x) = x + 1 in
let f := 2 in
read a;
write (a * ( f + f))"

[Input]
"10\n"

[Value]
"40\n"


[Test]
(* Scope case III *)
let _ = test_run 
"let x := 1 in
let y := 2 in
let z := 3 in
let proc f (x) = (x := x + y) in
let proc g (x) = (x := x + z) in
let y := 4 in
let z := 5 in
write (f ( g <y> ))"

[Input]
""

[Value]
"9\n"

[Test]
(* 20. Complex scope *)
let _ = test_run 

"let x := 1 in
let y := 5 in
let proc f (z) =
  if z then (x := x + 1) else (y := y - 2)
in
let x := 10 in
let y := 50 in
let proc g (z) =
  if z then (x := x + 5) else (y := y - 10)
in
write (
  g (true) + g (false) + x + y + f (true) + f (false) + x + y
)"

[Input]
""

[Value]
"170\n"
