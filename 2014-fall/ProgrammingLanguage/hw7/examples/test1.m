let rec fact = fn x =>
    if (x = 1) 
        then 1
        else x + fact(x-1)
    in (fact 5)
end
