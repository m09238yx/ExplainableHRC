:- [deduce_backwards],[why_question],[whynot_question],[write_list].
:- use_module(library(random)).
:-dynamic node/4, user_fact/4, different/1, asked_question/1,n_computer_user/1,y_computer_user/2,y_user_computer/2,n_user_computer/2,yr_user_computer/3,yr_computer_user/3,computer_ask_user/2,rule_used/1,d_rule/2.
:- dynamic rule/3.

chat:-
    print_welcome,
    print_conclusion(Conclusion,F),
    assert(asked_question(F)),
    ask_agree(Conclusion,F),
    conversations(_Used,_).

print_welcome:-
    exampleOpen,
    write_user_fact,
    write_user_rule.

exampleOpen:-
    get_time(N),
    string_concat(N, ' .txt',Filename),
    open(Filename,write, Out),
    write(Out,'\n----------CONVERSATION REPORT ----------\n'),
    nb_setval(fileOutput,Out).

writeBothFact(String):-
    write(String),
    nb_getval(fileOutput,Out),
    write(Out,String).

writeBothRule(String):-
    write(String),write(nl),
    nb_getval(fileOutput,Out),
    write(Out,String),write(Out,nl).

exampleClose:-
    nb_getval(fileOutput,Out),
    close(Out).

print_conclusion(Conclusion,F):-
    write('\n----------CONVERSATION ----------\n'),nl,
    nb_getval(fileOutput,Out),
    write('Construction Robot Advisor: '),conclusion(F), 
    write(Out,'\nConstruction Robot Advisor: '),
    (
        deduce_backwards(F,node(_ID, F, _R, _DAG))
    ->  
        print_fact(F),write(': True.\n'),nl,
        write(Out,' is true\n'),
        Conclusion =true
    ;   
        print_fact(F),write(': False.\n'),nl,
        write(Out,' is false\n'),
        Conclusion = false
        
    ).

ask_agree(Conclusion,F):-
    repeat,
    nb_getval(fileOutput,Out),
    write('Construction Robot Advisor: Do you agree with this conclusion?\n'),
    write(Out, 'Construction Robot Advisor: [Do you agree with this conclusion?]\n'),
    yes_no,
    write('User:'),read(N),
    (   N =:= 1
    ->   write(Out,'User: YES, BYE\n'),exampleClose,write('Construction Robot Advisor: Bye\n')->halt
    ;   N =:= 2
    ->   write(Out,'User: NO\n'),
    
        (   Conclusion =true
        ->  database(Conclusion,F),
            write('User: Why do you believe '),
            write(Out,'User: Why do you believe '), print_fact(F), write(Out,'?\n'),write('?\n'), 
            why(F)
        ;   database(Conclusion,F),
            write('User: Why do you not believe '), 
            write(Out,'User: Why do you not believe '), print_fact(F), write('?\n'),write(Out, '?\n'),
            write('\nConstruction Robot Advisor: Why do you believe '), 
            write(Out,'\nConstruction Robot Advisor: Why do you believe '), print_fact(F), write('? '),write(Out, '? '),
            whynot(F)
        )
    ;   write("Not a valid choice, try again..."), nl,fail
    ).


database(Conclusion,F):-
   (    Conclusion =true
    ->
        assert(n_computer_user(F)),!,     %% LOUISE: At this point the computer should add F to N_computer_user and Y_user_computer
        aggregate_all(count, y_user_computer(_,_), Count1),
        A is Count1 +1,
        assert(y_user_computer(A,F)),!,
        assert(asked_question(F)),!
    ;
        aggregate_all(count, n_user_computer(_,_), Count2),
        B is Count2 +1,
        assert(n_user_computer(B,F)),!,
        %write(n_user_computer(B,F)),
        aggregate_all(count, y_computer_user(_,_), Count3),
        C is Count3 +1,
        assert(y_computer_user(C,F)),!,     %% LOUISE: At this point the computer should add F to Y_computer_user and N_user_computer
        assert(asked_question(F)),!
    ).



conversations(Used,R):-
    repeat,
    write('\n----------SELECT A QUESTION OR EXIT----------\n'),nl,
    (Used=true
    -> dialogue(R)
    ; dialogue2).

dialogue(R):-
    repeat,
    nb_getval(fileOutput,Out),
    write('Construction Robot Advisor: Please select an option:\n'),
    write('1. Exit\n'),
    write('2. I do not have the rule used by the system or I have a different rule\n'),
    write(Out,'\nConstruction Robot Advisor: Please select an option:\n'),
    write(Out,'\n1. Exit\n'),
    write(Out,'\n2. I do not have this rule used by computer\n'),
    write_why_list,!,
    write_whynot_list,!,
    write('User:'),
    prompt(_, ''),
    read(N),
    (   
        N=:= 1
     -> write(Out,'\nConstruction Robot Advisor:Bye\n'),exampleClose,write('Construction Robot Advisor:Bye\n')->halt
    ;   
        N=:= 2
    ->  rule(R,A,F),
       (\+ user_rule(_,A,F),
        write(Out, '\n----------DISAGREEMENT----------\n'),
        write(Out,'\nConstruction Robot Advisor: I have found a disagreement. The system used a rule the user does not have.\n'),
        write('\nConstruction Robot Advisor: I have found a disagreement. The system used a rule the user does not have.\n')
        ;  write('\nConstruction Robot Advisor: The system and user both have this rule; please select again.\n'),
             write(Out,'\nConstruction Robot Advisor: The system and user both have this rule; please select again.\n'),
            dialogue2
        )
    ;   
        N1 is N-1,
        y_user_computer(N1, Fact), N \=1, N \=2
        ->  write(Out,'\nUser: Why do you believe '),write('\nUser: Why do you believe '),print_fact(Fact), write('?\n'),write(Out,'?\n'),
            assert(asked_question(Fact)),
            why(Fact)
    ;   
        aggregate_all(count, y_user_computer(_,_), Count),
        A is N-Count-1,
        n_user_computer(A,Fact), N \=1, N \=2
         -> write(Out,'\nUser: Why do you not believe '),write('\nUser: Why do you not believe '),print_fact(Fact), write('?\n'),write(Out,'?\n'),
            write(Out,'\nConstruction Robot Advisor: Why do you believe '),write('\nConstruction Robot Advisor: Why do you believe '), print_fact(Fact), write('? '),write(Out, '?'),
            assert(asked_question(Fact)),
            whynot(Fact)
    ;   
        write('Not a valid choice, try again...'), nl,fail
    ).
print_deduction_tree(Fact) :-
    (   deduce_backwards(Fact, Node)
    ->  write('Deduction tree for '), write(Fact), write(':'), nl,
        print_node(Node, '', true)
    ;   write('Cannot deduce '), write(Fact), write('.'), nl
    ).

print_node(node(_ID, Fact, Rule, Children), Prefix, Last) :-
    connector(Last, Conn),
    write(Prefix), write(Conn), write_term(Fact, [quoted(false)]),
    ( Rule == unprovable -> write(' [assumed not]') ; true ), nl,
    next_prefix(Prefix, Last, Prefix2),
    print_children(Children, Prefix2).

print_children([], _Prefix).
print_children([Child], Prefix) :-
    print_node(Child, Prefix, true).
print_children([Child|Tail], Prefix) :-
    print_node(Child, Prefix, false),
    print_children(Tail, Prefix).

connector(true, '└─ ').
connector(false, '├─ ').

next_prefix(Prefix, true, New) :-
    string_concat(Prefix, '   ', New).
next_prefix(Prefix, false, New) :-
    string_concat(Prefix, '│  ', New).


dialogue2:-
    repeat,
    nb_getval(fileOutput,Out),
    write('Construction Robot Advisor: Please select an option:\n'),
    write('1. Exit\n'),
    write(Out,'\nConstruction Robot Advisor: Please select an option:\n'),
    write(Out,'\n1. Exit\n'),
    write_why_list,!,
    write_whynot_list,!,
    write('User:'),
    prompt(_, ''),
    read(N),
    (   
        N=:= 1
     -> write(Out,'\nConstruction Robot Advisor:Bye\n'),exampleClose,write('Construction Robot Advisor:Bye\n')->halt
   ;   
        N1 is N-1,
        y_user_computer(N1, Fact), N \=1, N \=2
        ->  write(Out,'\nUser: Why do you believe '),write('\nUser: Why do you believe '),print_fact(Fact), write('?\n'),write(Out,'?\n'),
            assert(asked_question(Fact)),
            why(Fact)
    ;   
        aggregate_all(count, y_user_computer(_,_), Count),
        A is N-Count-1,
        n_user_computer(A,Fact), N \=1, N \=2
         -> write(Out,'\nUser: Why do you not believe '),write('\nUser: Why do you not believe '),print_fact(Fact), write('?\n'),write(Out,'?\n'),
            write(Out,'\nConstruction Robot Advisor: Why do you believe '),write('\nConstruction Robot Advisor: Why do you believe '), print_fact(Fact), write('? '),write(Out, '?'),
            assert(asked_question(Fact)),
            whynot(Fact)
    ;   
        write('Not a valid choice, try again...'), nl,fail
    ).