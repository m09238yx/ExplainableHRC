import shutil
from pathlib import Path

import pytest

from explainable_hrc.prolog_bridge import run_prolog_reasoning, validate_trace


CLI_CANDIDATES = (
    Path(__file__).resolve().parents[4]
    / 'reasoning' / 'proximity_bridge_cli.pl',
    Path('/home/ubuntu/ExplainableHRC/reasoning/proximity_bridge_cli.pl'),
)
CLI_PATH = next((path for path in CLI_CANDIDATES if path.is_file()),
                CLI_CANDIDATES[0])


def trace(**overrides):
    value = {
        'worker_distance': 1.42,
        'caution_distance': 3.0,
        'stop_distance': 1.5,
        'resume_distance': 1.8,
        'previous_state': 'slow',
        'clearance_duration': 0.0,
        'required_clearance_duration': 1.0,
        'resume_complete': True,
        'goal_reached': False,
        'decision': 'stop',
        'ignored_transport_field': 123,
    }
    value.update(overrides)
    return value


def test_validate_trace_keeps_only_reasoning_state():
    result = validate_trace(trace())
    assert 'ignored_transport_field' not in result
    assert result['worker_distance'] == 1.42
    assert result['decision'] == 'stop'


@pytest.mark.parametrize(
    'change, message',
    [
        ({'worker_distance': 'near'}, 'worker_distance must be numeric'),
        ({'goal_reached': 0}, 'goal_reached must be boolean'),
        ({'decision': 'fly'}, "decision has unsupported value 'fly'"),
    ],
)
def test_validate_trace_rejects_invalid_types_and_states(change, message):
    with pytest.raises(ValueError, match=message):
        validate_trace(trace(**change))


def test_validate_trace_rejects_missing_fields():
    value = trace()
    del value['resume_distance']
    with pytest.raises(ValueError, match='missing trace fields: resume_distance'):
        validate_trace(value)


@pytest.mark.skipif(shutil.which('swipl') is None, reason='SWI-Prolog missing')
def test_prolog_bridge_returns_grounded_stop_explanations():
    result = run_prolog_reasoning(trace(), str(CLI_PATH))
    assert result['prolog_decision'] == 'stop'
    assert result['decision_matches'] is True
    assert result['active_constraints'] == ['minimum_separation']
    assert 'worker_distance,1.42' in result['why']
    assert 'block_continue_at_minimum_separation' in result[
        'why_not_continue']


@pytest.mark.skipif(shutil.which('swipl') is None, reason='SWI-Prolog missing')
def test_prolog_bridge_detects_ros_decision_mismatch():
    result = run_prolog_reasoning(trace(decision='go'), str(CLI_PATH))
    assert result['trace_decision'] == 'go'
    assert result['prolog_decision'] == 'stop'
    assert result['decision_matches'] is False


@pytest.mark.skipif(shutil.which('swipl') is None, reason='SWI-Prolog missing')
def test_prolog_bridge_represents_safe_go_without_why_not():
    result = run_prolog_reasoning(
        trace(worker_distance=4.0, previous_state='go', decision='go'),
        str(CLI_PATH),
    )
    assert result['prolog_decision'] == 'go'
    assert result['decision_matches'] is True
    assert result['active_constraints'] == []
    assert result['why_not_continue'] is None
