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

The robot follows the green route. It stops when the moving worker comes within
`1.5 m`, resumes after the worker moves beyond `1.8 m`, and stops at the goal.
The red disc around the worker shows the `1.5 m` stop zone.

Other available demos:

```bash
./scripts/run_hri_safety_scenario.sh
./scripts/run_gazebo_empty_world.sh
```

Stop Docker when finished:

```bash
docker compose -f docker/compose.yaml down
```
