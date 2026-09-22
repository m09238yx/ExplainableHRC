whynot(F):-
    repeat,
    nb_getval(fileOutput,Out),
    write(Out,'Please state your reason:\n'),write('Please state your reason:\n'),
    write_reason,
    write('User: '),
    prompt(_, ''),
    read(Number),
    (   Number  =:= 1
    ->  write(Out,'Because it is an user initial fact.'),
        ( 
            user_fact(_,F,initial_fact,_),
            \+ node(_N, F,_, _)
            -> (    write('User: Because '),write(Out,'User: Because '), print_fact(F),write(' is an initial fact.'),write(Out,' is an initial fact.'),nl, 
                    aggregate_all(count, y_computer_user(_,_), X),
                    aggregate_all(count, n_user_computer(_,_), Y),
                    X1 is X +1,
                    Y1 is Y+1,
                    assert(y_computer_user(X1,F)),!,
                    assert(n_user_computer(Y1,F)),!,
                    write('Construction Robot Advisor: I have found the disagreement. User believes '), 
                    write(Out, '\n----------DISAGREEMENT----------\n'),
                    write(Out, 'Construction Robot Advisor: I have found the disagreement. User believes '),print_fact(F),
                    write(Out, ' is an initial fact,but the computer neither believes nor infers it.'), write(' is an initial fact,but the computer neither believes nor infers it.\n'),nl,
                    assert(different(F)),!
            )
        ; (
            \+user_fact(_,F,initial_fact,_)
            ->write('\nConstruction Robot Advisor: It is not an initial user fact, please select another reason.'),whynot(F),
            write(Out,'\nConstruction Robot Advisor: It is not a user initial fact, please select another reason.'),nl,fail
            )
        )
    ;    Number =:= 2
    ->  write(Out, 'Because it is a new fact deduced by a rule.'), reason_rule(F,_), nl, !
    ;    Number =:= 3
    -> write(Out,'Construction Robot Advisor:Bye\n'),write('Construction Robot Advisor: Bye\n')->halt
    ;
        write('Not a valid choice, try again...'), nl, fail
    ).
    

reason_rule(Fact,F):-
    repeat,
    nb_getval(fileOutput,Out),
    write('User: Please select a rule number: '),nl,
    write(Out,'User: Please select a rule number: '),
    write_user_rule,
    aggregate_all(count, user_rule(_,_,_), Count),
    Restart is Count+1,
    write(Restart),write('. Restart to choose another reason\n'),
    E is Restart+1,
    write(E),write('. Exit\n'),
    write('User: '),
    prompt(_, ''),
    read(N),nl,     
    (  N=:=E
    ->  write(Out,'\nConstruction Robot Advisor:Bye\n'),
        exampleClose,write('Construction Robot Advisor:Bye\n')->halt
    ;  N=:=Restart
    ->  write(Out,'1. Restart to choose a reason\n'),write(Out,'\nConstruction Robot Advisor: Why do you believe '),write('\nConstruction Robot Advisor: Why do you believe '), print_fact(Fact), write('? '),write(Out, '?'),
        whynot(Fact)
    ;   
        (   
            user_rule(N, A, F),
            check(A, _),
            %write(A),write(F)
            deduce_user(F,_)
            %user_fact(_,F,_,_)
        -> 
            (
                rule(_,A,F)
            ->  
                write(Out,'User:'),
                assert(yr_computer_user(N,A,F)),!,
                write_w_list,
                write_x_list,
                aggregate_all(count, computer_ask_user(_,_), Num),
                (   Num==0
                ->  write('Construction Robot Advisor: This rule is used in deduction. Both computer and user are agree with this rule, please select another rule to find disagreement.\n'),
                     write(Out,'Construction Robot Advisor: This rule is used in deduction. Both computer and user are agree with this rule, please select another rule to find disagreement.\n'),
                     reason_rule(F,_)
                ;   computer_ask_user(Num,_F),
                    choose(Num)
                )
             ;   
                write('Construction Robot Advisor: I found the disagreement! I do not have this rule'),
                write(Out, '\n----------DISAGREEMENT----------\n'),
                write(Out, 'Construction Robot Advisor: I found the disagreement! I do not have this rule '),print_rule(N),write(Out, ', but the user has it.'),write(', but the user has it.'), nl,
                assert(different(user_rule(N,_,_))),!,conversations(false,_)
            )

        ;   write('Construction Robot Advisor: This rule is not used in deduction of this fact.'),
            write(Out,'Construction Robot Advisor: This rule is not used in deduction of this fact.'),
            button(Fact)
        )
    ;   
        write('Not a valid choice, try again...'), nl, fail).



button(F):-
    repeat,
    nb_getval(fileOutput,Out),
    write(Out,'Please choose another rule or reason\n'),
    write('Please choose another rule or reason\n'),
    write('1. Restart to choose a reason\n'),
    write('2. Choose another rule\n'),
    write('3. Exit\n'),
    write('User:'),
    prompt(_, ''),
    read(N),
    (   N=:= 1
    -> write(Out,'1. Restart to choose a reason\n'),write(Out,'\nConstruction Robot Advisor: Why do you believe '),write('\nConstruction Robot Advisor: Why do you believe '), print_fact(F), write('? '),write(Out, '?'),
        whynot(F)
    ;   N=:= 2
    -> write(Out,'2. Choose another rule\n'),reason_rule(F,_)
    ;   N=:= 3
    -> write(Out,'\nConstruction Robot Advisor:Bye\n'),
      exampleClose,write('Construction Robot Advisor:Bye\n')->halt
    ;   
        write('Not a valid choice, try again...'), nl, fail
      ).


option_whynot:-
    write_w_list,
    write_x_list,
    aggregate_all(count, computer_ask_user(_,_), N),
    computer_ask_user(N,_F),
    choose(N).

choose(0):-
    nb_getval(fileOutput,Out),
    write('----------FINISHED----------\n'),
    write(Out, '----------FINISHED----------\n'),
    write(Out,'Construction Robot Advisor: Bye\n'),
    write('Construction Robot Advisor: Bye\n'), !,halt .
choose(N):-
    nb_getval(fileOutput,Out),
    computer_ask_user(N,F),
    assert(asked_question(F)),
    Num is N-1,
    ( n_computer_user(F)
     ->  
        write(Out,'Construction Robot Advisor: Why do you not believe '),write('Construction Robot Advisor: Why do you not believe '),print_fact(F), write('?\n'),write(Out,'?\n'),
        write(Out,'User: Why do you believe '),write('User: Why do you believe '), print_fact(F),write('? '),write(Out,'?\n'),
        whynot(F),choose(Num)
    ;   write(Out,'Construction Robot Advisor: Why do you believe '),write('Construction Robot Advisor: Why do you believe '),print_fact(F), write('? '),write(Out,'?\n'),
        whynot(F),choose(Num)
    ),
    choose(Num).

check([],[]).
check([not(H)|T], N):-
    \+ deduce_user(H, _DAG),!, 
    assert(n_computer_user(H)),
    check(T, N).
check([H|T], [H|N]):-
    \+ deduce_user(H, _DAG),!, 
    check(T, N).
check([H|T], N):-
    deduce_user(H,_DAG),
    %write(H),
    (   \+y_computer_user(_,H)
    ->
        aggregate_all(count, y_computer_user(_,_), Count4),
        Num is Count4 +1,
        assert(y_computer_user(Num,H))
    ;
    check(T,N)
    ).


pretty_list([],"").
pretty_list([Head|Tail],Out):-
    print_top(Head,_HeadPretty),
    pretty_list(Tail,Out).

print_top(Fact,_Pretty):-
    user_fact(_,Fact,Rule,_)
    ->assert(d_rule(Fact,Rule)).

%% LOUISE: Computer adds all positive literals in A to Y_computer_user
    %% LOUISE: Computer adds all negative literals in a to N_computer user
    %% LOUISE: Computer then selects a fact that is in Y_computer_user and is not a node and asks
    %% why the user believes that fact.
    %% OR the computer picks a fact that is in N_computer_user and is a node and asks why the user
    %% does not believe that fact.