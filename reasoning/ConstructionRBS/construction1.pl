:- [deduce_backwards],[why_question],[whynot_question],[write_list].
:- use_module(library(random)).
:- dynamic rule/3.

user_fact(1, available(concrete), initial_fact, []).
user_fact(2, available(steel), initial_fact, []).
user_fact(3, site_ready, initial_fact, []).
user_fact(4, crew_ready, initial_fact, []).
user_fact(5, robot_functional, initial_fact, []).
user_fact(6, beam_secured, initial_fact, []).
user_fact(7, not(worker_in_path), initial_fact, []).
user_fact(8, not(worker_in_swing_zone), initial_fact, []).

% Dialogue example for construction1 (no "what if"):
% Robot: I checked site readiness: concrete and steel are available and the site is ready — I can build the foundation.
% Robot: Foundation can be built and the crew is ready — I can start erection.
% Robot: The robot is functional and no worker is in its path — I can move safely.
% Robot: Erection can start, the robot can move safely, the beam is secured, and no worker is in the swing zone — I can lift the beam.
% Robot: I conclude the robot can lift the beam now.

user_rule(1,[available(concrete), available(steel), site_ready], can_build_foundation).
user_rule(2,[can_build_foundation, crew_ready], can_start_erection).
user_rule(3,[robot_functional, not(worker_in_path)], can_move_robot).
user_rule(4,[can_start_erection, can_move_robot, beam_secured, not(worker_in_swing_zone)], can_lift_beam).

rule(1,[available(concrete), available(steel), site_ready], can_build_foundation).
rule(2,[can_build_foundation, crew_ready], can_start_erection).
rule(3,[robot_functional, not(worker_in_path)], can_move_robot).
rule(4,[can_start_erection, can_move_robot, beam_secured, not(worker_in_swing_zone)], can_lift_beam).

conclusion(can_lift_beam).

node(1, available(concrete), initial_fact, []).
node(2, available(steel), initial_fact, []).
node(3, site_ready, initial_fact, []).
node(4, crew_ready, initial_fact, []).
node(5, robot_functional, initial_fact, []).
node(6, beam_secured, initial_fact, []).
node(7, not(worker_in_path), initial_fact, []).
node(8, not(worker_in_swing_zone), initial_fact, []).

fact_description(available(concrete)):-
    nb_getval(fileOutput,Out),
    write(Out,'Concrete is available.'),
    write('Concrete is available.').
fact_description(available(steel)):-
    nb_getval(fileOutput,Out),
    write(Out,'Steel is available.'),
    write('Steel is available.').
fact_description(site_ready):-
    nb_getval(fileOutput,Out),
    write(Out,'The site is ready for construction.'),
    write('The site is ready for construction.').
fact_description(crew_ready):-
    nb_getval(fileOutput,Out),
    write(Out,'The crew is ready.'),
    write('The crew is ready.').
fact_description(robot_functional):-
    nb_getval(fileOutput,Out),
    write(Out,'The robot is functional.'),
    write('The robot is functional.').
fact_description(beam_secured):-
    nb_getval(fileOutput,Out),
    write(Out,'The beam is secured.'),
    write('The beam is secured.').
fact_description(not(worker_in_path)):-
    nb_getval(fileOutput,Out),
    write(Out,'No worker is inside the robot path.'),
    write('No worker is inside the robot path.').
fact_description(not(worker_in_swing_zone)):-
    nb_getval(fileOutput,Out),
    write(Out,'No worker is inside the swing zone.'),
    write('No worker is inside the swing zone.').
fact_description(can_build_foundation):-
    nb_getval(fileOutput,Out),
    write(Out,'The robot can build the foundation.'),
    write('The robot can build the foundation.').
fact_description(can_start_erection):-
    nb_getval(fileOutput,Out),
    write(Out,'The robot can start erection.'),
    write('The robot can start erection.').
fact_description(can_move_robot):-
    nb_getval(fileOutput,Out),
    write(Out,'The robot can move safely.'),
    write('The robot can move safely.').
fact_description(can_lift_beam):-
    nb_getval(fileOutput,Out),
    write(Out,'The robot can lift the beam.'),
    write('The robot can lift the beam.').

rule_description(1):-
    write('1. If concrete and steel are available and the site is ready, then the robot can build the foundation.'),
    nb_getval(fileOutput,Out),
    write(Out,'1. If concrete and steel are available and the site is ready, then the robot can build the foundation.').
rule_description(2):-
    write('2. If the foundation can be built and the crew is ready, then the robot can start erection.'),
    nb_getval(fileOutput,Out),
    write(Out,'2. If the foundation can be built and the crew is ready, then the robot can start erection.').
rule_description(3):-
    write('3. If the robot is functional and no worker is in the path, then the robot can move safely.'),
    nb_getval(fileOutput,Out),
    write(Out,'3. If the robot is functional and no worker is in the path, then the robot can move safely.').
rule_description(4):-
    write('4. If erection can start, the robot can move safely, the beam is secured, and no worker is in the swing zone, then the robot can lift the beam.'),
    nb_getval(fileOutput,Out),
    write(Out,'4. If erection can start, the robot can move safely, the beam is secured, and no worker is in the swing zone, then the robot can lift the beam.').

r_description(1):-
    nb_getval(fileOutput,Out),
    write(Out,'1. If concrete and steel are available and the site is ready, then the robot can build the foundation.'),
    write('1. If concrete and steel are available and the site is ready, then the robot can build the foundation.'),nl.
r_description(2):-
    nb_getval(fileOutput,Out),
    write(Out,'2. If the foundation can be built and the crew is ready, then the robot can start erection.'),
    write('2. If the foundation can be built and the crew is ready, then the robot can start erection.'),nl.
r_description(3):-
    nb_getval(fileOutput,Out),
    write(Out,'3. If the robot is functional and no worker is in the path, then the robot can move safely.'),
    write('3. If the robot is functional and no worker is in the path, then the robot can move safely.'),nl.
r_description(4):-
    nb_getval(fileOutput,Out),
    write(Out,'4. If erection can start, the robot can move safely, the beam is secured, and no worker is in the swing zone, then the robot can lift the beam.'),
    write('4. If erection can start, the robot can move safely, the beam is secured, and no worker is in the swing zone, then the robot can lift the beam.'),nl.
system_rule(Rule):-
    r_description(Rule).
