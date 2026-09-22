:-dynamic node/4.

deduce_backwards(Q, node(ID, Q, R , DAG)):-
   node(ID, Q, R , DAG).
deduce_backwards(Q, node(ID, Q, ID_r , NodeList)):-
   rule(ID_r, A, Q),
   \+ node(_ID, Q, _ID_r, _NodeList),
   check_antecedants(A, NodeList), !,
   countNumbers(Numbers),
   ID is Numbers +1,
   assert(node(ID,Q,ID_r,NodeList)).
 
countNumbers(Numbers) :-
  aggregate_all(count, node(_,_,_,_), Numbers).

 
check_antecedants([],[]).
check_antecedants([H|T], [node(ID, H, R, DAG)|NodeList]):-
    deduce_backwards(H, node(ID, H, R, DAG)),
    check_antecedants(T, NodeList).

check_antecedants([not(H)|T], [node(ID_n,not(H),unprovable,[])|NodeList]):-
    \+ deduce_backwards(H, _DAG), !,
    countNumbers(Numbers),
    ID_n is Numbers +1,
    assert(node(ID_n,not(H),unprovable,[])),
    check_antecedants(T, NodeList).



% the deduce processing using user rules 
deduce_user(Q, user_fact(ID, Q, R , DAG)):-
   user_fact(ID, Q, R , DAG).
deduce_user(Q, user_fact(ID, Q, ID_r , NodeList)):-
   user_rule(ID_r, A, Q),
   \+ user_fact(_ID, Q, _ID_r, _NodeList),
   check_as(A, NodeList), !,
   count(Num),
   ID is Num +1,
   assert(user_fact(ID,Q,ID_r,NodeList)).
 
count(Num) :-
  aggregate_all(count, user_fact(_,_,_,_), Num).

check_as([],[]).
check_as([H|T], [user_fact(ID, H, R, DAG)|NodeList]):-
    deduce_user(H, user_fact(ID, H, R, DAG)),
    check_as(T, NodeList).

check_as([not(H)|T], [user_fact(ID_n,not(H),unprovable,[])|NodeList]):-
    \+ deduce_user(H, _DAG), !,
    count(Num),
    ID_n is Num +1,
    assert(user_fact(ID_n,not(H),unprovable,[])),
    check_as(T, NodeList).