:- module(s02_occlusion_reasoning, [
    s02_default_state/1,
    s02_decision/3,
    s02_explain_why/3,
    s02_explain_why_not/3,
    s02_dialogue_reply/4,
    s02_chat/0,
    s02_chat/1,
    s02_chat/3
]).

:- use_module(explanation_engine).
:- use_module(library(readutil)).

/** <module> Paper-aligned S02 occlusion reasoning prototype.

The state is an explicit SWI-Prolog dict. This first slice covers the paper's
deterministic visibility example: a forklift occludes a worker in Zone C,
visibility drops below the certified minimum, and PAUSE overrides CONTINUE.
*/


s02_default_state(s02_state{
    visibility_confidence: 0.52,
    minimum_visibility: 0.60,
    observed_entity: worker,
    occluding_object: forklift,
    zone: zone_c,
    nominal_action: continue
}).


s02_decision(State, Decision, ActiveConstraints) :-
    state_knowledge(State, Facts, Rules),
    once(prove(selected_action(Decision), Facts, Rules, _)),
    findall(Constraint,
            prove(constraint_active(Constraint), Facts, Rules, _),
            Constraints0),
    sort(Constraints0, ActiveConstraints),
    !.


s02_explain_why(State, Action,
                why(
                    decision(Action),
                    constraint(visibility_below_minimum),
                    evidence([
                        observed(visibility_confidence, Confidence),
                        required_minimum(visibility_confidence, Minimum),
                        caused_by(occlusion(Entity, Occluder, Zone))
                    ]),
                    Proof
                )) :-
    state_knowledge(State, Facts, Rules),
    Action = pause,
    memberchk(visibility_confidence(Confidence), Facts),
    memberchk(minimum_visibility(Minimum), Facts),
    memberchk(observed_entity(Entity), Facts),
    memberchk(occluding_object(Occluder), Facts),
    memberchk(current_zone(Zone), Facts),
    once(explain_why(selected_action(Action), Facts, Rules,
                     why(selected_action(Action), Proof))),
    !.

s02_explain_why(State, Action,
                why(
                    decision(Action),
                    condition(visibility_meets_minimum),
                    evidence([
                        observed(visibility_confidence, Confidence),
                        required_minimum(visibility_confidence, Minimum)
                    ]),
                    Proof
                )) :-
    state_knowledge(State, Facts, Rules),
    Action = continue,
    memberchk(visibility_confidence(Confidence), Facts),
    memberchk(minimum_visibility(Minimum), Facts),
    once(explain_why(selected_action(Action), Facts, Rules,
                     why(selected_action(Action), Proof))),
    !.


s02_explain_why_not(State, Alternative,
                    why_not(
                        alternative(Alternative),
                        selected(pause),
                        blocked_by(visibility_below_minimum),
                        violation(
                            observed(visibility_confidence, Confidence),
                            required_minimum(visibility_confidence, Minimum)
                        ),
                        Proof
                    )) :-
    state_knowledge(State, Facts, Rules),
    Alternative = continue,
    memberchk(visibility_confidence(Confidence), Facts),
    memberchk(minimum_visibility(Minimum), Facts),
    once(explain_why_not(Alternative, pause, Facts, Rules,
                         why_not(Alternative, pause,
                                 visibility_below_minimum, Proof))).


s02_dialogue_reply(State, why_decision, Text, Explanation) :-
    s02_decision(State, Decision, _),
    s02_explain_why(State, Decision, Explanation),
    decision_reply(Decision, State, Text).
s02_dialogue_reply(State, why_not(Alternative), Text, Explanation) :-
    s02_explain_why_not(State, Alternative, Explanation),
    format(string(Text),
           'I did not ~w because visibility confidence ~2f is below the certified minimum ~2f. Continuing would violate the visibility constraint.',
           [Alternative,
            State.visibility_confidence,
            State.minimum_visibility]).
s02_dialogue_reply(State, clarify_occlusion, Text,
                   clarification(occlusion(Entity, Occluder, Zone))) :-
    s02_decision(State, pause, _),
    Entity = State.observed_entity,
    Occluder = State.occluding_object,
    Zone = State.zone,
    format(string(Text),
           'The ~w obstructed my view of the ~w in ~w, reducing sensing reliability.',
           [Occluder, Entity, Zone]).
s02_dialogue_reply(State, show_state, Text,
                   state_summary(Decision, Constraints)) :-
    s02_decision(State, Decision, Constraints),
    format(string(Text),
           'Decision: ~w. Visibility: ~2f. Required minimum: ~2f. Occluder: ~w. Zone: ~w. Active constraints: ~w.',
           [Decision,
            State.visibility_confidence,
            State.minimum_visibility,
            State.occluding_object,
            State.zone,
            Constraints]).


decision_reply(pause, State, Text) :-
    format(string(Text),
           'I paused because visibility confidence ~2f is below the certified minimum ~2f. The ~w is occluding the ~w in ~w.',
           [State.visibility_confidence,
            State.minimum_visibility,
            State.occluding_object,
            State.observed_entity,
            State.zone]).
decision_reply(continue, State, Text) :-
    format(string(Text),
           'I continued because visibility confidence ~2f meets the certified minimum ~2f.',
           [State.visibility_confidence,
            State.minimum_visibility]).


s02_chat :-
    s02_default_state(State),
    s02_chat(State).


s02_chat(State) :-
    current_input(Input),
    current_output(Output),
    s02_chat(State, Input, Output).


s02_chat(State, Input, Output) :-
    s02_decision(State, Decision, Constraints),
    format(Output, '~n--- S02 Occlusion-Aware Dialogue ---~n', []),
    format(Output,
           'Robot: Current decision is ~w. Active constraints: ~w.~n',
           [Decision, Constraints]),
    chat_loop(State, Input, Output).


chat_loop(State, Input, Output) :-
    format(Output, '~nPlease select a question:~n', []),
    format(Output, '1. Why did you make this decision?~n', []),
    format(Output, '2. Why not continue?~n', []),
    format(Output, '3. What caused the low visibility?~n', []),
    format(Output, '4. Show the current safety state.~n', []),
    format(Output, '5. Exit.~n', []),
    format(Output, 'Enter a number from 1 to 5.~n', []),
    format(Output, 'User: ', []),
    flush_output(Output),
    read_line_to_string(Input, Line),
    parse_choice(Line, Choice),
    handle_choice(Choice, State, Input, Output).


parse_choice(end_of_file, end_of_file) :-
    !.
parse_choice(Line, Choice) :-
    normalize_space(string(Trimmed), Line),
    string_codes(Trimmed, InputCodes),
    (   append(NumberCodes, [0'.], InputCodes)
    ->  true
    ;   NumberCodes = InputCodes
    ),
    catch(number_codes(Choice, NumberCodes), _, fail),
    !.
parse_choice(_Line, invalid).


handle_choice(5, _State, _Input, Output) :-
    format(Output, 'Robot: Dialogue ended.~n', []).
handle_choice(end_of_file, _State, _Input, Output) :-
    format(Output, 'Robot: Dialogue ended.~n', []).
handle_choice(Choice, State, Input, Output) :-
    choice_intent(Choice, Intent),
    !,
    (   s02_dialogue_reply(State, Intent, Text, _Explanation)
    ->  format(Output, 'Robot: ~s~n', [Text])
    ;   format(Output,
               'Robot: That question is not applicable to the current safety state.~n',
               [])
    ),
    chat_loop(State, Input, Output).
handle_choice(_Choice, State, Input, Output) :-
    format(Output, 'Robot: Please choose a number from 1 to 5.~n', []),
    chat_loop(State, Input, Output).


choice_intent(1, why_decision).
choice_intent(2, why_not(continue)).
choice_intent(3, clarify_occlusion).
choice_intent(4, show_state).


state_knowledge(State, Facts, Rules) :-
    is_dict(State, s02_state),
    Facts = [
        visibility_confidence(State.visibility_confidence),
        minimum_visibility(State.minimum_visibility),
        observed_entity(State.observed_entity),
        occluding_object(State.occluding_object),
        current_zone(State.zone),
        nominal_action(State.nominal_action)
    ],
    s02_rules(Rules).


s02_rules([
    rule(
        occlusion_evidence,
        occlusion(Entity, Occluder, Zone),
        [
            observed_entity(Entity),
            occluding_object(Occluder),
            current_zone(Zone)
        ]
    ),
    rule(
        visibility_constraint,
        constraint_active(visibility_below_minimum),
        [
            visibility_confidence(Confidence),
            minimum_visibility(Minimum),
            less_than(Confidence, Minimum),
            occlusion(_Entity, _Occluder, _Zone)
        ]
    ),
    rule(
        pause_on_visibility_constraint,
        selected_action(pause),
        [constraint_active(visibility_below_minimum)]
    ),
    rule(
        block_continue_on_visibility_constraint,
        action_blocked(continue, visibility_below_minimum),
        [constraint_active(visibility_below_minimum)]
    ),
    rule(
        continue_with_reliable_visibility,
        selected_action(continue),
        [
            visibility_confidence(Confidence),
            minimum_visibility(Minimum),
            greater_than_or_equal(Confidence, Minimum)
        ]
    )
]).
