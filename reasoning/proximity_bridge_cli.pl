:- use_module(library(http/json)).
:- use_module(s02_proximity_reasoning).

:- initialization(main, main).


main :-
    catch(run_bridge, Error, bridge_error(Error)).


run_bridge :-
    json_read_dict(user_input, Input),
    atom_string(PreviousState, Input.previous_state),
    atom_string(TraceDecision, Input.decision),
    State = proximity_state{
        worker_distance:Input.worker_distance,
        caution_distance:Input.caution_distance,
        stop_distance:Input.stop_distance,
        resume_distance:Input.resume_distance,
        previous_state:PreviousState,
        clearance_duration:Input.clearance_duration,
        required_clearance_duration:Input.required_clearance_duration,
        resume_complete:Input.resume_complete,
        goal_reached:Input.goal_reached
    },
    proximity_decision(State, Decision, Constraints),
    proximity_explain_why(State, Decision, Why),
    term_string(Why, WhyText, [quoted(true)]),
    why_not_text(State, WhyNotText),
    (Decision == TraceDecision -> MatchesTrace = true ; MatchesTrace = false),
    Result = _{
        trace_decision:TraceDecision,
        prolog_decision:Decision,
        decision_matches:MatchesTrace,
        active_constraints:Constraints,
        why:WhyText,
        why_not_continue:WhyNotText
    },
    json_write_dict(current_output, Result, [width(0)]),
    nl.


why_not_text(State, Text) :-
    proximity_explain_why_not(State, continue, WhyNot),
    !,
    term_string(WhyNot, Text, [quoted(true)]).
why_not_text(_State, null).


bridge_error(Error) :-
    message_to_string(Error, Message),
    json_write_dict(current_output,
                    _{error:Message},
                    [width(0)]),
    nl,
    halt(1).
