import math

import pytest

from explainable_hrc.safety_logic import (
    GO,
    GOAL_REACHED,
    RESUME,
    SLOW,
    STOP,
    WAIT,
    active_constraints,
    distance_limited_speed,
    ramp_speed,
    select_safety_state,
    target_speed_for_state,
)


PARAMETERS = {
    'required_clearance_duration': 1.0,
    'caution_distance': 3.0,
    'stop_distance': 1.5,
    'resume_distance': 1.8,
}


def decide(
    worker_distance,
    previous_state=GO,
    clearance_duration=0.0,
    resume_complete=True,
    goal_reached=False,
):
    return select_safety_state(
        worker_distance=worker_distance,
        goal_reached=goal_reached,
        previous_state=previous_state,
        clearance_duration=clearance_duration,
        resume_complete=resume_complete,
        **PARAMETERS,
    )


@pytest.mark.parametrize(
    ('distance', 'expected'),
    [
        (3.01, GO),
        (3.0, SLOW),
        (2.2, SLOW),
        (1.5, STOP),
        (1.0, STOP),
    ],
)
def test_distance_states(distance, expected):
    assert decide(distance) == expected


def test_stop_hysteresis_until_resume_threshold():
    assert decide(1.7, previous_state=STOP) == STOP
    assert active_constraints(STOP, 1.7, 1.5) == [
        'resume_threshold_not_cleared']


def test_stop_transitions_to_wait_above_resume_threshold():
    assert decide(1.81, previous_state=STOP) == WAIT


def test_wait_requires_full_clearance_duration():
    assert decide(
        2.0, previous_state=WAIT, clearance_duration=0.99) == WAIT
    assert decide(
        2.0, previous_state=WAIT, clearance_duration=1.0) == RESUME


def test_worker_reentry_during_wait_or_resume_stops_robot():
    assert decide(1.7, previous_state=WAIT) == STOP
    assert decide(
        1.7, previous_state=RESUME, resume_complete=False) == STOP


def test_resume_persists_until_speed_ramp_completes():
    assert decide(
        2.0, previous_state=RESUME, resume_complete=False) == RESUME
    assert decide(
        2.0, previous_state=RESUME, resume_complete=True) == SLOW


def test_goal_has_priority_over_worker_distance():
    assert decide(1.0, previous_state=STOP, goal_reached=True) == GOAL_REACHED


@pytest.mark.parametrize(
    ('state', 'distance', 'expected'),
    [
        (GO, 4.0, []),
        (SLOW, 2.2, ['caution_zone']),
        (STOP, 1.42, ['minimum_separation']),
        (WAIT, 2.0, ['clearance_confirmation']),
        (RESUME, 2.0, ['controlled_acceleration']),
        (GOAL_REACHED, 4.0, ['goal_reached']),
    ],
)
def test_active_constraints(state, distance, expected):
    assert active_constraints(state, distance, 1.5) == expected


def test_slow_speed_is_interpolated_from_distance():
    speed = distance_limited_speed(2.25, 1.5, 3.0, 0.1, 0.3)
    assert math.isclose(speed, 0.2)


def test_ramp_speed_limits_acceleration_and_deceleration():
    assert math.isclose(ramp_speed(0.0, 0.3, 0.15, 0.3, 0.1), 0.015)
    assert math.isclose(ramp_speed(0.3, 0.1, 0.15, 0.3, 0.1), 0.27)


def test_stop_wait_and_goal_commands_are_zero():
    for state in (STOP, WAIT, GOAL_REACHED):
        assert target_speed_for_state(
            state, 2.0, 1.5, 3.0, 0.1, 0.3) == 0.0
