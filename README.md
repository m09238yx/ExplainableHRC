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

A read-only bridge independently checks each latest trace with Prolog and
publishes its decision, consistency result, Why, and Why-not terms on
`/prolog_explanation`. It never publishes robot motion commands.

The sphere above the robot uses three safety colours: green for movement
(`GO`, `RESUME`, `GOAL_REACHED`), yellow for restricted operation (`SLOW`,
`WAIT`), and red for `STOP`. Concise transition explanations are published on
`/safety_explanation_text`; the text retains all six state names.

```bash
docker compose -f docker/compose.yaml exec ros2-desktop bash -lc \
  'source /opt/ros/jazzy/setup.bash && source /home/ubuntu/ros2_ws/install/setup.bash && ros2 topic echo /prolog_explanation std_msgs/msg/String'
```

The worker begins crossing after 15 seconds, pauses in the robot lane for 10
seconds so the stop is easy to observe, then remains at the far side while the
robot completes the task.

Stop Docker when finished:

```bash
docker compose -f docker/compose.yaml down
```
