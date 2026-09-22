:- begin_tests(s02_proximity_reasoning).

:- use_module('../s02_proximity_reasoning').


state(Overrides, State) :-
    proximity_default_state(Default),
    put_dict(Overrides, Default, State).


test(go_outside_caution_zone) :-
    state(_{worker_distance:4.0}, State),
    proximity_decision(State, go, []).


test(slow_inside_caution_zone) :-
    state(_{worker_distance:2.2}, State),
    proximity_decision(State, slow, [caution_zone]).


test(stop_at_minimum_separation) :-
    state(_{worker_distance:1.42, previous_state:slow}, State),
    proximity_decision(State, stop, [minimum_separation]).


test(remain_stopped_below_resume_threshold) :-
    state(_{worker_distance:1.7, previous_state:stop}, State),
    proximity_decision(
        State, stop, [resume_threshold_not_cleared]).


test(wait_after_resume_threshold_is_cleared) :-
    state(_{worker_distance:2.0, previous_state:stop}, State),
    proximity_decision(State, wait, [clearance_confirmation]).


test(continue_wait_before_timer_finishes) :-
    state(_{worker_distance:2.0,
            previous_state:wait,
            clearance_duration:0.6}, State),
    proximity_decision(State, wait, [clearance_confirmation]).


test(resume_after_clearance_timer) :-
    state(_{worker_distance:2.0,
            previous_state:wait,
            clearance_duration:1.0,
            resume_complete:false}, State),
    proximity_decision(State, resume, [controlled_acceleration]).


test(remain_in_resume_during_acceleration) :-
    state(_{worker_distance:2.2,
            previous_state:resume,
            resume_complete:false}, State),
    proximity_decision(State, resume, [controlled_acceleration]).


test(worker_reentry_during_resume_returns_to_stop) :-
    state(_{worker_distance:1.7,
            previous_state:resume,
            resume_complete:false}, State),
    proximity_decision(
        State, stop, [resume_threshold_not_cleared]).


test(goal_reached_has_highest_priority) :-
    state(_{worker_distance:1.0,
            previous_state:stop,
            goal_reached:true}, State),
    proximity_decision(State, goal_reached, [goal_reached]).


test(why_go_contains_caution_distance) :-
    state(_{worker_distance:4.0}, State),
    proximity_explain_why(State, go, Explanation),
    Explanation = why(
        decision(go),
        outside_caution_zone,
        evidence([
            observed(worker_distance, 4.0),
            caution_threshold(3.0)
        ]),
        _
    ).


test(why_slow_contains_distance_thresholds) :-
    state(_{worker_distance:2.2}, State),
    proximity_explain_why(State, slow, Explanation),
    Explanation = why(
        decision(slow),
        caution_zone,
        evidence([
            observed(worker_distance, 2.2),
            caution_threshold(3.0),
            stop_threshold(1.5)
        ]),
        proof(selected_action(slow), rule(slow_inside_caution_zone), _)
    ).


test(why_stop_contains_minimum_distance) :-
    state(_{worker_distance:1.42, previous_state:slow}, State),
    proximity_explain_why(State, stop, Explanation),
    Explanation = why(
        decision(stop),
        minimum_separation,
        evidence([
            observed(worker_distance, 1.42),
            required_minimum(stop_distance, 1.5)
        ]),
        _
    ).


test(why_wait_contains_timer) :-
    state(_{worker_distance:2.0,
            previous_state:wait,
            clearance_duration:0.6}, State),
    proximity_explain_why(State, wait, Explanation),
    Explanation = why(
        decision(wait),
        clearance_confirmation,
        evidence([
            observed(clearance_duration, 0.6),
            required(clearance_duration, 1.0)
        ]),
        _
    ).


test(why_resume_contains_clearance_confirmation) :-
    state(_{worker_distance:2.0,
            previous_state:wait,
            clearance_duration:1.0,
            resume_complete:false}, State),
    proximity_explain_why(State, resume, Explanation),
    Explanation = why(
        decision(resume),
        clearance_confirmed,
        _,
        _
    ).


test(why_goal_reached) :-
    state(_{goal_reached:true}, State),
    proximity_explain_why(State, goal_reached, Explanation),
    Explanation = why(
        decision(goal_reached),
        goal_reached,
        evidence([goal_reached(true)]),
        _
    ).


test(why_not_continue_when_stopped) :-
    state(_{worker_distance:1.42, previous_state:slow}, State),
    proximity_explain_why_not(State, continue, Explanation),
    Explanation = why_not(
        alternative(continue),
        selected(stop),
        blocked_by(minimum_separation),
        evidence([
            observed(worker_distance, 1.42),
            required_minimum(stop_distance, 1.5)
        ]),
        _
    ).


test(why_not_continue_at_full_speed_when_slow) :-
    state(_{worker_distance:2.2}, State),
    proximity_explain_why_not(State, continue, Explanation),
    Explanation = why_not(
        alternative(continue),
        selected(slow),
        blocked_by(caution_zone),
        _,
        _
    ).


test(why_not_continue_before_resume_threshold) :-
    state(_{worker_distance:1.7, previous_state:stop}, State),
    proximity_explain_why_not(State, continue, Explanation),
    Explanation = why_not(
        alternative(continue),
        selected(stop),
        blocked_by(resume_threshold_not_cleared),
        evidence([
            observed(worker_distance, 1.7),
            required_clearance(resume_distance, 1.8)
        ]),
        _
    ).


test(why_not_continue_during_wait) :-
    state(_{worker_distance:2.0, previous_state:stop}, State),
    proximity_explain_why_not(State, continue, Explanation),
    Explanation = why_not(
        alternative(continue),
        selected(wait),
        blocked_by(clearance_confirmation),
        _,
        _
    ).


test(why_not_continue_during_resume) :-
    state(_{worker_distance:2.0,
            previous_state:resume,
            resume_complete:false}, State),
    proximity_explain_why_not(State, continue, Explanation),
    Explanation = why_not(
        alternative(continue),
        selected(resume),
        blocked_by(controlled_acceleration),
        _,
        _
    ).


test(why_not_continue_after_goal) :-
    state(_{goal_reached:true}, State),
    proximity_explain_why_not(State, continue, Explanation),
    Explanation = why_not(
        alternative(continue),
        selected(goal_reached),
        blocked_by(goal_reached),
        evidence([goal_reached(true)]),
        _
    ).


test(why_not_continue_fails_when_go_is_selected, [fail]) :-
    state(_{worker_distance:4.0}, State),
    proximity_explain_why_not(State, continue, _).


test(boundary_stop_distance_is_stop) :-
    state(_{worker_distance:1.5}, State),
    proximity_decision(State, stop, [minimum_separation]).


test(boundary_caution_distance_is_slow) :-
    state(_{worker_distance:3.0}, State),
    proximity_decision(State, slow, [caution_zone]).


:- end_tests(s02_proximity_reasoning).
