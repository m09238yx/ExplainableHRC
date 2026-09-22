why(F):- 
    nb_getval(fileOutput,Out),
    node(_N, F, initial_fact, _NL), !,  
    (  
        \+ deduce_user(F,_),
        \+ user_fact(_,F,_,_)
    ->  write('\nConstruction Robot Advisor: Because computer has the fact: '), 
        write(Out,'\nConstruction Robot Advisor: Because computer has the fact: '), 
        print_fact(F),
        write(' is an initial fact.'),
        write(Out,' is an initial fact.'),
        write(Out, '\n----------DISAGREEMENT----------\n'),
        write(Out, 'Construction Robot Advisor: I have found the disagreement. Computer has the fact: '), 
        write('Construction Robot Advisor: I have found the disagreement. Computer has the fact: '), print_fact(F),write(' as an initial fact, but the user does not have it.\n'),nl, 
        write(Out,' is an initial fact, but the user does not have it.\n'),
        assert(different(F))
    ;   
        write('\nConstruction Robot Advisor: Because computer has the fact: '), 
        write(Out,'\nConstruction Robot Advisor: Because computer has the fact: '), 
        print_fact(F),
        write(' is an initial fact.\n'),
        write(Out,' is an initial fact.\n')
    ),
    conversations(false,_).
  
why(F):-
    nb_getval(fileOutput,Out), 
    node(_N, F, R, NL), !,                           
    rule(R, A, F),
    write('\nConstruction Robot Advisor: Because '),
    write(Out,'\nConstruction Robot Advisor: Because '),
    print_fact(F),
    write(' is deduced using RULE '),
    write(Out,' is deduced using RULE '),
    system_rule(R),
    assert(rule_used(R)),
    assert(asked_question(F)),!,
    assert(yr_user_computer(R, A, F)),!,
    write('---FROM FACTS---\n'),
    write(Out,'\n---FROM FACTS---\n'),
    pretty_print_node_list(NL,Pretty),
    write(Pretty),
    write(Out, Pretty),
    Used=true,
    conversations(Used,R),
    nl.

%% LOUISE:  You also want to store these facts in a list of facts that the user now knows the computer believes (or does not believe for negative literals),So you should be extending Y_user_computer and N_user_computer
 

pretty_print_node_list([],"").
pretty_print_node_list([Head|Tail],Out):-
    %write(Head),nl,
    pretty_head(Head),
   % print_top_level(Head,_Pretty),
    pretty_print_node_list(Tail,Out).


pretty_head(node(_, Fact, _Rule, _)):-
   ( \+node(_,Fact,unprovable,_)
     ->  (\+ y_user_computer(_N,Fact)
        ->  aggregate_all(count, y_user_computer(_,_), Count),
             N is Count +1,
            assert(y_user_computer(N,Fact)),!,
            print_fact(Fact),nl
        ;
            print_fact(Fact),nl
        )
     ; not_fact(Fact)
     ).

not_fact(not(H)):-
    \+ n_user_computer(_,H)
    ->  
        aggregate_all(count, n_user_computer(_,_), A),
        N_2 is A +1,
        assert(n_user_computer(N_2,H)),!,
        print_fact(not(H)),nl.
 

