from explainable_hrc.worker_motion_node import worker_y_position


def test_worker_waits_before_crossing():
    assert worker_y_position(
        10.0, -3.0, 3.0, 15.0, 10.0, 6.0, 5.0) == -3.0


def test_worker_reaches_crossing_centre():
    assert worker_y_position(
        20.0, -3.0, 3.0, 15.0, 10.0, 6.0, 5.0) == 0.0


def test_worker_waits_in_robot_lane():
    assert worker_y_position(
        25.0, -3.0, 3.0, 15.0, 10.0, 6.0, 5.0) == 0.0


def test_worker_waits_at_far_side():
    assert worker_y_position(
        33.0, -3.0, 3.0, 15.0, 10.0, 6.0, 5.0) == 3.0


def test_worker_returns_to_crossing_centre():
    assert worker_y_position(
        41.0, -3.0, 3.0, 15.0, 10.0, 6.0, 5.0) == 0.0
