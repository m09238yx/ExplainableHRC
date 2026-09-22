"""Validation and SWI-Prolog invocation for safety decision traces."""

import json
import subprocess
from pathlib import Path
from typing import Any


STATE_FIELDS = (
    'worker_distance',
    'caution_distance',
    'stop_distance',
    'resume_distance',
    'previous_state',
    'clearance_duration',
    'required_clearance_duration',
    'resume_complete',
    'goal_reached',
    'decision',
)

NUMBER_FIELDS = (
    'worker_distance',
    'caution_distance',
    'stop_distance',
    'resume_distance',
    'clearance_duration',
    'required_clearance_duration',
)

VALID_STATES = {
    'go', 'slow', 'stop', 'wait', 'resume', 'goal_reached',
}


def validate_trace(trace: Any) -> dict[str, Any]:
    """Return the Prolog state fields or raise ValueError."""
    if not isinstance(trace, dict):
        raise ValueError('decision trace must be a JSON object')
    missing = [field for field in STATE_FIELDS if field not in trace]
    if missing:
        raise ValueError(f'missing trace fields: {", ".join(missing)}')
    for field in NUMBER_FIELDS:
        value = trace[field]
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise ValueError(f'{field} must be numeric')
    for field in ('resume_complete', 'goal_reached'):
        if not isinstance(trace[field], bool):
            raise ValueError(f'{field} must be boolean')
    for field in ('previous_state', 'decision'):
        if not isinstance(trace[field], str):
            raise ValueError(f'{field} must be a string')
        if trace[field] not in VALID_STATES and not (
            field == 'previous_state' and trace[field] == 'none'
        ):
            raise ValueError(f'{field} has unsupported value {trace[field]!r}')
    return {field: trace[field] for field in STATE_FIELDS}


def run_prolog_reasoning(
    trace: Any,
    cli_path: str,
    timeout: float = 2.0,
) -> dict[str, Any]:
    """Validate a trace and obtain a structured Prolog explanation."""
    state = validate_trace(trace)
    path = Path(cli_path)
    if not path.is_file():
        raise RuntimeError(f'Prolog bridge file not found: {path}')
    try:
        completed = subprocess.run(
            ['swipl', '-q', '-s', str(path)],
            input=json.dumps(state),
            capture_output=True,
            check=False,
            text=True,
            timeout=timeout,
        )
    except FileNotFoundError as error:
        raise RuntimeError('SWI-Prolog executable not found') from error
    except subprocess.TimeoutExpired as error:
        raise RuntimeError('SWI-Prolog reasoning timed out') from error
    if completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise RuntimeError(f'SWI-Prolog reasoning failed: {detail}')
    try:
        result = json.loads(completed.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError('SWI-Prolog returned invalid JSON') from error
    if not isinstance(result, dict) or 'prolog_decision' not in result:
        raise RuntimeError(f'SWI-Prolog returned an invalid result: {result!r}')
    return result
