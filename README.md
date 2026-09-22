# ExplainableHRC

## Start Docker

Requirements:

- Docker Desktop
- Docker Compose v2

From the repository root, build and start the container:

```bash
docker compose -f docker/compose.yaml build
docker compose -f docker/compose.yaml up -d
```

Open the browser desktop at <http://127.0.0.1:6080/>. The initial password is
`ubuntu`.

Build the ROS 2 workspace:

```bash
docker compose -f docker/compose.yaml exec --user ubuntu ros2-desktop \
  bash -lc 'cd /home/ubuntu/ros2_ws && source /opt/ros/$ROS_DISTRO/setup.bash && colcon build --symlink-install'
```

## Run the demo

Run the construction-site worker-crossing demo from the repository root:

```bash
./scripts/run_construction_crossing_scenario.sh
```

The robot follows the green route through six visible safety states:
`GO`, `SLOW`, `STOP`, `WAIT`, `RESUME`, and `GOAL_REACHED`. It slows inside the
`3.0 m` caution zone, stops at `1.5 m`, waits one second after the worker clears
`1.8 m`, resumes with bounded acceleration, and stops at the goal. The yellow
disc shows the `3.0 m` caution zone and the red disc shows the `1.5 m` stop
zone. Structured JSON decision traces are published continuously on
`/safety_decision`.

The worker begins crossing after 15 seconds, pauses in the robot lane for 10
seconds so the stop is easy to observe, then remains at the far side while the
robot completes the task.

Stop Docker when finished:

```bash
docker compose -f docker/compose.yaml down
```
