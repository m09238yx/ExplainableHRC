import math


def decide(
    robot_x,
    robot_y,
    goal_x,
    goal_y,
    obstacle_x,
    obstacle_y,
    safety_threshold,
    goal_tolerance,
):
    distance_to_goal = math.hypot(goal_x - robot_x, goal_y - robot_y)
    distance_to_obstacle = math.hypot(
        obstacle_x - robot_x, obstacle_y - robot_y)
    if distance_to_goal <= goal_tolerance:
        return 'GOAL_REACHED'
    if distance_to_obstacle <= safety_threshold:
        return 'STOP'
    return 'CONTINUE'


def test_continue_outside_threshold():
    assert decide(0.0, 0.0, 11.0, 0.0, 8.0, 0.0, 1.0, 0.2) == 'CONTINUE'


def test_stop_at_threshold():
    assert decide(7.0, 0.0, 11.0, 0.0, 8.0, 0.0, 1.0, 0.2) == 'STOP'


def test_goal_has_priority():
    assert decide(10.9, 0.0, 11.0, 0.0, 11.0, 0.0, 1.0, 0.2) == 'GOAL_REACHED'
