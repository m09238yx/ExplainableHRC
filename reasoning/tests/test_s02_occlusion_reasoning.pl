:- begin_tests(s02_occlusion_reasoning).

:- use_module('../s02_occlusion_reasoning').


occluded_state(s02_state{
    visibility_confidence: 0.52,
    minimum_visibility: 0.60,
    observed_entity: worker,
    occluding_object: forklift,
    zone: zone_c,
    nominal_action: continue
}).


clear_state(s02_state{
    visibility_confidence: 0.85,
    minimum_visibility: 0.60,
    observed_entity: worker,
    occluding_object: forklift,
    zone: zone_c,
    nominal_action: continue
}).


test(low_visibility_selects_pause) :-
    occluded_state(State),
    s02_decision(State, pause, [visibility_below_minimum]).


test(reliable_visibility_selects_continue) :-
    clear_state(State),
    s02_decision(State, continue, []).


test(why_pause_is_grounded_in_trace_values) :-
    occluded_state(State),
    s02_explain_why(State, pause, Explanation),
    Explanation = why(
        decision(pause),
        constraint(visibility_below_minimum),
        evidence([
            observed(visibility_confidence, 0.52),
            required_minimum(visibility_confidence, 0.60),
            caused_by(occlusion(worker, forklift, zone_c))
        ]),
        proof(selected_action(pause),
              rule(pause_on_visibility_constraint), _)
    ).


test(why_not_continue_identifies_violated_constraint) :-
    occluded_state(State),
    s02_explain_why_not(State, continue, Explanation),
    Explanation = why_not(
        alternative(continue),
        selected(pause),
        blocked_by(visibility_below_minimum),
        violation(
            observed(visibility_confidence, 0.52),
            required_minimum(visibility_confidence, 0.60)
        ),
        proof(action_blocked(continue, visibility_below_minimum),
              rule(block_continue_on_visibility_constraint), _)
    ).


test(why_pause_fails_when_pause_was_not_selected, [fail]) :-
    clear_state(State),
    s02_explain_why(State, pause, _).


test(why_not_continue_fails_when_continue_is_safe, [fail]) :-
    clear_state(State),
    s02_explain_why_not(State, continue, _).


test(dialogue_why_reply_is_grounded) :-
    occluded_state(State),
    s02_dialogue_reply(State, why_decision, Text, Explanation),
    assertion(sub_string(Text, _, _, _, 'visibility confidence 0.52')),
    assertion(sub_string(Text, _, _, _, 'forklift')),
    Explanation = why(decision(pause), _, _, _).


test(dialogue_why_not_reply_names_constraint) :-
    occluded_state(State),
    s02_dialogue_reply(State, why_not(continue), Text, Explanation),
    assertion(sub_string(Text, _, _, _, 'violate the visibility constraint')),
    Explanation = why_not(alternative(continue), selected(pause), _, _, _).


test(dialogue_clarification_preserves_reference) :-
    occluded_state(State),
    s02_dialogue_reply(State, clarify_occlusion, Text, Clarification),
    assertion(sub_string(Text, _, _, _, 'forklift')),
    assertion(sub_string(Text, _, _, _, 'worker')),
    assertion(sub_string(Text, _, _, _, 'zone_c')),
    Clarification = clarification(occlusion(worker, forklift, zone_c)).


test(interactive_chat_handles_multiple_turns) :-
    occluded_state(State),
    open_string('1\n2\n3\n4\n5\n', Input),
    with_output_to(
        string(Output),
        (current_output(Stream), s02_chat(State, Input, Stream))),
    close(Input),
    assertion(sub_string(Output, _, _, _, 'I paused because')),
    assertion(sub_string(Output, _, _, _, 'I did not continue because')),
    assertion(sub_string(Output, _, _, _, 'obstructed my view')),
    assertion(sub_string(Output, _, _, _, 'Active constraints')),
    assertion(sub_string(Output, _, _, _, 'Dialogue ended')).


test(interactive_chat_also_accepts_prolog_style_periods) :-
    occluded_state(State),
    open_string('1.\n5.\n', Input),
    with_output_to(
        string(Output),
        (current_output(Stream), s02_chat(State, Input, Stream))),
    close(Input),
    assertion(sub_string(Output, _, _, _, 'I paused because')),
    assertion(sub_string(Output, _, _, _, 'Dialogue ended')).


test(interactive_chat_recovers_from_invalid_input) :-
    occluded_state(State),
    open_string('hello\n5\n', Input),
    with_output_to(
        string(Output),
        (current_output(Stream), s02_chat(State, Input, Stream))),
    close(Input),
    assertion(sub_string(Output, _, _, _,
                         'Please choose a number from 1 to 5')),
    assertion(sub_string(Output, _, _, _, 'Dialogue ended')).


:- end_tests(s02_occlusion_reasoning).
