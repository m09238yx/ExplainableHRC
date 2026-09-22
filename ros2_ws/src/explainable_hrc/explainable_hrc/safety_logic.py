"""Pure distance-based safety state and speed calculations."""

GO = 'go'
SLOW = 'slow'
STOP = 'stop'
WAIT = 'wait'
RESUME = 'resume'
GOAL_REACHED = 'goal_reached'


def select_safety_state(
    worker_distance: float,
    goal_reached: bool,
    previous_state: str | None,
    clearance_duration: float,
    required_clearance_duration: float,
    resume_complete: bool,
    caution_distance: float,
    stop_distance: float,
    resume_distance: float,
) -> str:
    """Select one of the six states using explicit safety priority."""
    if goal_reached:
        return GOAL_REACHED
    if worker_distance <= stop_distance:
        return STOP
    if (
        previous_state in (STOP, WAIT, RESUME)
        and worker_distance <= resume_distance
    ):
        return STOP
    if previous_state == STOP and worker_distance > resume_distance:
        return WAIT
    if previous_state == WAIT and worker_distance > resume_distance:
        if clearance_duration < required_clearance_duration:
            return WAIT
        return RESUME
    if previous_state == RESUME and not resume_complete:
        return RESUME
    if worker_distance <= caution_distance:
        return SLOW
    return GO


def active_constraints(
    state: str,
    worker_distance: float,
    stop_distance: float,
) -> list[str]:
    """Return the binding explanation labels for the selected state."""
    if state == GOAL_REACHED:
        return ['goal_reached']
    if state == STOP:
        if worker_distance <= stop_distance:
            return ['minimum_separation']
        return ['resume_threshold_not_cleared']
    if state == WAIT:
        return ['clearance_confirmation']
    if state == RESUME:
        return ['controlled_acceleration']
    if state == SLOW:
        return ['caution_zone']
    return []


def distance_limited_speed(
    worker_distance: float,
    stop_distance: float,
    caution_distance: float,
    minimum_speed: float,
    forward_speed: float,
) -> float:
    """Interpolate a cautious speed between stop and caution thresholds."""
    if worker_distance <= stop_distance:
        return 0.0
    if worker_distance >= caution_distance:
        return forward_speed
    span = caution_distance - stop_distance
    progress = (worker_distance - stop_distance) / span
    return minimum_speed + progress * (forward_speed - minimum_speed)


def ramp_speed(
    current_speed: float,
    target_speed: float,
    acceleration_rate: float,
    deceleration_rate: float,
    period: float,
) -> float:
    """Move speed toward a target with bounded acceleration/deceleration."""
    if target_speed >= current_speed:
        return min(target_speed, current_speed + acceleration_rate * period)
    return max(target_speed, current_speed - deceleration_rate * period)


def target_speed_for_state(
    state: str,
    worker_distance: float,
    stop_distance: float,
    caution_distance: float,
    minimum_speed: float,
    forward_speed: float,
) -> float:
    """Return the desired speed before applying the ramp."""
    if state in (STOP, WAIT, GOAL_REACHED):
        return 0.0
    if state in (SLOW, RESUME):
        return distance_limited_speed(
            worker_distance,
            stop_distance,
            caution_distance,
            minimum_speed,
            forward_speed,
        )
    return forward_speed
