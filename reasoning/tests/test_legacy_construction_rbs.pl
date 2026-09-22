:- begin_tests(legacy_construction_rbs).

:- consult('../ConstructionRBS/legal_move_v1.pl').
:- consult('../ConstructionRBS/construction1.pl').


test(normal_backward_deduction) :-
    deduce_backwards(can_lift_beam,
                     node(_, can_lift_beam, 4, Premises)),
    Premises = [
        node(_, can_start_erection, 2, _),
        node(_, can_move_robot, 3, _),
        node(_, beam_secured, initial_fact, []),
        node(_, not(worker_in_swing_zone), initial_fact, [])
    ].


test(why_support_is_present_after_deduction) :-
    once(deduce_backwards(can_lift_beam, _)),
    once(node(_, can_lift_beam, 4, Premises)),
    memberchk(node(_, can_start_erection, 2, _), Premises),
    memberchk(node(_, can_move_robot, 3, _), Premises).


test(why_not_controlled_disagreement_precondition,
     [setup(retractall(node(_, crew_ready, _, _)))]) :-
    user_fact(_, crew_ready, initial_fact, []),
    \+ node(_, crew_ready, _, _).


:- end_tests(legacy_construction_rbs).
