"""Human-readable labels for the six-state safety demonstration."""

from typing import Any


BEACON_COLOURS = {
    'go': 'GREEN',
    'slow': 'YELLOW',
    'stop': 'RED',
    'wait': 'YELLOW',
    'resume': 'GREEN',
    'goal_reached': 'GREEN',
}


def applied_rule(trace: dict[str, Any]) -> str:
    """Return the Prolog rule selected by a validated decision trace."""
    decision = trace['decision']
    previous = trace['previous_state']
    if decision == 'goal_reached':
        return 'goal_has_priority'
    if decision == 'stop':
        if trace['worker_distance'] <= trace['stop_distance']:
            return 'stop_at_minimum_separation'
        return {
            'stop': 'remain_stopped_until_resume_threshold',
            'wait': 'reset_wait_inside_resume_threshold',
            'resume': 'reset_resume_inside_resume_threshold',
        }.get(previous, 'stop_at_minimum_separation')
    if decision == 'wait':
        if previous == 'stop':
            return 'start_clearance_wait'
        return 'continue_clearance_wait'
    if decision == 'resume':
        if previous == 'wait':
            return 'begin_controlled_resume'
        return 'continue_controlled_resume'
    if decision == 'slow':
        return 'slow_inside_caution_zone'
    return 'go_outside_caution_zone'


def explanation_text(trace: dict[str, Any]) -> str:
    """Create a compact display line grounded in trace values."""
    decision = trace['decision']
    constraints = trace.get('active_constraints', [])
    constraint = constraints[0] if constraints else 'none'
    return (
        f'State: {decision.upper()} | '
        f'Worker distance: {trace["worker_distance"]:.2f} m | '
        f'Reason: {constraint} | Rule: {applied_rule(trace)}'
    )
