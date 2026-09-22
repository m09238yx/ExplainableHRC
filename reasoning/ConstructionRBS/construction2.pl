:- [deduce_backwards],[why_question],[whynot_question],[write_list].
:- use_module(library(random)).
:- dynamic rule/3.

% Initial state facts for a construction safety decision
user_fact(1, crane_ready, initial_fact, []).
user_fact(2, load_secure, initial_fact, []).
user_fact(3, visibility_good, initial_fact, []).
user_fact(4, safe_distance, initial_fact, []).
user_fact(5, no_obstacle, initial_fact, []).
user_fact(6, not(worker_in_swing_zone), initial_fact, []).
user_fact(7, human_confirms, initial_fact, []).

% Dialogue example (no "what if"):
% Robot: I evaluated the lift. The crane is ready, the load is secured, and visibility is good — so I can prepare the lift.
% Robot: Preparation done. All workers are at a safe distance and there are no obstacles — I can position the crane.
% Robot: The crane is positioned and no worker is in the swing zone — I can lift the beam.
% Robot: Based on these conditions, I conclude the lift can be executed safely if you confirm. Do you confirm?
% Human: I confirm.
% Robot: Confirmation received. The lift is safe to execute. Proceeding with the lift.

% Rules representing safety constraints and decision structure
user_rule(1,[crane_ready, load_secure, visibility_good], can_prepare_lift).
user_rule(2,[can_prepare_lift, safe_distance, no_obstacle], can_position_crane).
user_rule(3,[can_position_crane, not(worker_in_swing_zone)], can_lift_beam).
user_rule(4,[can_lift_beam, human_confirms], safe_to_execute_lift).

rule(1,[crane_ready, load_secure, visibility_good], can_prepare_lift).
rule(2,[can_prepare_lift, safe_distance, no_obstacle], can_position_crane).
rule(3,[can_position_crane, not(worker_in_swing_zone)], can_lift_beam).
rule(4,[can_lift_beam, human_confirms], safe_to_execute_lift).

conclusion(safe_to_execute_lift).

node(1, crane_ready, initial_fact, []).
node(2, load_secure, initial_fact, []).
node(3, visibility_good, initial_fact, []).
node(4, safe_distance, initial_fact, []).
node(5, no_obstacle, initial_fact, []).
node(6, not(worker_in_swing_zone), initial_fact, []).
node(7, human_confirms, initial_fact, []).

fact_description(crane_ready):-
    nb_getval(fileOutput,Out),
    write(Out,'The crane is ready.'),
    write('The crane is ready.').
fact_description(load_secure):-
    nb_getval(fileOutput,Out),
    write(Out,'The load is secured.'),
    write('The load is secured.').
fact_description(visibility_good):-
    nb_getval(fileOutput,Out),
    write(Out,'Visibility is good.'),
    write('Visibility is good.').
fact_description(safe_distance):-
    nb_getval(fileOutput,Out),
    write(Out,'All workers are at a safe distance.'),
    write('All workers are at a safe distance.').
fact_description(no_obstacle):-
    nb_getval(fileOutput,Out),
    write(Out,'There are no obstacles in the crane path.'),
    write('There are no obstacles in the crane path.').
fact_description(not(worker_in_swing_zone)):-
    nb_getval(fileOutput,Out),
    write(Out,'No worker is in the lift swing zone.'),
    write('No worker is in the lift swing zone.').
fact_description(human_confirms):-
    nb_getval(fileOutput,Out),
    write(Out,'A human operator confirms the lift.'),
    write('A human operator confirms the lift.').
fact_description(can_prepare_lift):-
    nb_getval(fileOutput,Out),
    write(Out,'The system can prepare for lift.'),
    write('The system can prepare for lift.').
fact_description(can_position_crane):-
    nb_getval(fileOutput,Out),
    write(Out,'The crane can be positioned safely.'),
    write('The crane can be positioned safely.').
fact_description(can_lift_beam):-
    nb_getval(fileOutput,Out),
    write(Out,'The system can lift the beam.'),
    write('The system can lift the beam.').
fact_description(safe_to_execute_lift):-
    nb_getval(fileOutput,Out),
    write(Out,'The lift is safe to execute with human confirmation.'),
    write('The lift is safe to execute with human confirmation.').

rule_description(1):-
    write('1. If the crane is ready, the load is secured, and visibility is good, then the system can prepare for lift.'),
    nb_getval(fileOutput,Out),
    write(Out,'1. If the crane is ready, the load is secured, and visibility is good, then the system can prepare for lift.').
rule_description(2):-
    write('2. If lift preparation is complete, the distance is safe, and there are no obstacles, then the crane can be positioned safely.'),
    nb_getval(fileOutput,Out),
    write(Out,'2. If lift preparation is complete, the distance is safe, and there are no obstacles, then the crane can be positioned safely.').
rule_description(3):-
    write('3. If the crane is positioned safely and no worker is in the swing zone, then the system can lift the beam.'),
    nb_getval(fileOutput,Out),
    write(Out,'3. If the crane is positioned safely and no worker is in the swing zone, then the system can lift the beam.').
rule_description(4):-
    write('4. If the beam can be lifted and the human confirms, then it is safe to execute the lift.'),
    nb_getval(fileOutput,Out),
    write(Out,'4. If the beam can be lifted and the human confirms, then it is safe to execute the lift.').

r_description(1):-
    nb_getval(fileOutput,Out),
    write(Out,'1. If the crane is ready, the load is secured, and visibility is good, then the system can prepare for lift.'),
    write('1. If the crane is ready, the load is secured, and visibility is good, then the system can prepare for lift.'),nl.
r_description(2):-
    nb_getval(fileOutput,Out),
    write(Out,'2. If lift preparation is complete, the distance is safe, and there are no obstacles, then the crane can be positioned safely.'),
    write('2. If lift preparation is complete, the distance is safe, and there are no obstacles, then the crane can be positioned safely.'),nl.
r_description(3):-
    nb_getval(fileOutput,Out),
    write(Out,'3. If the crane is positioned safely and no worker is in the swing zone, then the system can lift the beam.'),
    write('3. If the crane is positioned safely and no worker is in the swing zone, then the system can lift the beam.'),nl.
r_description(4):-
    nb_getval(fileOutput,Out),
    write(Out,'4. If the beam can be lifted and the human confirms, then it is safe to execute the lift.'),
    write('4. If the beam can be lifted and the human confirms, then it is safe to execute the lift.'),nl.
system_rule(Rule):-
    r_description(Rule).

