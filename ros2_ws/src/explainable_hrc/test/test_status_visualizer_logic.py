import pytest

from explainable_hrc.status_visualizer_logic import (
    BEACON_COLOURS,
    applied_rule,
    explanation_text,
)


def trace(**overrides):
    value = {
        'decision': 'stop',
        'previous_state': 'slow',
        'worker_distance': 1.42,
        'stop_distance': 1.5,
        'active_constraints': ['minimum_separation'],
    }
    value.update(overrides)
    return value


@pytest.mark.parametrize(
    'change, expected',
    [
        ({'decision': 'go'}, 'go_outside_caution_zone'),
        ({'decision': 'slow'}, 'slow_inside_caution_zone'),
        ({}, 'stop_at_minimum_separation'),
        ({'decision': 'wait', 'previous_state': 'stop'},
         'start_clearance_wait'),
        ({'decision': 'resume', 'previous_state': 'wait'},
         'begin_controlled_resume'),
        ({'decision': 'goal_reached'}, 'goal_has_priority'),
    ],
)
def test_applied_rule_for_six_states(change, expected):
    assert applied_rule(trace(**change)) == expected


def test_explanation_text_makes_stop_visible():
    text = explanation_text(trace())
    assert text == (
        'State: STOP | Worker distance: 1.42 m | '
        'Reason: minimum_separation | '
        'Rule: stop_at_minimum_separation'
    )


def test_six_states_use_only_three_safety_colours():
    assert set(BEACON_COLOURS.values()) == {'GREEN', 'YELLOW', 'RED'}
    assert BEACON_COLOURS['stop'] == 'RED'
    assert BEACON_COLOURS['slow'] == BEACON_COLOURS['wait'] == 'YELLOW'
