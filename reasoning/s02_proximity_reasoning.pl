:- module(s02_proximity_reasoning, [
    proximity_default_state/1,
    proximity_decision/3,
    proximity_explain_why/3,
    proximity_explain_why_not/3,
    proximity_dialogue_reply/4,
    proximity_chat/0,
    proximity_chat/1,
    proximity_chat/3
]).

:- use_module(explanation_engine).
:- use_module(library(readutil)).

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


proximity_dialogue_reply(State, show_decision, Text,
                         state_summary(Decision, Constraints)) :-
    proximity_decision(State, Decision, Constraints),
    format(string(Text),
           'Current decision: ~w. Worker distance: ~2f m. Active constraints: ~w.',
           [Decision, State.worker_distance, Constraints]).
proximity_dialogue_reply(State, why_decision, Text, Explanation) :-
    proximity_decision(State, Decision, _),
    proximity_explain_why(State, Decision, Explanation),
    Explanation = why(decision(Decision), Reason, Evidence, _),
    why_reply(Decision, Reason, Evidence, State, Text).
proximity_dialogue_reply(State, why_not(Alternative), Text, Explanation) :-
    proximity_explain_why_not(State, Alternative, Explanation),
    Explanation = why_not(alternative(Alternative), selected(Selected),
                          blocked_by(Constraint), Evidence, _),
    format(string(Text),
           'I did not ~w; I selected ~w because ~w blocks that alternative. Evidence: ~q.',
           [Alternative, Selected, Constraint, Evidence]).
proximity_dialogue_reply(State, show_facts, Text, facts(Facts)) :-
    state_knowledge(State, Facts, _),
    format(string(Text), 'Facts used for this decision: ~q.', [Facts]).
proximity_dialogue_reply(State, show_rule, Text, applied_rule(RuleId)) :-
    decision_proof(State, _Decision, Proof),
    Proof = proof(_, rule(RuleId), _),
    format(string(Text), 'Applied rule: ~w.', [RuleId]).
proximity_dialogue_reply(State, show_proof, Text, Proof) :-
    decision_proof(State, _Decision, Proof),
    with_output_to(
        string(Text),
        (current_output(Output), write_proof_tree(Output, Proof, 0))).


why_reply(stop, minimum_separation, _Evidence, State, Text) :-
    format(string(Text),
           'I stopped because the worker is ~2f m away, at or inside the ~2f m minimum separation.',
           [State.worker_distance, State.stop_distance]).
why_reply(stop, resume_threshold_not_cleared, _Evidence, State, Text) :-
    format(string(Text),
           'I remain stopped because the worker is ~2f m away and has not cleared the ~2f m resume threshold.',
           [State.worker_distance, State.resume_distance]).
why_reply(wait, clearance_confirmation, _Evidence, State, Text) :-
    format(string(Text),
           'I am waiting to confirm clearance. The safe distance has held for ~2f s; ~2f s is required.',
           [State.clearance_duration,
            State.required_clearance_duration]).
why_reply(resume, clearance_confirmed, _Evidence, State, Text) :-
    format(string(Text),
           'I began a controlled resume because the worker cleared ~2f m and clearance was confirmed for ~2f s.',
           [State.resume_distance,
            State.required_clearance_duration]).
why_reply(resume, controlled_acceleration, _Evidence, _State, Text) :-
    Text = 'I am resuming under controlled acceleration and have not yet reached the target speed.'.
why_reply(slow, caution_zone, _Evidence, State, Text) :-
    format(string(Text),
           'I slowed because the worker is ~2f m away, inside the ~2f m caution zone.',
           [State.worker_distance, State.caution_distance]).
why_reply(go, outside_caution_zone, _Evidence, State, Text) :-
    format(string(Text),
           'I continue because the worker is ~2f m away, outside the ~2f m caution zone.',
           [State.worker_distance, State.caution_distance]).
why_reply(goal_reached, goal_reached, _Evidence, _State,
          "I stopped because the goal has been reached.").


decision_proof(State, Decision, Proof) :-
    state_knowledge(State, Facts, Rules),
    once(prove(selected_action(Decision), Facts, Rules, Proof)).


write_proof_tree(Output, proof(Goal, fact), Indent) :-
    write_indent(Output, Indent),
    format(Output, '~q [fact]~n', [Goal]).
write_proof_tree(Output, proof(Goal, builtin), Indent) :-
    write_indent(Output, Indent),
    format(Output, '~q [builtin]~n', [Goal]).
write_proof_tree(Output, proof(Goal, rule(RuleId), Premises), Indent) :-
    write_indent(Output, Indent),
    format(Output, '~q [rule: ~w]~n', [Goal, RuleId]),
    ChildIndent is Indent + 2,
    maplist(write_proof_tree_at(Output, ChildIndent), Premises).


write_proof_tree_at(Output, Indent, Proof) :-
    write_proof_tree(Output, Proof, Indent).


write_indent(_Output, 0) :-
    !.
write_indent(Output, Count) :-
    put_char(Output, ' '),
    Remaining is Count - 1,
    write_indent(Output, Remaining).


proximity_chat :-
    proximity_default_state(State),
    proximity_chat(State).


proximity_chat(State) :-
    current_input(Input),
    current_output(Output),
    proximity_chat(State, Input, Output).


proximity_chat(State, Input, Output) :-
    proximity_decision(State, Decision, Constraints),
    format(Output, '~n--- S02 Proximity Explanation Dialogue ---~n', []),
    format(Output,
           'Robot: Current decision is ~w. Active constraints: ~w.~n',
           [Decision, Constraints]),
    proximity_chat_loop(State, Input, Output).


proximity_chat_loop(State, Input, Output) :-
    format(Output, '~nPlease select a question:~n', []),
    format(Output, '1. What is the current decision?~n', []),
    format(Output, '2. Why did you make this decision?~n', []),
    format(Output, '3. Why not continue?~n', []),
    format(Output, '4. Which facts were used?~n', []),
    format(Output, '5. Which rule was applied?~n', []),
    format(Output, '6. Show the complete proof tree.~n', []),
    format(Output, '7. Exit.~n', []),
    format(Output, 'Enter a number from 1 to 7.~n', []),
    format(Output, 'User: ', []),
    flush_output(Output),
    read_line_to_string(Input, Line),
    proximity_parse_choice(Line, Choice),
    proximity_handle_choice(Choice, State, Input, Output).


proximity_parse_choice(end_of_file, end_of_file) :-
    !.
proximity_parse_choice(Line, Choice) :-
    normalize_space(string(Trimmed), Line),
    string_codes(Trimmed, InputCodes),
    (   append(NumberCodes, [0'.], InputCodes)
    ->  true
    ;   NumberCodes = InputCodes
    ),
    catch(number_codes(Choice, NumberCodes), _, fail),
    !.
proximity_parse_choice(_Line, invalid).


proximity_handle_choice(7, _State, _Input, Output) :-
    format(Output, 'Robot: Dialogue ended.~n', []).
proximity_handle_choice(end_of_file, _State, _Input, Output) :-
    format(Output, 'Robot: Dialogue ended.~n', []).
proximity_handle_choice(Choice, State, Input, Output) :-
    proximity_choice_intent(Choice, Intent),
    !,
    (   proximity_dialogue_reply(State, Intent, Text, _Explanation)
    ->  format(Output, 'Robot: ~s~n', [Text])
    ;   format(Output,
               'Robot: That question is not applicable to the current decision.~n',
               [])
    ),
    proximity_chat_loop(State, Input, Output).
proximity_handle_choice(_Choice, State, Input, Output) :-
    format(Output, 'Robot: Please choose a number from 1 to 7.~n', []),
    proximity_chat_loop(State, Input, Output).


proximity_choice_intent(1, show_decision).
proximity_choice_intent(2, why_decision).
proximity_choice_intent(3, why_not(continue)).
proximity_choice_intent(4, show_facts).
proximity_choice_intent(5, show_rule).
proximity_choice_intent(6, show_proof).


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
