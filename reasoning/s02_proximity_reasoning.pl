:- module(s02_proximity_reasoning, [
    proximity_default_state/1,
    proximity_decision/3,
    proximity_explain_why/3,
    proximity_explain_why_not/3
]).

:- use_module(explanation_engine).

/** <module> Distance-based safety decisions and structured explanations.

The module models six states for the first Gazebo explanation demo:
go, slow, stop, wait, resume, and goal_reached. State is passed explicitly as
a proximity_state{} dict so each decision remains isolated and reproducible.
*/


proximity_default_state(proximity_state{
    worker_distance: 4.0,
    caution_distance: 3.0,
    stop_distance: 1.5,
    resume_distance: 1.8,
    previous_state: go,
    clearance_duration: 0.0,
    required_clearance_duration: 1.0,
    resume_complete: true,
    goal_reached: false
}).


proximity_decision(State, Decision, ActiveConstraints) :-
    state_knowledge(State, Facts, Rules),
    once(prove(selected_action(Decision), Facts, Rules,
               proof(selected_action(Decision), rule(RuleId), _Premises))),
    decision_constraints(RuleId, ActiveConstraints),
    !.


proximity_explain_why(State, Decision,
                      why(decision(Decision), Reason, Evidence, Proof)) :-
    state_knowledge(State, Facts, Rules),
    once(prove(selected_action(Decision), Facts, Rules, Proof)),
    Proof = proof(selected_action(Decision), rule(RuleId), _),
    why_details(RuleId, State, Reason, Evidence),
    !.


proximity_explain_why_not(State, Alternative,
                          why_not(
                              alternative(Alternative),
                              selected(Selected),
                              blocked_by(Constraint),
                              Evidence,
                              Proof
                          )) :-
    state_knowledge(State, Facts, Rules),
    once(explain_why_not(Alternative, Selected, Facts, Rules,
                         why_not(Alternative, Selected, Constraint, Proof))),
    constraint_evidence(Constraint, State, Evidence),
    !.


state_knowledge(State, Facts, Rules) :-
    is_dict(State, proximity_state),
    Facts = [
        worker_distance(State.worker_distance),
        caution_distance(State.caution_distance),
        stop_distance(State.stop_distance),
        resume_distance(State.resume_distance),
        previous_state(State.previous_state),
        clearance_duration(State.clearance_duration),
        required_clearance_duration(State.required_clearance_duration),
        resume_complete(State.resume_complete),
        goal_reached(State.goal_reached)
    ],
    proximity_rules(Rules).


proximity_rules([
    rule(
        goal_has_priority,
        selected_action(goal_reached),
        [goal_reached(true)]
    ),
    rule(
        stop_at_minimum_separation,
        selected_action(stop),
        [
            goal_reached(false),
            worker_distance(Distance),
            stop_distance(Stop),
            less_than_or_equal(Distance, Stop)
        ]
    ),
    rule(
        remain_stopped_until_resume_threshold,
        selected_action(stop),
        [
            goal_reached(false),
            previous_state(stop),
            worker_distance(Distance),
            stop_distance(Stop),
            resume_distance(Resume),
            greater_than(Distance, Stop),
            less_than_or_equal(Distance, Resume)
        ]
    ),
    rule(
        reset_wait_inside_resume_threshold,
        selected_action(stop),
        [
            goal_reached(false),
            previous_state(wait),
            worker_distance(Distance),
            stop_distance(Stop),
            resume_distance(Resume),
            greater_than(Distance, Stop),
            less_than_or_equal(Distance, Resume)
        ]
    ),
    rule(
        reset_resume_inside_resume_threshold,
        selected_action(stop),
        [
            goal_reached(false),
            previous_state(resume),
            worker_distance(Distance),
            stop_distance(Stop),
            resume_distance(Resume),
            greater_than(Distance, Stop),
            less_than_or_equal(Distance, Resume)
        ]
    ),
    rule(
        start_clearance_wait,
        selected_action(wait),
        [
            goal_reached(false),
            previous_state(stop),
            worker_distance(Distance),
            resume_distance(Resume),
            greater_than(Distance, Resume)
        ]
    ),
    rule(
        continue_clearance_wait,
        selected_action(wait),
        [
            goal_reached(false),
            previous_state(wait),
            worker_distance(Distance),
            resume_distance(Resume),
            greater_than(Distance, Resume),
            clearance_duration(Duration),
            required_clearance_duration(Required),
            less_than(Duration, Required)
        ]
    ),
    rule(
        begin_controlled_resume,
        selected_action(resume),
        [
            goal_reached(false),
            previous_state(wait),
            worker_distance(Distance),
            resume_distance(Resume),
            greater_than(Distance, Resume),
            clearance_duration(Duration),
            required_clearance_duration(Required),
            greater_than_or_equal(Duration, Required)
        ]
    ),
    rule(
        continue_controlled_resume,
        selected_action(resume),
        [
            goal_reached(false),
            previous_state(resume),
            resume_complete(false)
        ]
    ),
    rule(
        slow_inside_caution_zone,
        selected_action(slow),
        [
            goal_reached(false),
            worker_distance(Distance),
            stop_distance(Stop),
            caution_distance(Caution),
            greater_than(Distance, Stop),
            less_than_or_equal(Distance, Caution)
        ]
    ),
    rule(
        go_outside_caution_zone,
        selected_action(go),
        [
            goal_reached(false),
            worker_distance(Distance),
            caution_distance(Caution),
            greater_than(Distance, Caution)
        ]
    ),
    rule(
        block_continue_at_goal,
        action_blocked(continue, goal_reached),
        [goal_reached(true)]
    ),
    rule(
        block_continue_at_minimum_separation,
        action_blocked(continue, minimum_separation),
        [
            worker_distance(Distance),
            stop_distance(Stop),
            less_than_or_equal(Distance, Stop)
        ]
    ),
    rule(
        block_continue_until_resume_threshold,
        action_blocked(continue, resume_threshold_not_cleared),
        [
            previous_state(stop),
            worker_distance(Distance),
            stop_distance(Stop),
            resume_distance(Resume),
            greater_than(Distance, Stop),
            less_than_or_equal(Distance, Resume)
        ]
    ),
    rule(
        block_continue_while_waiting,
        action_blocked(continue, clearance_confirmation),
        [selected_action(wait)]
    ),
    rule(
        block_continue_while_resuming,
        action_blocked(continue, controlled_acceleration),
        [selected_action(resume)]
    ),
    rule(
        block_full_speed_in_caution_zone,
        action_blocked(continue, caution_zone),
        [selected_action(slow)]
    )
]).


decision_constraints(goal_has_priority, [goal_reached]).
decision_constraints(stop_at_minimum_separation, [minimum_separation]).
decision_constraints(remain_stopped_until_resume_threshold,
                     [resume_threshold_not_cleared]).
decision_constraints(reset_wait_inside_resume_threshold,
                     [resume_threshold_not_cleared]).
decision_constraints(reset_resume_inside_resume_threshold,
                     [resume_threshold_not_cleared]).
decision_constraints(start_clearance_wait, [clearance_confirmation]).
decision_constraints(continue_clearance_wait, [clearance_confirmation]).
decision_constraints(begin_controlled_resume, [controlled_acceleration]).
decision_constraints(continue_controlled_resume, [controlled_acceleration]).
decision_constraints(slow_inside_caution_zone, [caution_zone]).
decision_constraints(go_outside_caution_zone, []).


why_details(goal_has_priority, _State,
            goal_reached,
            evidence([goal_reached(true)])).
why_details(stop_at_minimum_separation, State,
            minimum_separation,
            evidence([
                observed(worker_distance, State.worker_distance),
                required_minimum(stop_distance, State.stop_distance)
            ])).
why_details(remain_stopped_until_resume_threshold, State,
            resume_threshold_not_cleared,
            evidence([
                observed(worker_distance, State.worker_distance),
                required_clearance(resume_distance, State.resume_distance)
            ])).
why_details(reset_wait_inside_resume_threshold, State,
            resume_threshold_not_cleared,
            evidence([
                observed(worker_distance, State.worker_distance),
                required_clearance(resume_distance, State.resume_distance)
            ])).
why_details(reset_resume_inside_resume_threshold, State,
            resume_threshold_not_cleared,
            evidence([
                observed(worker_distance, State.worker_distance),
                required_clearance(resume_distance, State.resume_distance)
            ])).
why_details(start_clearance_wait, State,
            clearance_confirmation,
            evidence([
                observed(worker_distance, State.worker_distance),
                cleared(resume_distance, State.resume_distance),
                observed(clearance_duration, State.clearance_duration),
                required(clearance_duration,
                         State.required_clearance_duration)
            ])).
why_details(continue_clearance_wait, State,
            clearance_confirmation,
            evidence([
                observed(clearance_duration, State.clearance_duration),
                required(clearance_duration,
                         State.required_clearance_duration)
            ])).
why_details(begin_controlled_resume, State,
            clearance_confirmed,
            evidence([
                observed(worker_distance, State.worker_distance),
                observed(clearance_duration, State.clearance_duration),
                required(clearance_duration,
                         State.required_clearance_duration)
            ])).
why_details(continue_controlled_resume, State,
            controlled_acceleration,
            evidence([resume_complete(State.resume_complete)])).
why_details(slow_inside_caution_zone, State,
            caution_zone,
            evidence([
                observed(worker_distance, State.worker_distance),
                caution_threshold(State.caution_distance),
                stop_threshold(State.stop_distance)
            ])).
why_details(go_outside_caution_zone, State,
            outside_caution_zone,
            evidence([
                observed(worker_distance, State.worker_distance),
                caution_threshold(State.caution_distance)
            ])).


constraint_evidence(goal_reached, _State,
                    evidence([goal_reached(true)])).
constraint_evidence(minimum_separation, State,
                    evidence([
                        observed(worker_distance, State.worker_distance),
                        required_minimum(stop_distance, State.stop_distance)
                    ])).
constraint_evidence(resume_threshold_not_cleared, State,
                    evidence([
                        observed(worker_distance, State.worker_distance),
                        required_clearance(resume_distance,
                                           State.resume_distance)
                    ])).
constraint_evidence(clearance_confirmation, State,
                    evidence([
                        observed(clearance_duration,
                                 State.clearance_duration),
                        required(clearance_duration,
                                 State.required_clearance_duration)
                    ])).
constraint_evidence(controlled_acceleration, State,
                    evidence([resume_complete(State.resume_complete)])).
constraint_evidence(caution_zone, State,
                    evidence([
                        observed(worker_distance, State.worker_distance),
                        caution_threshold(State.caution_distance)
                    ])).
