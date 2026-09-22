
%% LOUISE:  both write_why_list and write_why_not_list feel a bit redundant to me.
%% The user has already said they want an explanation.
agree(1, "Yes, I agree. Exit.").
agree(2, "No, I disagree. I want an explanation.").

reason(1, "Because it's a user initial fact.").
reason(2, "Because it is a new fact deduced by a rule.").
reason(3, "Exit.").

write_user_fact:-
    write('\n----------YOUR FACTS ----------\n'),nl,
    user_fact(_N, Fact, initial_fact, []),
    print_fact(Fact),nl,
    fail.
write_user_fact.

write_user_rule:-
    write('\n----------YOUR RULES ----------\n'),nl,
    user_rule(N, _Antecedants, _C),
    print_rule(N),nl,
    fail.
write_user_rule.


print_fact(Fact):-
    fact_description(Fact).
print_rule(Rule):-
    rule_description(Rule).


yes_no:-
    agree(N, Name),
    write(N), write('. '), write(Name), nl,
    fail.
yes_no.

write_why_list:-
    %% LOUISE: What if the node was labelled unprovable?
    y_user_computer(N,F),
    \+ asked_question(F),
    N1 is N+1,
    write(N1),write(". Why do you believe "), print_fact(F), write("?"),nl,
    fail.
write_why_list.

write_whynot_list:-
    %% LOUISE: What if the node was labelled unprovable?
    n_user_computer(A,F),
    %write(F),
    deduce_user(F,_),
    \+ asked_question(F),
    aggregate_all(count, y_user_computer(_,_), Count),
    B is A+Count+1,
    write(B),write(". Why do not you believe "), print_fact(F), write("?"),nl,
    fail.
write_whynot_list.


write_w_list:-
    y_computer_user(_N,F),
    \+ deduce_backwards(F,_),
    \+ asked_question(F),
    aggregate_all(count, computer_ask_user(_,_), Num),
    N is Num+1,
    assert(computer_ask_user(N, F)),
    %write("Why do you believe "), print_fact(F), write("?"),nl,
    fail.
write_w_list.



write_x_list:-
    n_computer_user(F),
    deduce_backwards(F,_),
    \+ asked_question(F),
    aggregate_all(count, computer_ask_user(_,_), Num),
    N is Num +1,
    assert(computer_ask_user(N, F)),
    %write("Why don't you believe "), print_fact(F), write("?"),nl,
    fail.
write_x_list.



random_pick(Res, R):- 
        length(Res, Length),  
        Upper is Length + 1,
        random(1, Upper, Rand),
        nth_item(Res, Rand, R).

nth_item([H|_], 1, H).
nth_item([_|T], N, X):-
        nth_item(T, N1, X),
        N is N1 + 1.


write_reason:-
    reason(N, Name),
    write(N), write('. '), write(Name), nl,
    fail.
write_reason.


write_initial_list:-
    initial_question(N,_F,Pretty),
    write(N), write('. '), write(Pretty), nl,
    fail.
write_initial_list.
